/**
 * Flink REST API Client for job management operations
 */

import axios, { AxiosInstance } from 'axios';
import { FlinkJobDetails, SavepointStatus } from '../types.js';
import type { Logger } from 'winston';

export class FlinkRestClient {
  private restUrl: string;
  private client: AxiosInstance;
  private logger: Logger;

  constructor(restUrl: string, logger: Logger) {
    this.restUrl = restUrl.replace(/\/$/, ''); // Remove trailing slash
    this.logger = logger;
    this.client = axios.create({
      baseURL: this.restUrl,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Get detailed job information from Flink REST API
   */
  async getJobDetails(jobId: string): Promise<FlinkJobDetails | null> {
    try {
      const response = await this.client.get<FlinkJobDetails>(`/jobs/${jobId}`);
      if (response.status === 200) {
        return response.data;
      } else {
        this.logger.warn(`Failed to get job details: ${response.status}`);
        return null;
      }
    } catch (error) {
      this.logger.error(`Error getting job details: ${error}`);
      return null;
    }
  }

  /**
   * Trigger savepoint creation via REST API
   */
  async triggerSavepoint(jobId: string, targetDirectory?: string): Promise<string | null> {
    try {
      const payload: Record<string, string> = {};
      if (targetDirectory) {
        payload['target-directory'] = targetDirectory;
      }

      const response = await this.client.post(`/jobs/${jobId}/savepoints`, payload);

      if (response.status === 202) {
        // Accepted
        return response.data['request-id'];
      } else {
        this.logger.error(`Failed to trigger savepoint: ${response.status} - ${response.data}`);
        return null;
      }
    } catch (error) {
      this.logger.error(`Error triggering savepoint: ${error}`);
      return null;
    }
  }

  /**
   * Get savepoint operation status
   */
  async getSavepointStatus(jobId: string, requestId: string): Promise<SavepointStatus | null> {
    try {
      const url = `/jobs/${jobId}/savepoints/${requestId}`;
      this.logger.debug(`Checking savepoint status at: ${url}`);

      const response = await this.client.get<SavepointStatus>(url);

      this.logger.debug(`Savepoint status response: ${response.status}`);
      if (response.status === 200) {
        this.logger.debug(`Savepoint status result: ${JSON.stringify(response.data)}`);
        return response.data;
      } else {
        this.logger.warn(`Savepoint status check failed: ${response.status} - ${response.data}`);
        return null;
      }
    } catch (error) {
      this.logger.error(`Error getting savepoint status: ${error}`);
      return null;
    }
  }

  /**
   * Stop job with savepoint creation
   */
  async stopJobWithSavepoint(jobId: string): Promise<string | null> {
    try {
      const payload = { mode: 'stop' };

      const response = await this.client.patch(`/jobs/${jobId}`, payload);

      if (response.status === 202) {
        return response.data['request-id'];
      } else {
        this.logger.error(`Failed to stop job with savepoint: ${response.status}`);
        return null;
      }
    } catch (error) {
      this.logger.error(`Error stopping job with savepoint: ${error}`);
      return null;
    }
  }

  /**
   * Get all jobs from Flink cluster with detailed information
   */
  async getAllJobs(): Promise<FlinkJobDetails[] | null> {
    try {
      // First get the list of jobs with basic info
      const response = await this.client.get<{ jobs: Array<{ id: string; status: string }> }>(
        '/jobs'
      );
      if (response.status !== 200) {
        this.logger.error(`Failed to get jobs: ${response.status}`);
        return null;
      }

      const basicJobs = response.data.jobs || [];

      // Get detailed info for each job
      const detailedJobs: FlinkJobDetails[] = [];
      for (const job of basicJobs) {
        const jobId = job.id;
        if (jobId) {
          // Get detailed info for each job
          const detailed = await this.getJobDetails(jobId);
          if (detailed) {
            detailedJobs.push(detailed);
          } else {
            // If we can't get details, use basic info
            detailedJobs.push(job as unknown as FlinkJobDetails);
          }
        }
      }

      return detailedJobs;
    } catch (error) {
      this.logger.error(`Error getting jobs: ${error}`);
      return null;
    }
  }

  /**
   * Cancel a job
   */
  async cancelJob(jobId: string): Promise<boolean> {
    try {
      const response = await this.client.patch(`/jobs/${jobId}`, { mode: 'cancel' });
      return response.status === 202;
    } catch (error) {
      this.logger.error(`Error cancelling job: ${error}`);
      return false;
    }
  }

  /**
   * Create savepoint via REST API
   */
  async createSavepoint(jobId: string, targetDirectory?: string): Promise<string | null> {
    try {
      const payload: Record<string, string> = {};
      if (targetDirectory) {
        payload['target-directory'] = targetDirectory;
      }

      const response = await this.client.post(`/jobs/${jobId}/savepoints`, payload);

      if (response.status === 202) {
        // Accepted
        return response.data['request-id'];
      } else {
        this.logger.error(`Failed to create savepoint: ${response.status} - ${response.data}`);
        return null;
      }
    } catch (error) {
      this.logger.error(`Error creating savepoint: ${error}`);
      return null;
    }
  }

  /**
   * Check if any running jobs are using the specified savepoint path
   */
  async checkJobsUsingSavepoint(savepointPath: string): Promise<FlinkJobDetails[]> {
    try {
      // Get all running jobs from Flink cluster
      const jobs = await this.getAllJobs();
      if (!jobs) {
        return [];
      }

      // Filter for running jobs and check their savepoint paths
      const savepointJobs: FlinkJobDetails[] = [];
      for (const job of jobs) {
        try {
          const jobId = job.jid || job.id;
          const jobState = job.state;

          if (['RUNNING', 'RESTARTING'].includes(jobState) && jobId) {
            // Get job details to check savepoint configuration
            const jobDetails = await this.getJobDetails(jobId);
            if (jobDetails) {
              // Check if job was started from this savepoint
              const executionConfig = jobDetails['execution-config'] || {};
              const jobSavepoint = executionConfig['execution.savepoint.path'];

              if (jobSavepoint === savepointPath) {
                savepointJobs.push({
                  ...job,
                  'savepoint-path': jobSavepoint,
                });
              }
            }
          }
        } catch (error) {
          this.logger.error(`Error checking job savepoint: ${error}`);
          continue;
        }
      }

      return savepointJobs;
    } catch (error) {
      this.logger.error(`Error checking jobs using savepoint: ${error}`);
      return [];
    }
  }

  /**
   * Check connectivity to Flink REST API
   */
  async checkConnectivity(): Promise<boolean> {
    try {
      const response = await this.client.get('/config');
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }
}
