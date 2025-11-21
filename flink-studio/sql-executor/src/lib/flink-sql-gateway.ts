/**
 * Flink SQL Gateway Client for executing SQL statements
 */

import axios, { AxiosInstance } from 'axios';
import {
  StatementResult,
  OperationStatus,
  ExecutionResult,
  ParsedStatement,
} from '../types.js';
import type { Logger } from 'winston';

export class FlinkSQLGatewayClient {
  private gatewayUrl: string;
  private pollInterval: number;
  private maxWaitTime: number;
  private client: AxiosInstance;
  private logger: Logger;
  private sessionHandle: string | null = null;

  constructor(
    gatewayUrl: string,
    _sessionTimeout: number,
    pollInterval: number,
    maxWaitTime: number,
    logger: Logger
  ) {
    this.gatewayUrl = gatewayUrl.replace(/\/$/, '');
    this.pollInterval = pollInterval;
    this.maxWaitTime = maxWaitTime;
    this.logger = logger;

    this.client = axios.create({
      baseURL: this.gatewayUrl,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Check connectivity to SQL Gateway
   */
  async checkConnectivity(): Promise<boolean> {
    try {
      const response = await this.client.get('/v1/info');
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }

  /**
   * Create a new session
   */
  async createSession(properties: Record<string, string> = {}): Promise<string> {
    try {
      const payload = {
        properties: {
          ...properties,
        },
      };

      const response = await this.client.post('/v1/sessions', payload);

      if (response.status === 200) {
        const handle = response.data.sessionHandle as string;
        this.sessionHandle = handle;
        this.logger.info(`✅ SQL Gateway session created: ${handle}`);
        return handle;
      } else {
        throw new Error(`Failed to create session: ${response.status}`);
      }
    } catch (error) {
      this.logger.error(`Error creating session: ${error}`);
      throw error;
    }
  }

  /**
   * Close session
   */
  async closeSession(sessionHandle?: string): Promise<void> {
    const handle = sessionHandle || this.sessionHandle;
    if (!handle) {
      return;
    }

    try {
      await this.client.delete(`/v1/sessions/${handle}`);
      this.logger.info(`✅ Session closed: ${handle}`);
      if (this.sessionHandle === handle) {
        this.sessionHandle = null;
      }
    } catch (error) {
      this.logger.warn(`Failed to close session: ${error}`);
    }
  }

  /**
   * Execute a SQL statement
   */
  async executeStatement(
    sql: string,
    sessionHandle?: string
  ): Promise<{ operationHandle: string; resultType: string }> {
    const handle = sessionHandle || this.sessionHandle;
    if (!handle) {
      throw new Error('No active session. Call createSession first.');
    }

    try {
      const payload = {
        statement: sql,
      };

      const response = await this.client.post(`/v1/sessions/${handle}/statements`, payload);

      if (response.status === 200) {
        return {
          operationHandle: response.data.operationHandle,
          resultType: response.data.resultType || 'UNKNOWN',
        };
      } else {
        throw new Error(`Failed to execute statement: ${response.status}`);
      }
    } catch (error: any) {
      if (error.response?.data?.message) {
        throw new Error(error.response.data.message);
      }
      throw error;
    }
  }

  /**
   * Get operation status
   */
  async getOperationStatus(
    sessionHandle: string,
    operationHandle: string
  ): Promise<OperationStatus> {
    try {
      const response = await this.client.get(
        `/v1/sessions/${sessionHandle}/operations/${operationHandle}/status`
      );

      if (response.status === 200) {
        return response.data;
      } else {
        throw new Error(`Failed to get operation status: ${response.status}`);
      }
    } catch (error) {
      this.logger.error(`Error getting operation status: ${error}`);
      throw error;
    }
  }

  /**
   * Fetch results for an operation
   */
  async fetchResults(
    sessionHandle: string,
    operationHandle: string,
    token: number = 0
  ): Promise<StatementResult> {
    try {
      const response = await this.client.get(
        `/v1/sessions/${sessionHandle}/operations/${operationHandle}/result/${token}`
      );

      if (response.status === 200) {
        return response.data;
      } else {
        throw new Error(`Failed to fetch results: ${response.status}`);
      }
    } catch (error) {
      this.logger.error(`Error fetching results: ${error}`);
      throw error;
    }
  }

  /**
   * Wait for operation to complete and fetch results
   */
  async waitForCompletion(
    sessionHandle: string,
    operationHandle: string
  ): Promise<StatementResult | null> {
    const startTime = Date.now();
    const timeoutMs = this.maxWaitTime * 1000;

    while (true) {
      const elapsed = Date.now() - startTime;
      if (elapsed > timeoutMs) {
        this.logger.warn(`Operation timed out after ${this.maxWaitTime}s`);
        return null;
      }

      const status = await this.getOperationStatus(sessionHandle, operationHandle);

      if (status.status === 'FINISHED') {
        // Fetch results
        try {
          return await this.fetchResults(sessionHandle, operationHandle);
        } catch (error) {
          // Some operations don't have results (DDL, DML)
          return {
            resultType: 'NONE',
          };
        }
      } else if (status.status === 'ERROR') {
        throw new Error('Operation failed with error');
      } else if (status.status === 'CANCELED') {
        throw new Error('Operation was canceled');
      }

      // Wait before polling again
      await this.sleep(this.pollInterval * 1000);
    }
  }

  /**
   * Execute SQL and wait for results
   */
  async executeAndWait(
    sql: string,
    sessionHandle?: string
  ): Promise<ExecutionResult> {
    const startTime = Date.now();

    try {
      const { operationHandle } = await this.executeStatement(sql, sessionHandle);

      const handle = sessionHandle || this.sessionHandle;
      if (!handle) {
        throw new Error('No session handle available');
      }

      const result = await this.waitForCompletion(handle, operationHandle);

      const duration = (Date.now() - startTime) / 1000;

      return {
        success: true,
        statement: sql,
        duration,
        result: result || undefined,
        rowCount: result?.data?.length,
      };
    } catch (error: any) {
      const duration = (Date.now() - startTime) / 1000;
      return {
        success: false,
        statement: sql,
        duration,
        error: error.message || String(error),
      };
    }
  }

  /**
   * Execute multiple statements in sequence
   */
  async executeMultipleStatements(
    statements: ParsedStatement[],
    continueOnError: boolean = true
  ): Promise<ExecutionResult[]> {
    const results: ExecutionResult[] = [];

    for (const stmt of statements) {
      this.logger.info(`Executing statement ${stmt.index + 1}/${statements.length}...`);

      const result = await this.executeAndWait(stmt.sql);
      results.push(result);

      if (!result.success && !continueOnError) {
        this.logger.error(`Statement failed, stopping execution.`);
        break;
      }
    }

    return results;
  }

  /**
   * Sleep utility
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Get current session handle
   */
  getSessionHandle(): string | null {
    return this.sessionHandle;
  }
}
