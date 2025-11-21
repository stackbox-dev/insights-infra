/**
 * Main Flink SQL Executor class
 */

import * as fs from 'fs';
import * as path from 'path';
import chalk from 'chalk';
import Table from 'cli-table3';
import { FlinkSQLGatewayClient } from './flink-sql-gateway.js';
import { FlinkRestClient } from './flink-rest-client.js';
import { FlinkJobDatabase } from './database.js';
import { FlinkJobManager } from './flink-job-manager.js';
import { loadEnvFile, substituteEnvVariables, loadConfig } from '../utils/env.js';
import { splitStatements, formatSqlPreview } from '../utils/sql-parser.js';
import { formatSqlError } from '../utils/logger.js';
import {
  ExecutorOptions,
  Config,
  ExecutionResult,
  EnvVars,
} from '../types.js';
import type { Logger } from 'winston';

export class FlinkSQLExecutor {
  private config: Config;
  private envVars: EnvVars = {};
  private logger: Logger;
  private sqlGateway: FlinkSQLGatewayClient;
  private restClient: FlinkRestClient;
  private database: FlinkJobDatabase | null = null;
  private jobManager: FlinkJobManager | null = null;

  constructor(options: ExecutorOptions, logger: Logger) {
    this.logger = logger;

    // Load environment variables first
    if (options.envFile) {
      this.envVars = loadEnvFile(options.envFile);
      // Merge into process.env so loadConfig can access them
      Object.assign(process.env, this.envVars);
    }

    // Load configuration (after env vars are loaded)
    this.config = loadConfig(options.configFile);

    // Override config with command line options
    if (options.sqlGatewayUrl) {
      this.config.sql_gateway.url = options.sqlGatewayUrl;
    }
    if (options.flinkRestUrl) {
      this.config.flink_cluster.url = options.flinkRestUrl;
    }
    if (options.continueOnError !== undefined) {
      this.config.execution.continue_on_error = options.continueOnError;
    }
    if (options.stopOnError) {
      this.config.execution.continue_on_error = false;
    }

    // Initialize clients
    this.sqlGateway = new FlinkSQLGatewayClient(
      this.config.sql_gateway.url,
      this.config.sql_gateway.session_timeout,
      this.config.sql_gateway.poll_interval,
      this.config.sql_gateway.max_wait_time,
      this.logger
    );

    this.restClient = new FlinkRestClient(this.config.flink_cluster.url, this.logger);
  }

  /**
   * Initialize database if enabled
   */
  initializeDatabase(enableDatabase: boolean, dbPath?: string): void {
    if (enableDatabase) {
      const path = dbPath || this.config.job_management.database_path;
      this.database = new FlinkJobDatabase(path, this.logger);
      this.database.initialize();

      // Initialize job manager with database
      this.jobManager = new FlinkJobManager(
        this.restClient,
        this.database,
        this.sqlGateway,
        this.logger,
        this.envVars
      );
    }
  }

  /**
   * Execute SQL from file
   */
  async executeFromFile(
    filePath: string,
    dryRun: boolean = false,
    singleStatement: boolean = false
  ): Promise<ExecutionResult[]> {
    this.logger.info(`Executing SQL from file: ${filePath}`);

    // Read file
    if (!fs.existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }

    let sqlContent = fs.readFileSync(filePath, 'utf-8');

    // Substitute environment variables
    sqlContent = substituteEnvVariables(sqlContent, this.envVars, true);

    if (singleStatement) {
      return this.executeSingleStatement(sqlContent, dryRun, path.basename(filePath));
    } else {
      return this.executeMultipleStatements(sqlContent, dryRun, path.basename(filePath));
    }
  }

  /**
   * Execute inline SQL query
   */
  async executeInlineQuery(
    sql: string,
    dryRun: boolean = false,
    singleStatement: boolean = false
  ): Promise<ExecutionResult[]> {
    this.logger.info('Executing inline SQL query');

    // Substitute environment variables
    const processedSql = substituteEnvVariables(sql, this.envVars, true);

    if (singleStatement) {
      return this.executeSingleStatement(processedSql, dryRun, 'inline-query');
    } else {
      return this.executeMultipleStatements(processedSql, dryRun, 'inline-query');
    }
  }

  /**
   * Execute single statement
   */
  private async executeSingleStatement(
    sql: string,
    dryRun: boolean,
    source: string
  ): Promise<ExecutionResult[]> {
    if (dryRun) {
      this.logger.info(`DRY RUN: Would execute 1 SQL statement from ${source}`);
      this.logger.info(`  Statement: ${formatSqlPreview(sql, 200)}`);
      return [
        {
          success: true,
          statement: sql,
        },
      ];
    }

    // Check connectivity
    const isConnected = await this.sqlGateway.checkConnectivity();
    if (!isConnected) {
      throw new Error(
        `Flink SQL Gateway is not accessible at ${this.config.sql_gateway.url}`
      );
    }

    // Create session
    await this.sqlGateway.createSession();

    try {
      const result = await this.sqlGateway.executeAndWait(sql);

      // Display results
      if (result.success && result.result) {
        this.displayResults(result, source);
      } else if (!result.success) {
        this.logger.error(formatSqlError(result.error || 'Unknown error', false));
      }

      return [result];
    } finally {
      await this.sqlGateway.closeSession();
    }
  }

  /**
   * Execute multiple statements
   */
  private async executeMultipleStatements(
    sql: string,
    dryRun: boolean,
    source: string
  ): Promise<ExecutionResult[]> {
    const statements = splitStatements(sql);

    if (statements.length === 0) {
      this.logger.warn('No SQL statements found');
      return [];
    }

    if (dryRun) {
      this.logger.info(`DRY RUN: Would execute ${statements.length} SQL statement(s) from ${source}`);
      for (const stmt of statements) {
        this.logger.info(`  Statement ${stmt.index + 1}: ${formatSqlPreview(stmt.sql, 150)}`);
      }
      return statements.map((stmt) => ({
        success: true,
        statement: stmt.sql,
      }));
    }

    // Check connectivity
    const isConnected = await this.sqlGateway.checkConnectivity();
    if (!isConnected) {
      throw new Error(
        `Flink SQL Gateway is not accessible at ${this.config.sql_gateway.url}`
      );
    }
    this.logger.info(`✅ Flink SQL Gateway is accessible`);

    // Create session
    await this.sqlGateway.createSession();

    try {
      const results = await this.sqlGateway.executeMultipleStatements(
        statements,
        this.config.execution.continue_on_error
      );

      // Display results
      for (let i = 0; i < results.length; i++) {
        const result = results[i];
        if (result.success && result.result) {
          this.displayResults(result, `${source}_stmt_${i + 1}`);
        } else if (!result.success) {
          this.logger.error(`Statement ${i + 1} failed:`);
          this.logger.error(formatSqlError(result.error || 'Unknown error', false));
        }
      }

      return results;
    } finally {
      await this.sqlGateway.closeSession();
    }
  }

  /**
   * Display query results
   */
  private displayResults(result: ExecutionResult, source: string): void {
    if (!result.result || !result.result.data) {
      this.logger.info(`✅ ${source} completed successfully (${result.duration?.toFixed(1)}s)`);
      return;
    }

    const data = result.result.data;
    const columns = result.result.columns;

    console.log(chalk.blue(`\n📊 Results for ${source}:`));
    console.log('='.repeat(80));

    if (data.length === 0) {
      console.log(chalk.yellow('No rows returned'));
    } else {
      // Create table
      const table = new Table({
        head: columns?.map((col) => chalk.cyan(col.name)) || Object.keys(data[0]).map((k) => chalk.cyan(k)),
        style: { head: [], border: [] },
      });

      // Add rows
      for (const row of data) {
        table.push(Object.values(row).map(String));
      }

      console.log(table.toString());
      console.log(chalk.green(`\n✅ Displayed ${data.length} row(s)`));
    }

    console.log('='.repeat(80));
  }

  /**
   * List all jobs from Flink cluster
   */
  async listJobs(statusFilter?: string, showAll: boolean = false): Promise<void> {
    const jobs = await this.restClient.getAllJobs();

    if (!jobs) {
      this.logger.error('Failed to retrieve jobs from Flink cluster');
      return;
    }

    let filteredJobs = jobs;
    if (statusFilter && !showAll) {
      filteredJobs = jobs.filter((job) => job.state === statusFilter.toUpperCase());
    } else if (!showAll) {
      // By default, show only RUNNING jobs
      filteredJobs = jobs.filter((job) => job.state === 'RUNNING');
    }

    if (filteredJobs.length === 0) {
      this.logger.info('No jobs found matching criteria');
      return;
    }

    // Display jobs in table
    const table = new Table({
      head: [
        chalk.cyan('Job ID'),
        chalk.cyan('Job Name'),
        chalk.cyan('Status'),
        chalk.cyan('Start Time'),
      ],
      style: { head: [], border: [] },
    });

    for (const job of filteredJobs) {
      const jobId = job.jid || job.id || 'unknown';
      const startTime = job['start-time']
        ? new Date(job['start-time']).toISOString()
        : 'N/A';

      table.push([
        jobId.substring(0, 16) + '...',
        job.name || 'unknown',
        this.colorizeStatus(job.state),
        startTime,
      ]);
    }

    console.log(table.toString());
    console.log(chalk.green(`\n✅ Found ${filteredJobs.length} job(s)`));
  }

  /**
   * Colorize job status
   */
  private colorizeStatus(status: string): string {
    switch (status.toUpperCase()) {
      case 'RUNNING':
        return chalk.green(status);
      case 'FAILED':
        return chalk.red(status);
      case 'CANCELED':
      case 'CANCELLED':
        return chalk.yellow(status);
      case 'FINISHED':
        return chalk.blue(status);
      default:
        return status;
    }
  }

  /**
   * Get REST client for advanced operations
   */
  getRestClient(): FlinkRestClient {
    return this.restClient;
  }

  /**
   * Get database instance
   */
  getDatabase(): FlinkJobDatabase | null {
    return this.database;
  }

  /**
   * Get job manager instance
   */
  getJobManager(): FlinkJobManager | null {
    return this.jobManager;
  }

  /**
   * Get environment variables
   */
  getEnvVars(): EnvVars {
    return this.envVars;
  }

  /**
   * Cleanup resources
   */
  async cleanup(): Promise<void> {
    await this.sqlGateway.closeSession();
    if (this.database) {
      this.database.close();
    }
  }
}
