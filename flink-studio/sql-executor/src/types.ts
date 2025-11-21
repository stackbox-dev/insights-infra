/**
 * Type definitions for Flink SQL Executor
 */

export interface EnvVars {
  [key: string]: string;
}

export interface FlinkJobDetails {
  jid?: string;
  id?: string;
  name: string;
  state: string;
  'start-time'?: number;
  'end-time'?: number;
  duration?: number;
  vertices?: Array<{
    id: string;
    name: string;
    parallelism: number;
    status: string;
  }>;
  'execution-config'?: {
    'execution.savepoint.path'?: string;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

export interface SavepointStatus {
  status: {
    id: string;
  };
  operation?: {
    location?: string;
    'failure-cause'?: {
      'class': string;
      'stack-trace': string;
    };
  };
}

export interface SavepointRecord {
  id?: number;
  savepoint_id: string;
  job_id: string;
  job_name: string;
  savepoint_path: string | null;
  status: 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';
  created_at: string;
  completed_at: string | null;
  size_bytes: number | null;
  failure_reason: string | null;
}

export interface JobManagementOperation {
  id?: number;
  job_id: string;
  job_name: string;
  operation_type: 'PAUSE' | 'RESUME' | 'CANCEL';
  savepoint_id: number | null;
  created_at: string;
  metadata: string | null;
}

export interface FlinkSQLGatewaySession {
  sessionHandle: string;
}

export interface StatementResult {
  resultType: string;
  data?: Array<Record<string, unknown>>;
  rowCount?: number;
  columns?: Array<{
    name: string;
    logicalType: {
      type: string;
      nullable: boolean;
    };
  }>;
}

export interface OperationStatus {
  status: 'RUNNING' | 'FINISHED' | 'ERROR' | 'CANCELED' | 'PENDING' | 'INITIALIZED';
}

export interface Config {
  sql_gateway: {
    url: string;
    session_timeout: number;
    poll_interval: number;
    max_wait_time: number;
  };
  flink_cluster: {
    url: string;
  };
  job_management: {
    enable_database: boolean;
    database_path: string;
  };
  logging: {
    level: string;
    format: string;
  };
  execution: {
    continue_on_error: boolean;
  };
  connection: {
    timeout: number;
    retry_count: number;
    retry_delay: number;
  };
}

export interface ExecutorOptions {
  sqlFile?: string;
  sql?: string;
  envFile?: string;
  sqlGatewayUrl?: string;
  flinkRestUrl?: string;
  dryRun?: boolean;
  singleStatement?: boolean;
  continueOnError?: boolean;
  stopOnError?: boolean;
  format?: 'table' | 'simple' | 'plain' | 'json';
  verbose?: boolean;
  logLevel?: string;
  logFile?: string;
  debug?: boolean;
  keepSession?: boolean;
  configFile?: string;
}

export interface JobManagementOptions extends ExecutorOptions {
  file?: string;
  listJobs?: boolean;
  jobInfo?: string;
  statusFilter?: string;
  cancelled?: boolean;
  showAll?: boolean;
  cancelJob?: string;
  cancelJobsByName?: string;
  pauseJob?: string;
  resumeJob?: string;
  resumeSavepoint?: number;
  resumeSqlFile?: string;
  listPausable?: boolean;
  listResumable?: boolean;
  listActiveSavepoints?: boolean;
  listSavepoints?: boolean;
  limit?: string | number;
  savepointDir?: string;
  enableDatabase?: boolean;
  disableDatabase?: boolean;
  dbPath?: string;
}

export interface MonitorOptions {
  envFile?: string;
  health?: boolean;
  exceptions?: boolean;
  jobId?: string;
  detailed?: boolean;
  json?: boolean;
  continuous?: boolean;
  interval?: string | number;
}

export interface ParsedStatement {
  sql: string;
  index: number;
}

export interface ExecutionResult {
  success: boolean;
  statement: string;
  duration?: number;
  result?: StatementResult;
  error?: string;
  rowCount?: number;
}
