#!/usr/bin/env node

/**
 * Flink SQL Executor CLI
 * Main entry point for the command-line interface
 */

import { Command } from 'commander';
import chalk from 'chalk';
import { FlinkSQLExecutor } from './lib/flink-sql-executor.js';
import { createLogger } from './utils/logger.js';
import { ExecutorOptions, JobManagementOptions } from './types.js';
import * as fs from 'fs';

const program = new Command();

program
  .name('flink-sql')
  .description('Flink SQL Executor - Execute SQL statements and manage Flink jobs')
  .version('2.0.0');

// SQL Execution Options
program
  .option('-f, --file <path>', 'Path to SQL file to execute')
  .option('-s, --sql <query>', 'Inline SQL query to execute')
  .option('-e, --env-file <path>', 'Environment file for variable substitution', '.sbx-uat.env')
  .option('-u, --sql-gateway-url <url>', 'Flink SQL Gateway URL')
  .option('--flink-rest-url <url>', 'Flink REST API URL')
  .option('-d, --dry-run', 'Show what would be executed without running')
  .option('--single-statement', 'Treat input as single statement')
  .option('--continue-on-error', 'Continue executing remaining statements when one fails')
  .option('--stop-on-error', 'Stop execution on first error')
  .option('--format <type>', 'Output format: table, simple, plain, json', 'table')
  .option('--json', 'Output results in JSON format (equivalent to --format json)')
  .option('-v, --verbose', 'Enable verbose logging (DEBUG level)')
  .option('--log-level <level>', 'Logging level: DEBUG, INFO, WARNING, ERROR', 'INFO')
  .option('-l, --log-file <path>', 'Log file path (optional)')
  .option('--debug', 'Enable debug mode with detailed error information')
  .option('--keep-session', 'Keep SQL Gateway session open after execution')
  .option('--config <path>', 'Configuration file path');

// Job Management Options
program
  .option('--list-jobs', 'List all jobs from Flink cluster')
  .option('--job-info <id>', 'Get detailed information about specific job')
  .option('--status-filter <status>', 'Filter jobs by status (RUNNING, FINISHED, CANCELED, FAILED)')
  .option('--cancelled', 'Show only cancelled jobs')
  .option('--show-all', 'Show jobs of all statuses')
  .option('--cancel-job <id>', 'Cancel job gracefully with savepoint')
  .option('--cancel-jobs-by-name <pattern>', 'Cancel all jobs matching regex pattern')
  .option('--pause-job <id>', 'Pause job (create savepoint and stop)')
  .option('--resume-job <id>', 'Resume paused job from latest savepoint')
  .option('--resume-savepoint <id>', 'Resume from specific savepoint ID')
  .option('--resume-sql-file <path>', 'SQL file for resume operations')
  .option('--list-pausable', 'List jobs that can be paused (RUNNING status)')
  .option('--list-resumable', 'List jobs that can be resumed (PAUSED with savepoints)')
  .option('--list-active-savepoints', 'List active savepoint operations')
  .option('--list-savepoints', 'List savepoint history with details')
  .option('--limit <n>', 'Maximum savepoints to display', '10')
  .option('--savepoint-dir <path>', 'Target directory for savepoint storage')
  .option('--enable-database', 'Enable operation database for tracking')
  .option('--disable-database', 'Disable operation database')
  .option('--db-path <path>', 'Path to SQLite database', 'flink_jobs.db');

program.parse();

const options = program.opts() as JobManagementOptions;

async function main() {
  try {
    // Setup logger
    const logLevel = options.verbose ? 'DEBUG' : options.logLevel || 'INFO';
    const logger = createLogger(logLevel, options.logFile);

    // Validate options
    if (!options.file && !options.sql && !options.listJobs && !options.jobInfo &&
        !options.cancelJob && !options.cancelJobsByName && !options.pauseJob && !options.resumeJob &&
        !options.listPausable && !options.listResumable && !options.listSavepoints &&
        !options.listActiveSavepoints && !options.resumeSavepoint) {
      console.error(chalk.red('❌ Error: Must specify --file, --sql, or a job management option'));
      program.help();
      process.exit(1);
    }

    // Check env file exists
    if (options.envFile && !fs.existsSync(options.envFile)) {
      console.warn(chalk.yellow(`⚠️  Environment file not found: ${options.envFile}`));
    }

    // Create executor
    const executor = new FlinkSQLExecutor(options as ExecutorOptions, logger);

    // Initialize database if needed
    if (options.enableDatabase || options.listSavepoints || options.listResumable ||
        options.pauseJob || options.resumeJob || options.resumeSavepoint) {
      executor.initializeDatabase(true, options.dbPath);
    } else if (!options.disableDatabase) {
      // Check if database operations are configured by default
      const enableByDefault = process.env.JOB_MANAGEMENT_ENABLE_DATABASE === 'true';
      if (enableByDefault) {
        executor.initializeDatabase(true, options.dbPath);
      }
    }

    // Execute SQL file or inline query
    if (options.file) {
      const results = await executor.executeFromFile(
        options.file,
        options.dryRun || false,
        options.singleStatement || false
      );

      const successCount = results.filter((r) => r.success).length;
      const failCount = results.length - successCount;

      if (failCount === 0) {
        console.log(chalk.green(`\n✅ All ${results.length} statement(s) executed successfully`));
      } else {
        console.log(
          chalk.yellow(
            `\n⚠️  Completed with ${successCount} success, ${failCount} failed`
          )
        );
        process.exit(1);
      }
    } else if (options.sql) {
      const results = await executor.executeInlineQuery(
        options.sql,
        options.dryRun || false,
        options.singleStatement || false
      );

      const successCount = results.filter((r) => r.success).length;
      const failCount = results.length - successCount;

      if (failCount === 0) {
        console.log(chalk.green(`\n✅ All ${results.length} statement(s) executed successfully`));
      } else {
        console.log(
          chalk.yellow(
            `\n⚠️  Completed with ${successCount} success, ${failCount} failed`
          )
        );
        process.exit(1);
      }
    }

    // Job management operations
    if (options.listJobs) {
      let statusFilter = options.statusFilter;
      if (options.cancelled) {
        statusFilter = 'CANCELED';
      }
      await executor.listJobs(statusFilter, options.showAll || false);
    }

    if (options.jobInfo) {
      const restClient = executor.getRestClient();
      const jobDetails = await restClient.getJobDetails(options.jobInfo);
      if (jobDetails) {
        console.log(JSON.stringify(jobDetails, null, 2));
      } else {
        console.error(chalk.red(`❌ Failed to get job details for: ${options.jobInfo}`));
        process.exit(1);
      }
    }

    if (options.cancelJob) {
      const restClient = executor.getRestClient();
      logger.info(`Cancelling job: ${options.cancelJob}`);
      const success = await restClient.cancelJob(options.cancelJob);
      if (success) {
        console.log(chalk.green(`✅ Job cancelled successfully: ${options.cancelJob}`));
      } else {
        console.error(chalk.red(`❌ Failed to cancel job: ${options.cancelJob}`));
        process.exit(1);
      }
    }

    if (options.cancelJobsByName) {
      const restClient = executor.getRestClient();
      const pattern = new RegExp(options.cancelJobsByName, 'i');

      logger.info(`Finding jobs matching pattern: ${options.cancelJobsByName}`);
      const allJobs = await restClient.getAllJobs();
      if (!allJobs) {
        console.error(chalk.red('❌ Failed to retrieve jobs from cluster'));
        process.exit(1);
      }
      const matchingJobs = allJobs.filter(job => pattern.test(job.name));

      if (matchingJobs.length === 0) {
        console.log(chalk.yellow(`No jobs found matching pattern: ${options.cancelJobsByName}`));
        return;
      }

      console.log(chalk.cyan(`\nFound ${matchingJobs.length} job(s) matching pattern "${options.cancelJobsByName}":`));
      matchingJobs.forEach(job => {
        console.log(chalk.cyan(`  - ${job.name} (${job.jid || job.id})`));
      });

      console.log(chalk.yellow(`\nCancelling ${matchingJobs.length} job(s)...\n`));

      let successCount = 0;
      let failCount = 0;

      for (const job of matchingJobs) {
        const jobId = job.jid || job.id;
        if (!jobId) continue;
        logger.info(`Cancelling job: ${job.name} (${jobId})`);
        const success = await restClient.cancelJob(jobId);
        if (success) {
          console.log(chalk.green(`✅ Cancelled: ${job.name}`));
          successCount++;
        } else {
          console.log(chalk.red(`❌ Failed: ${job.name}`));
          failCount++;
        }
      }

      console.log(chalk.cyan(`\nResults: ${successCount} succeeded, ${failCount} failed`));
      if (failCount > 0) {
        process.exit(1);
      }
    }

    if (options.listSavepoints) {
      const database = executor.getDatabase();
      if (!database) {
        console.error(chalk.red('❌ Database not enabled. Use --enable-database'));
        process.exit(1);
      }

      const limit = typeof options.limit === 'string' ? parseInt(options.limit) : (options.limit || 10);
      const savepoints = database.getSavepoints(undefined, limit);

      if (savepoints.length === 0) {
        console.log(chalk.yellow('No savepoints found'));
      } else {
        console.log(JSON.stringify(savepoints, null, 2));
      }
    }

    // Advanced job management operations
    const jobManager = executor.getJobManager();

    if (options.pauseJob) {
      if (!jobManager) {
        console.error(chalk.red('❌ Database not enabled. Use --enable-database'));
        process.exit(1);
      }

      logger.info(`Pausing job: ${options.pauseJob}`);
      const success = await jobManager.pauseJob(options.pauseJob, options.savepointDir);
      if (!success) {
        console.error(chalk.red(`❌ Failed to pause job: ${options.pauseJob}`));
        process.exit(1);
      }
    }

    if (options.resumeJob) {
      if (!jobManager) {
        console.error(chalk.red('❌ Database not enabled. Use --enable-database'));
        process.exit(1);
      }

      if (!options.resumeSqlFile) {
        console.error(chalk.red('❌ --resume-sql-file is required for resuming jobs'));
        process.exit(1);
      }

      logger.info(`Resuming job: ${options.resumeJob}`);
      const success = await jobManager.resumeJob(options.resumeJob, options.resumeSqlFile);
      if (!success) {
        console.error(chalk.red(`❌ Failed to resume job: ${options.resumeJob}`));
        process.exit(1);
      }
    }

    if (options.resumeSavepoint) {
      if (!jobManager) {
        console.error(chalk.red('❌ Database not enabled. Use --enable-database'));
        process.exit(1);
      }

      if (!options.resumeSqlFile) {
        console.error(chalk.red('❌ --resume-sql-file is required for resuming from savepoint'));
        process.exit(1);
      }

      logger.info(`Resuming from savepoint: ${options.resumeSavepoint}`);
      const success = await jobManager.resumeFromSavepointId(
        options.resumeSavepoint,
        options.resumeSqlFile
      );
      if (!success) {
        console.error(chalk.red(`❌ Failed to resume from savepoint: ${options.resumeSavepoint}`));
        process.exit(1);
      }
    }

    if (options.listPausable) {
      if (!jobManager) {
        console.error(chalk.red('❌ Database not enabled. Use --enable-database'));
        process.exit(1);
      }

      const pausableJobs = await jobManager.listPausableJobs();
      if (pausableJobs.length === 0) {
        console.log(chalk.yellow('No pausable jobs found'));
      } else {
        console.log(chalk.blue(`\n📋 Pausable Jobs (${pausableJobs.length}):`));
        for (const job of pausableJobs) {
          const jobId = job.jid || job.id || 'unknown';
          console.log(`  - ${job.name} (${jobId.substring(0, 16)}...)`);
        }
      }
    }

    if (options.listResumable) {
      if (!jobManager) {
        console.error(chalk.red('❌ Database not enabled. Use --enable-database'));
        process.exit(1);
      }

      const resumableJobs = await jobManager.listResumableJobs();
      if (resumableJobs.length === 0) {
        console.log(chalk.yellow('No resumable jobs found'));
      } else {
        console.log(chalk.blue(`\n📋 Resumable Jobs (${resumableJobs.length}):`));
        for (const job of resumableJobs) {
          console.log(`  - ${job.job_name} (${job.job_id.substring(0, 16)}...)`);
          console.log(`    Savepoint: ${job.savepoint_path}`);
          console.log(`    Created: ${job.created_at}`);
        }
      }
    }

    if (options.listActiveSavepoints) {
      if (!jobManager) {
        console.error(chalk.red('❌ Database not enabled. Use --enable-database'));
        process.exit(1);
      }

      const activeSavepoints = await jobManager.listActiveSavepoints();
      if (activeSavepoints.length === 0) {
        console.log(chalk.yellow('No active savepoints found'));
      } else {
        console.log(JSON.stringify(activeSavepoints, null, 2));
      }
    }

    // Cleanup
    await executor.cleanup();

    if (options.dryRun) {
      console.log(chalk.blue('\n🎉 Dry run completed successfully!'));
    }
  } catch (error: any) {
    console.error(chalk.red(`\n❌ Error: ${error.message}`));
    if (options.debug) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();
