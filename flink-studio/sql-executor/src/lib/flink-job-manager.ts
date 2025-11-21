/**
 * Flink Job Manager for advanced job lifecycle operations
 * Handles pause, resume, and savepoint management
 */

import { FlinkRestClient } from './flink-rest-client.js';
import { FlinkJobDatabase } from './database.js';
import { FlinkSQLGatewayClient } from './flink-sql-gateway.js';
import { substituteEnvVariables } from '../utils/env.js';
import { splitStatements } from '../utils/sql-parser.js';
import type { Logger } from 'winston';
import type { EnvVars, FlinkJobDetails } from '../types.js';
import * as fs from 'fs';

export class FlinkJobManager {
  private restClient: FlinkRestClient;
  private database: FlinkJobDatabase;
  private sqlGateway: FlinkSQLGatewayClient;
  private logger: Logger;
  private envVars: EnvVars;

  constructor(
    restClient: FlinkRestClient,
    database: FlinkJobDatabase,
    sqlGateway: FlinkSQLGatewayClient,
    logger: Logger,
    envVars: EnvVars = {}
  ) {
    this.restClient = restClient;
    this.database = database;
    this.sqlGateway = sqlGateway;
    this.logger = logger;
    this.envVars = envVars;
  }

  /**
   * Pause a job by creating a savepoint and stopping it
   * Supports both job ID and job name
   */
  async pauseJob(jobIdOrName: string, savepointDir?: string): Promise<boolean> {
    this.logger.info(`⏸️  Pausing job ${jobIdOrName}...`);

    try {
      // Try to find job by ID or name
      const jobDetails = await this.findJobByIdOrName(jobIdOrName);
      if (!jobDetails) {
        this.logger.error(`❌ Job not found: ${jobIdOrName}`);
        return false;
      }

      const jobId = jobDetails.jid || jobDetails.id || '';
      const jobStatus = jobDetails.state;
      const jobName = jobDetails.name || `job_${jobId.substring(0, 8)}`;

      this.logger.info(`Found job: ${jobName} (${jobId})`);

      // Check if job can be paused
      if (!['RUNNING', 'CREATED'].includes(jobStatus)) {
        this.logger.error(`❌ Cannot pause job ${jobId} with status: ${jobStatus}`);
        return false;
      }

      // Check for existing savepoint in progress
      const existingSavepoint = this.database.getLatestSavepoint(jobId);
      if (existingSavepoint && existingSavepoint.status === 'IN_PROGRESS') {
        this.logger.info(`🔄 Resuming existing savepoint creation for job ${jobId}`);
        // TODO: Resume polling if we have request_id in metadata
      }

      // Create new savepoint record in database
      const savepointRecordId = this.database.recordSavepoint(
        `savepoint-${Date.now()}`,
        jobId,
        jobName,
        'IN_PROGRESS'
      );
      this.logger.info(`💾 Creating savepoint for job ${jobId} (${jobName})...`);

      // Trigger savepoint creation via REST API
      const requestId = await this.restClient.triggerSavepoint(jobId, savepointDir);
      if (!requestId) {
        this.database.updateSavepointStatus(
          `savepoint-${Date.now()}`,
          'FAILED',
          undefined,
          undefined,
          'Failed to trigger savepoint creation'
        );
        this.logger.error(`❌ Failed to trigger savepoint for job ${jobId}`);
        return false;
      }

      this.logger.info(`📝 Savepoint request ID: ${requestId}`);

      // Poll for completion
      const success = await this.pollSavepointCompletion(
        jobId,
        jobName,
        requestId,
        savepointRecordId
      );

      return success;
    } catch (error) {
      this.logger.error(`❌ Error pausing job ${jobIdOrName}: ${error}`);
      return false;
    }
  }

  /**
   * Poll for savepoint completion with robust error handling
   */
  private async pollSavepointCompletion(
    jobId: string,
    jobName: string,
    requestId: string,
    savepointRecordId: number
  ): Promise<boolean> {
    const maxWait = 120; // seconds
    const startTime = Date.now();
    const savepointId = `savepoint-${requestId}`;

    while ((Date.now() - startTime) / 1000 < maxWait) {
      const status = await this.restClient.getSavepointStatus(jobId, requestId);
      this.logger.debug(`Savepoint status: ${JSON.stringify(status)}`);

      if (!status) {
        this.logger.warn('No status returned from savepoint status check');
        await this.sleep(2000);
        continue;
      }

      const statusValue = status.status?.id || 'UNKNOWN';
      this.logger.debug(`Status value: ${statusValue}`);

      if (statusValue === 'COMPLETED') {
        const savepointPath = status.operation?.location;
        if (savepointPath) {
          // Update database with final savepoint path
          this.database.updateSavepointStatus(
            savepointId,
            'COMPLETED',
            savepointPath,
            undefined,
            undefined
          );

          // Cancel the job
          const cancelled = await this.restClient.cancelJob(jobId);
          if (cancelled) {
            this.logger.info(`✅ Job ${jobId} (${jobName}) paused successfully`);
            this.logger.info(`📍 Savepoint location: ${savepointPath}`);

            // Record the pause operation
            this.database.recordOperation(jobId, jobName, 'PAUSE', savepointRecordId);
            return true;
          } else {
            this.logger.error(`❌ Failed to cancel job ${jobId} after savepoint creation`);
            return false;
          }
        }
      } else if (statusValue === 'FAILED') {
        const errorMsg =
          status.operation?.['failure-cause']?.['stack-trace'] || 'Unknown error';
        this.database.updateSavepointStatus(
          savepointId,
          'FAILED',
          undefined,
          undefined,
          errorMsg
        );
        this.logger.error(`❌ Savepoint creation failed: ${errorMsg}`);
        return false;
      }

      await this.sleep(2000);
    }

    // Timeout
    this.database.updateSavepointStatus(
      savepointId,
      'FAILED',
      undefined,
      undefined,
      'Savepoint creation timed out'
    );
    this.logger.error(`❌ Savepoint creation timed out for job ${jobId}`);
    return false;
  }

  /**
   * Resume a paused job from its latest savepoint
   * Supports both job ID and job name
   */
  async resumeJob(jobIdOrName: string, sqlFile: string): Promise<boolean> {
    this.logger.info(`▶️  Resuming job ${jobIdOrName}...`);

    try {
      // Try to find savepoint by job ID first
      let savepoint = this.database.getLatestSavepoint(jobIdOrName);

      // If not found, try by job name
      if (!savepoint) {
        savepoint = this.database.getSavepointByJobName(jobIdOrName);
      }

      // If still not found, try partial name match
      if (!savepoint) {
        const matches = this.database.searchSavepointsByJobName(jobIdOrName);
        if (matches.length === 1) {
          savepoint = matches[0];
          this.logger.info(`Found savepoint by partial name match: ${savepoint.job_name}`);
        } else if (matches.length > 1) {
          this.logger.error(
            `❌ Multiple savepoints found for pattern "${jobIdOrName}": ${matches.map((s) => s.job_name).join(', ')}`
          );
          this.logger.error('Please be more specific');
          return false;
        }
      }

      if (!savepoint) {
        this.logger.error(`❌ No savepoint found for job: ${jobIdOrName}`);
        return false;
      }

      if (savepoint.status !== 'COMPLETED') {
        this.logger.error(`❌ Latest savepoint for job ${jobIdOrName} is not in COMPLETED state`);
        return false;
      }

      if (!savepoint.savepoint_path) {
        this.logger.error(`❌ Savepoint path not found for job ${jobIdOrName}`);
        return false;
      }

      this.logger.info(`📍 Resuming from savepoint: ${savepoint.savepoint_path}`);
      this.logger.info(`Job: ${savepoint.job_name} (${savepoint.job_id})`);

      // Resume from the savepoint
      return await this.resumeFromSavepoint(savepoint.id!, sqlFile, savepoint.savepoint_path, savepoint.job_id);
    } catch (error) {
      this.logger.error(`❌ Error resuming job ${jobIdOrName}: ${error}`);
      return false;
    }
  }

  /**
   * Resume from a specific savepoint ID
   */
  async resumeFromSavepointId(savepointId: number, sqlFile: string): Promise<boolean> {
    this.logger.info(`▶️  Resuming from savepoint ID ${savepointId}...`);

    try {
      const savepoint = this.database.getSavepointById(savepointId);
      if (!savepoint) {
        this.logger.error(`❌ Savepoint with ID ${savepointId} not found`);
        return false;
      }

      if (savepoint.status !== 'COMPLETED') {
        this.logger.error(`❌ Savepoint ${savepointId} is not in COMPLETED state`);
        return false;
      }

      if (!savepoint.savepoint_path) {
        this.logger.error(`❌ Savepoint path not found for savepoint ${savepointId}`);
        return false;
      }

      this.logger.info(`📍 Resuming from savepoint: ${savepoint.savepoint_path}`);
      return await this.resumeFromSavepoint(savepointId, sqlFile, savepoint.savepoint_path, savepoint.job_id);
    } catch (error) {
      this.logger.error(`❌ Error resuming from savepoint ${savepointId}: ${error}`);
      return false;
    }
  }

  /**
   * Execute SQL file to resume job from savepoint
   * Includes safety checks and audit tracking
   */
  private async resumeFromSavepoint(
    savepointId: number,
    sqlFile: string,
    savepointPath: string,
    originalJobId: string
  ): Promise<boolean> {
    try {
      // SAFETY CHECK 1: Check if savepoint is already being used by running jobs
      this.logger.info('🔍 Checking if savepoint is already in use...');
      const runningJobs = await this.restClient.checkJobsUsingSavepoint(savepointPath);
      if (runningJobs.length > 0) {
        this.logger.error(
          `❌ Savepoint is already being used by ${runningJobs.length} running job(s):`
        );
        for (const job of runningJobs) {
          const jobId = job.jid || job.id || 'unknown';
          this.logger.error(`   - Job ID: ${jobId}, Name: ${job.name}, State: ${job.state}`);
        }
        this.logger.error('💡 Stop the conflicting jobs before resuming from this savepoint');
        return false;
      }

      // SAFETY CHECK 2: Check database for recent resume events using this savepoint
      const recentResumes = this.database.checkSavepointUsage(savepointPath, 24);
      if (recentResumes.length > 0) {
        this.logger.warn(
          `⚠️  Found ${recentResumes.length} recent resume event(s) for this savepoint (last 24h)`
        );
        for (const resume of recentResumes) {
          this.logger.warn(`   - Started: ${resume.created_at}`);
        }
      }

      // Create resume event record for audit trail
      const resumeEventId = this.database.createResumeEvent(
        savepointId,
        originalJobId,
        'resumed-job',
        sqlFile,
        JSON.stringify({
          savepoint_path: savepointPath,
          initiated_by: 'flink-sql-executor',
          checks_passed: true,
        })
      );
      this.logger.info(`📝 Created resume event record: ${resumeEventId}`);

      // Read SQL file
      if (!fs.existsSync(sqlFile)) {
        this.logger.error(`❌ SQL file not found: ${sqlFile}`);
        return false;
      }

      let sqlContent = fs.readFileSync(sqlFile, 'utf-8');

      // Substitute environment variables
      sqlContent = substituteEnvVariables(sqlContent, this.envVars, true);

      // Add savepoint path to execution properties
      const savepointConfig = `
        SET 'execution.savepoint.path' = '${savepointPath}';
        SET 'execution.savepoint.ignore-unclaimed-state' = 'false';
      `;

      sqlContent = savepointConfig + '\n' + sqlContent;

      // Parse and execute SQL statements
      const statements = splitStatements(sqlContent);
      this.logger.info(`📝 Executing ${statements.length} statement(s) from ${sqlFile}...`);

      // Create session
      await this.sqlGateway.createSession({
        'execution.savepoint.path': savepointPath,
        'execution.savepoint.ignore-unclaimed-state': 'false',
      });

      try {
        const results = await this.sqlGateway.executeMultipleStatements(statements, false);

        const successCount = results.filter((r) => r.success).length;
        const failCount = results.length - successCount;

        if (failCount === 0) {
          this.logger.info(`✅ Job resumed successfully from savepoint`);

          // Record the resume operation
          this.database.recordOperation('resumed-job', sqlFile, 'RESUME', savepointId);
          return true;
        } else {
          this.logger.error(`❌ Failed to resume job: ${failCount} statement(s) failed`);
          return false;
        }
      } finally {
        await this.sqlGateway.closeSession();
      }
    } catch (error) {
      this.logger.error(`❌ Error executing SQL file ${sqlFile}: ${error}`);
      return false;
    }
  }

  /**
   * Find job by ID or name from running jobs
   */
  private async findJobByIdOrName(jobIdOrName: string): Promise<FlinkJobDetails | null> {
    const allJobs = await this.restClient.getAllJobs();
    if (!allJobs) {
      return null;
    }

    // Try to find by exact ID first
    let job = allJobs.find((j) => {
      const jid = j.jid || j.id;
      return jid === jobIdOrName;
    });

    // Try to find by exact name
    if (!job) {
      job = allJobs.find((j) => j.name === jobIdOrName);
    }

    // Try to find by partial name match
    if (!job) {
      const matches = allJobs.filter((j) => j.name?.includes(jobIdOrName));
      if (matches.length === 1) {
        job = matches[0];
        this.logger.info(`Found job by partial name match: ${job.name}`);
      } else if (matches.length > 1) {
        this.logger.error(
          `Multiple jobs found for pattern "${jobIdOrName}": ${matches.map((j) => j.name).join(', ')}`
        );
        this.logger.error('Please be more specific');
        return null;
      }
    }

    return job || null;
  }

  /**
   * List jobs that can be paused (RUNNING status)
   */
  async listPausableJobs(): Promise<FlinkJobDetails[]> {
    const allJobs = await this.restClient.getAllJobs();
    if (!allJobs) {
      return [];
    }

    return allJobs.filter((job) => ['RUNNING', 'CREATED'].includes(job.state));
  }

  /**
   * List jobs that can be resumed (have completed savepoints)
   */
  async listResumableJobs(): Promise<
    Array<{ job_id: string; job_name: string; savepoint_path: string; created_at: string }>
  > {
    // Get all completed savepoints
    const savepoints = this.database.getSavepoints('COMPLETED', 0);

    // Get unique jobs that have savepoints
    const jobMap = new Map<
      string,
      { job_id: string; job_name: string; savepoint_path: string; created_at: string }
    >();

    for (const sp of savepoints) {
      if (!jobMap.has(sp.job_id) && sp.savepoint_path) {
        jobMap.set(sp.job_id, {
          job_id: sp.job_id,
          job_name: sp.job_name,
          savepoint_path: sp.savepoint_path,
          created_at: sp.created_at,
        });
      }
    }

    return Array.from(jobMap.values());
  }

  /**
   * List active (in-progress) savepoint operations
   */
  async listActiveSavepoints() {
    return this.database.getActiveSavepoints();
  }

  /**
   * Helper to sleep for ms milliseconds
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
