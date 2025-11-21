#!/usr/bin/env node

/**
 * Flink Cluster Monitoring Tool
 * Monitor Apache Flink jobs for exceptions, health status, and performance metrics
 */

import { Command } from 'commander';
import chalk from 'chalk';
import Table from 'cli-table3';
import { FlinkRestClient } from './lib/flink-rest-client.js';
import { loadEnvFile, loadConfig } from './utils/env.js';
import { createLogger } from './utils/logger.js';
import { MonitorOptions } from './types.js';
import * as fs from 'fs';

const program = new Command();

program
  .name('flink-monitor')
  .description('Flink Cluster Monitor - Monitor Flink cluster health and jobs')
  .version('2.0.0');

program
  .option('-e, --env-file <path>', 'Environment file for configuration', '.sbx-uat.env')
  .option('--health', 'Check cluster health')
  .option('--exceptions', 'Show recent exceptions across all jobs')
  .option('--job-id <id>', 'Monitor specific job by ID')
  .option('--detailed', 'Show detailed job information')
  .option('--json', 'Output in JSON format')
  .option('-c, --continuous', 'Continuous monitoring mode')
  .option('-i, --interval <seconds>', 'Polling interval in continuous mode', '10');

program.parse();

const options = program.opts() as MonitorOptions;

async function checkClusterHealth(restClient: FlinkRestClient): Promise<void> {
  console.log(chalk.blue('\n🏥 Flink Cluster Health Check'));
  console.log('='.repeat(50));

  const isConnected = await restClient.checkConnectivity();
  if (!isConnected) {
    console.log(chalk.red('❌ Flink REST API is not accessible'));
    process.exit(1);
  }

  console.log(chalk.green('✅ Flink REST API is accessible'));

  // Get all jobs
  const jobs = await restClient.getAllJobs();
  if (!jobs) {
    console.log(chalk.red('❌ Failed to retrieve jobs'));
    return;
  }

  // Count jobs by status
  const statusCounts: Record<string, number> = {};
  for (const job of jobs) {
    const status = job.state || 'UNKNOWN';
    statusCounts[status] = (statusCounts[status] || 0) + 1;
  }

  console.log(chalk.blue('\n📊 Job Status Summary:'));
  for (const [status, count] of Object.entries(statusCounts)) {
    const color =
      status === 'RUNNING'
        ? chalk.green
        : status === 'FAILED'
        ? chalk.red
        : status === 'CANCELED'
        ? chalk.yellow
        : chalk.white;

    console.log(`  ${color(status)}: ${count}`);
  }

  // Check for failed jobs
  const failedJobs = jobs.filter((job) => job.state === 'FAILED');
  if (failedJobs.length > 0) {
    console.log(chalk.red(`\n⚠️  Found ${failedJobs.length} failed job(s):`));
    for (const job of failedJobs) {
      console.log(`  - ${job.name} (${job.jid || job.id})`);
    }
  } else {
    console.log(chalk.green('\n✅ No failed jobs found'));
  }

  console.log(chalk.blue('\n🎉 Health check completed!\n'));
}

async function showJobDetails(
  restClient: FlinkRestClient,
  jobId: string,
  json: boolean = false
): Promise<void> {
  const jobDetails = await restClient.getJobDetails(jobId);

  if (!jobDetails) {
    console.error(chalk.red(`❌ Failed to get job details for: ${jobId}`));
    process.exit(1);
  }

  if (json) {
    console.log(JSON.stringify(jobDetails, null, 2));
    return;
  }

  console.log(chalk.blue(`\n📋 Job Details: ${jobDetails.name}`));
  console.log('='.repeat(50));
  console.log(`Job ID: ${jobDetails.jid || jobDetails.id}`);
  console.log(`Status: ${colorizeStatus(jobDetails.state)}`);
  console.log(`Start Time: ${jobDetails['start-time'] ? new Date(jobDetails['start-time']).toISOString() : 'N/A'}`);
  console.log(`Duration: ${jobDetails.duration ? (jobDetails.duration / 1000).toFixed(0) + 's' : 'N/A'}`);

  if (jobDetails.vertices && jobDetails.vertices.length > 0) {
    console.log(chalk.blue('\n📊 Vertices:'));
    const table = new Table({
      head: [
        chalk.cyan('Name'),
        chalk.cyan('Parallelism'),
        chalk.cyan('Status'),
      ],
      style: { head: [], border: [] },
    });

    for (const vertex of jobDetails.vertices) {
      table.push([vertex.name, vertex.parallelism.toString(), colorizeStatus(vertex.status)]);
    }

    console.log(table.toString());
  }

  console.log();
}

async function listAllJobs(restClient: FlinkRestClient, json: boolean = false): Promise<void> {
  const jobs = await restClient.getAllJobs();

  if (!jobs) {
    console.error(chalk.red('❌ Failed to retrieve jobs'));
    process.exit(1);
  }

  if (json) {
    console.log(JSON.stringify(jobs, null, 2));
    return;
  }

  if (jobs.length === 0) {
    console.log(chalk.yellow('No jobs found'));
    return;
  }

  const table = new Table({
    head: [
      chalk.cyan('Job ID'),
      chalk.cyan('Name'),
      chalk.cyan('Status'),
      chalk.cyan('Start Time'),
    ],
    style: { head: [], border: [] },
  });

  for (const job of jobs) {
    const jobId = job.jid || job.id || 'unknown';
    const startTime = job['start-time']
      ? new Date(job['start-time']).toISOString()
      : 'N/A';

    table.push([
      jobId.substring(0, 16) + '...',
      job.name || 'unknown',
      colorizeStatus(job.state),
      startTime,
    ]);
  }

  console.log(table.toString());
  console.log(chalk.green(`\n✅ Found ${jobs.length} job(s)`));
}

function colorizeStatus(status: string): string {
  switch (status?.toUpperCase()) {
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
      return status || 'UNKNOWN';
  }
}

async function continuousMonitor(
  restClient: FlinkRestClient,
  intervalSeconds: number
): Promise<void> {
  console.log(chalk.blue(`\n🔄 Starting continuous monitoring (interval: ${intervalSeconds}s)`));
  console.log(chalk.gray('Press Ctrl+C to stop\n'));

  while (true) {
    const timestamp = new Date().toISOString();
    console.log(chalk.gray(`\n[${timestamp}]`));

    await checkClusterHealth(restClient);

    await new Promise((resolve) => setTimeout(resolve, intervalSeconds * 1000));
  }
}

async function main() {
  try {
    // Load environment variables
    if (options.envFile && fs.existsSync(options.envFile)) {
      loadEnvFile(options.envFile);
    }

    // Load configuration
    const config = loadConfig();
    const logger = createLogger('INFO');

    // Create REST client
    const restClient = new FlinkRestClient(config.flink_cluster.url, logger);

    // Execute monitoring operations
    if (options.health) {
      await checkClusterHealth(restClient);
    } else if (options.jobId) {
      await showJobDetails(restClient, options.jobId, options.json || false);
    } else if (options.continuous) {
      const interval = typeof options.interval === 'string' ? parseInt(options.interval) : (options.interval || 10);
      await continuousMonitor(restClient, interval);
    } else {
      // Default: list all jobs
      await listAllJobs(restClient, options.json || false);
    }
  } catch (error: any) {
    console.error(chalk.red(`\n❌ Error: ${error.message}`));
    process.exit(1);
  }
}

main();
