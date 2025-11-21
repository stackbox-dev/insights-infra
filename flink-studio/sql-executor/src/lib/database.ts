/**
 * SQLite database for job management operation tracking
 */

import Database from 'better-sqlite3';
import type { Database as DatabaseType } from 'better-sqlite3';
import { SavepointRecord, JobManagementOperation } from '../types.js';
import type { Logger } from 'winston';

export class FlinkJobDatabase {
  private db: DatabaseType | null = null;
  private logger: Logger;
  private dbPath: string;

  constructor(dbPath: string, logger: Logger) {
    this.dbPath = dbPath;
    this.logger = logger;
  }

  /**
   * Initialize database and create tables
   */
  initialize(): void {
    try {
      this.db = new Database(this.dbPath);
      this.db.pragma('journal_mode = WAL');
      this.db.pragma('foreign_keys = ON');

      this.createTables();
      this.logger.info(`✅ Database initialized at ${this.dbPath}`);
    } catch (error) {
      this.logger.error(`Failed to initialize database: ${error}`);
      throw error;
    }
  }

  /**
   * Create database tables
   */
  private createTables(): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    // Savepoints table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS savepoints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        savepoint_id TEXT NOT NULL UNIQUE,
        job_id TEXT NOT NULL,
        job_name TEXT NOT NULL,
        savepoint_path TEXT,
        status TEXT NOT NULL CHECK(status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED')),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        completed_at TEXT,
        size_bytes INTEGER,
        failure_reason TEXT
      );
    `);

    // Job management operations table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS job_management_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id TEXT NOT NULL,
        job_name TEXT NOT NULL,
        operation_type TEXT NOT NULL CHECK(operation_type IN ('PAUSE', 'RESUME', 'CANCEL')),
        savepoint_id INTEGER,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        metadata TEXT,
        FOREIGN KEY (savepoint_id) REFERENCES savepoints(id)
      );
    `);

    // Resume events table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS resume_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_savepoint_id INTEGER NOT NULL,
        target_job_id TEXT NOT NULL,
        target_job_name TEXT NOT NULL,
        sql_file TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        metadata TEXT,
        FOREIGN KEY (source_savepoint_id) REFERENCES savepoints(id)
      );
    `);

    // Create indexes
    this.db.exec(`
      CREATE INDEX IF NOT EXISTS idx_savepoints_job_id ON savepoints(job_id);
      CREATE INDEX IF NOT EXISTS idx_savepoints_status ON savepoints(status);
      CREATE INDEX IF NOT EXISTS idx_operations_job_id ON job_management_operations(job_id);
      CREATE INDEX IF NOT EXISTS idx_operations_type ON job_management_operations(operation_type);
    `);
  }

  /**
   * Record savepoint creation
   */
  recordSavepoint(
    savepointId: string,
    jobId: string,
    jobName: string,
    status: 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' = 'IN_PROGRESS'
  ): number {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT INTO savepoints (savepoint_id, job_id, job_name, status)
      VALUES (?, ?, ?, ?)
    `);

    const result = stmt.run(savepointId, jobId, jobName, status);
    return result.lastInsertRowid as number;
  }

  /**
   * Update savepoint status
   */
  updateSavepointStatus(
    savepointId: string,
    status: 'COMPLETED' | 'FAILED',
    savepointPath?: string,
    sizeBytes?: number,
    failureReason?: string
  ): void {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      UPDATE savepoints
      SET status = ?,
          completed_at = datetime('now'),
          savepoint_path = COALESCE(?, savepoint_path),
          size_bytes = COALESCE(?, size_bytes),
          failure_reason = COALESCE(?, failure_reason)
      WHERE savepoint_id = ?
    `);

    stmt.run(status, savepointPath || null, sizeBytes || null, failureReason || null, savepointId);
  }

  /**
   * Record job management operation
   */
  recordOperation(
    jobId: string,
    jobName: string,
    operationType: 'PAUSE' | 'RESUME' | 'CANCEL',
    savepointId?: number,
    metadata?: string
  ): number {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT INTO job_management_operations (job_id, job_name, operation_type, savepoint_id, metadata)
      VALUES (?, ?, ?, ?, ?)
    `);

    const result = stmt.run(jobId, jobName, operationType, savepointId || null, metadata || null);
    return result.lastInsertRowid as number;
  }

  /**
   * Get all savepoints, optionally filtered by status
   */
  getSavepoints(status?: string, limit: number = 10): SavepointRecord[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    let query = 'SELECT * FROM savepoints';
    const params: any[] = [];

    if (status) {
      query += ' WHERE status = ?';
      params.push(status);
    }

    query += ' ORDER BY created_at DESC';

    if (limit > 0) {
      query += ' LIMIT ?';
      params.push(limit);
    }

    const stmt = this.db.prepare(query);
    return stmt.all(...params) as SavepointRecord[];
  }

  /**
   * Get savepoint by ID
   */
  getSavepointById(id: number): SavepointRecord | null {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare('SELECT * FROM savepoints WHERE id = ?');
    return (stmt.get(id) as SavepointRecord) || null;
  }

  /**
   * Get latest savepoint for a job
   */
  getLatestSavepoint(jobId: string): SavepointRecord | null {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT * FROM savepoints
      WHERE job_id = ? AND status = 'COMPLETED'
      ORDER BY created_at DESC
      LIMIT 1
    `);

    return (stmt.get(jobId) as SavepointRecord) || null;
  }

  /**
   * Get all operations for a job
   */
  getJobOperations(jobId: string): JobManagementOperation[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT * FROM job_management_operations
      WHERE job_id = ?
      ORDER BY created_at DESC
    `);

    return stmt.all(jobId) as JobManagementOperation[];
  }

  /**
   * Get active (in-progress) savepoints
   */
  getActiveSavepoints(): SavepointRecord[] {
    return this.getSavepoints('IN_PROGRESS', 0);
  }

  /**
   * Get savepoint by job name
   */
  getSavepointByJobName(jobName: string): SavepointRecord | null {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT * FROM savepoints
      WHERE job_name = ? AND status = 'COMPLETED'
      ORDER BY created_at DESC
      LIMIT 1
    `);

    return (stmt.get(jobName) as SavepointRecord) || null;
  }

  /**
   * Search savepoints by partial job name
   */
  searchSavepointsByJobName(jobNamePattern: string): SavepointRecord[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT * FROM savepoints
      WHERE job_name LIKE ? AND status = 'COMPLETED'
      ORDER BY created_at DESC
    `);

    return stmt.all(`%${jobNamePattern}%`) as SavepointRecord[];
  }

  /**
   * Create resume event record
   */
  createResumeEvent(
    savepointId: number,
    targetJobId: string,
    targetJobName: string,
    sqlFile: string,
    metadata?: string
  ): number {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      INSERT INTO resume_events (source_savepoint_id, target_job_id, target_job_name, sql_file, metadata)
      VALUES (?, ?, ?, ?, ?)
    `);

    const result = stmt.run(
      savepointId,
      targetJobId,
      targetJobName,
      sqlFile,
      metadata || null
    );
    return result.lastInsertRowid as number;
  }

  /**
   * Check if savepoint has been used recently
   */
  checkSavepointUsage(savepointPath: string, hoursAgo: number = 24): any[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT re.*, sp.savepoint_path
      FROM resume_events re
      JOIN savepoints sp ON re.source_savepoint_id = sp.id
      WHERE sp.savepoint_path = ?
        AND datetime(re.created_at) > datetime('now', '-${hoursAgo} hours')
      ORDER BY re.created_at DESC
    `);

    return stmt.all(savepointPath);
  }

  /**
   * Get all resume events for a savepoint
   */
  getResumeEventsBySavepoint(savepointId: number): any[] {
    if (!this.db) {
      throw new Error('Database not initialized');
    }

    const stmt = this.db.prepare(`
      SELECT * FROM resume_events
      WHERE source_savepoint_id = ?
      ORDER BY created_at DESC
    `);

    return stmt.all(savepointId);
  }

  /**
   * Close database connection
   */
  close(): void {
    if (this.db) {
      this.db.close();
      this.db = null;
    }
  }
}
