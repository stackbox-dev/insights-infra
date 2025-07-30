#!/usr/bin/env python3
"""
Flink SQL Executor

This script executes SQL files or inline queries against the Flink SQL Gateway
with comprehensive status checking and error reporting.

Features:
- Executes SQL from individual files or inline queries
- Supports multiple SQL statements in a single file or string
- Provides detailed status monitoring and error reporting
- Configurable error handling (continue on error or stop on first error)
- Supports configuration via command line arguments
- Handles Flink SQL Gateway session management
- Comprehensive logging and debug information

Usage:
    python flink_sql_executor.py --file /path/to/my_query.sql
    python flink_sql_executor.py --sql "SELECT * FROM my_table LIMIT 10"
    python flink_sql_executor.py --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"
    python flink_sql_executor.py --file /path/to/my_query.sql --sql-gateway-url http://localhost:8083
"""

import argparse
import json
import logging
import os
import re
import sqlite3
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import requests
import yaml
from datetime import datetime, timedelta
from tabulate import tabulate
import threading
from contextlib import contextmanager


def load_env_file(env_file_path: str) -> Dict[str, str]:
    """
    Load environment variables from a .env file

    Args:
        env_file_path: Path to the .env file

    Returns:
        Dictionary of environment variables
    """
    env_vars = {}

    if not os.path.exists(env_file_path):
        print(f"⚠️  Environment file not found: {env_file_path}")
        return env_vars

    try:
        with open(env_file_path, "r", encoding="utf-8") as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()

                # Skip empty lines and comments
                if not line or line.startswith("#"):
                    continue

                # Parse KEY=VALUE format
                if "=" in line:
                    key, value = line.split("=", 1)
                    key = key.strip()
                    value = value.strip()

                    # Remove quotes if present
                    if (value.startswith('"') and value.endswith('"')) or (
                        value.startswith("'") and value.endswith("'")
                    ):
                        value = value[1:-1]

                    env_vars[key] = value
                else:
                    print(
                        f"⚠️  Invalid format in {env_file_path} line {line_num}: {line}"
                    )

        print(f"✅ Loaded {len(env_vars)} environment variables from {env_file_path}")
        return env_vars

    except Exception as e:
        print(f"❌ Error reading environment file {env_file_path}: {e}")
        return env_vars


def substitute_env_variables(
    sql_content: str, env_vars: Dict[str, str], strict: bool = True
) -> str:
    """
    Substitute environment variables in SQL content

    Args:
        sql_content: SQL content with ${VAR_NAME} placeholders
        env_vars: Dictionary of environment variables
        strict: If True, raises error when required variables are missing

    Returns:
        SQL content with variables substituted

    Raises:
        ValueError: If strict=True and required variables are missing
    """
    if not sql_content:
        return sql_content

    # Pattern to match ${VARIABLE_NAME}
    pattern = r"\$\{([^}]+)\}"

    # Find all variables in the SQL content
    required_vars = re.findall(pattern, sql_content)
    if not required_vars:
        return sql_content

    # Check for missing variables
    missing_vars = []
    available_vars = env_vars or {}

    for var_name in required_vars:
        if var_name not in available_vars:
            missing_vars.append(var_name)

    # Handle missing variables
    if missing_vars:
        if strict:
            missing_list = ", ".join(missing_vars)
            raise ValueError(
                f"SQL file contains {len(missing_vars)} required environment variable(s) that are not provided: {missing_list}. "
                f"Please provide these variables via environment file (.env) or environment variables."
            )
        else:
            print(
                f"⚠️  Warning: {len(missing_vars)} environment variable(s) not found: {', '.join(missing_vars)}"
            )

    # Perform substitution
    def replace_var(match):
        var_name = match.group(1)
        if var_name in available_vars:
            return available_vars[var_name]
        else:
            return match.group(0)  # Return original placeholder if variable not found

    substituted_content = re.sub(pattern, replace_var, sql_content)

    # Report successful substitutions
    successful_vars = [var for var in required_vars if var in available_vars]
    if successful_vars:
        print(
            f"✅ Substituted {len(successful_vars)} environment variable(s): {', '.join(set(successful_vars))}"
        )

    return substituted_content


class FlinkJobDatabase:
    """
    Manages SQLite database operations for job persistence and management
    """

    def __init__(self, db_path: str = "flink_jobs.db"):
        self.db_path = db_path
        self.logger = logging.getLogger(__name__)
        self._lock = threading.Lock()
        self._init_database()

    @contextmanager
    def get_connection(self):
        """Get a database connection with proper locking"""
        with self._lock:
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row  # Enable dict-like access
            try:
                yield conn
            finally:
                conn.close()

    def _init_database(self):
        """Initialize database with required tables"""
        with self.get_connection() as conn:
            # Enhanced Savepoints table - stores everything we need for pause/resume
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS savepoints (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    job_id TEXT NOT NULL,
                    job_name TEXT,
                    savepoint_path TEXT NOT NULL,
                    savepoint_type TEXT NOT NULL DEFAULT 'MANUAL',
                    job_status TEXT DEFAULT 'UNKNOWN',
                    sql_content TEXT,
                    tags TEXT DEFAULT '[]',
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    created_by TEXT DEFAULT 'sql-executor',
                    is_latest BOOLEAN DEFAULT FALSE,
                    metadata TEXT DEFAULT '{}',
                    flink_start_time TEXT,
                    session_handle TEXT,
                    description TEXT,
                    request_id TEXT,
                    savepoint_status TEXT DEFAULT 'COMPLETED'
                )
            """
            )

            # Create resume events table for audit and tracking
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS resume_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    savepoint_id INTEGER NOT NULL,
                    original_job_id TEXT NOT NULL,
                    new_job_id TEXT,
                    savepoint_path TEXT NOT NULL,
                    sql_file_path TEXT NOT NULL,
                    resume_status TEXT DEFAULT 'STARTED',
                    error_message TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    completed_at DATETIME,
                    metadata TEXT DEFAULT '{}',
                    FOREIGN KEY (savepoint_id) REFERENCES savepoints (id)
                )
            """
            )

            # Add new columns to existing table if they don't exist
            try:
                conn.execute("ALTER TABLE savepoints ADD COLUMN request_id TEXT")
            except:
                pass  # Column already exists

            try:
                conn.execute(
                    "ALTER TABLE savepoints ADD COLUMN savepoint_status TEXT DEFAULT 'COMPLETED'"
                )
            except:
                pass  # Column already exists

            # Create indexes for better performance
            conn.execute("CREATE INDEX IF NOT EXISTS idx_job_id ON savepoints(job_id)")
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_job_name ON savepoints(job_name)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_is_latest ON savepoints(is_latest)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_job_status ON savepoints(job_status)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_savepoint_status ON savepoints(savepoint_status)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_resume_savepoint_id ON resume_events(savepoint_id)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_resume_original_job_id ON resume_events(original_job_id)"
            )

            conn.commit()
            self.logger.debug(f"Database initialized at {self.db_path}")

    def store_savepoint(
        self,
        job_id: str,
        savepoint_path: str,
        savepoint_type: str = "MANUAL",
        metadata: Dict = None,
        job_name: str = None,
        sql_content: str = None,
    ):
        """Store savepoint information - simplified to just store savepoint data"""
        with self.get_connection() as conn:
            # Insert new savepoint entry
            conn.execute(
                """
                INSERT INTO savepoints 
                (job_id, job_name, savepoint_path, savepoint_type, job_status, sql_content, 
                 tags, is_latest, session_handle, description, metadata, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, ?, ?, ?, ?)
            """,
                (
                    job_id,
                    (
                        job_name or metadata.get("job_name")
                        if metadata
                        else f"job_{job_id[:8]}"
                    ),
                    savepoint_path,
                    savepoint_type,
                    "SAVEPOINT_CREATED",
                    sql_content,
                    "[]",  # Empty tags
                    None,  # No session handle
                    f"Savepoint created via {savepoint_type}",
                    json.dumps(metadata or {}),
                    datetime.now().isoformat(),
                ),
            )

            conn.commit()

    def get_latest_savepoint(self, job_id: str) -> Optional[Dict]:
        """Get the latest savepoint for a job"""
        with self.get_connection() as conn:
            row = conn.execute(
                """
                SELECT * FROM savepoints 
                WHERE job_id = ? AND is_latest = TRUE
                    AND savepoint_path != 'RUNNING_JOB'
                ORDER BY created_at DESC LIMIT 1
            """,
                (job_id,),
            ).fetchone()

            if row:
                savepoint = dict(row)
                savepoint["metadata"] = json.loads(savepoint["metadata"] or "{}")
                return savepoint
            return None

    def list_savepoints(self, job_id: str) -> List[Dict]:
        """List all savepoints for a job"""
        with self.get_connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM savepoints 
                WHERE job_id = ? AND savepoint_path != 'RUNNING_JOB'
                ORDER BY created_at DESC
            """,
                (job_id,),
            ).fetchall()

            savepoints = []
            for row in rows:
                savepoint = dict(row)
                savepoint["metadata"] = json.loads(savepoint["metadata"] or "{}")
                savepoints.append(savepoint)

            return savepoints

    def list_all_savepoints(self) -> List[Dict]:
        """List all savepoints in the database"""
        with self.get_connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM savepoints 
                WHERE savepoint_path != 'RUNNING_JOB'
                ORDER BY created_at DESC
            """
            ).fetchall()

            savepoints = []
            for row in rows:
                savepoint = dict(row)
                savepoint["metadata"] = json.loads(savepoint["metadata"] or "{}")
                savepoints.append(savepoint)

            return savepoints

    def get_savepoint_status_for_job(self, job_id: str) -> Optional[Dict]:
        """Get the current savepoint status for a job with smart decision logic"""
        with self.get_connection() as conn:
            row = conn.execute(
                """
                SELECT * FROM savepoints 
                WHERE job_id = ? AND is_latest = TRUE
                ORDER BY created_at DESC LIMIT 1
            """,
                (job_id,),
            ).fetchone()

            if not row:
                return None

            savepoint = dict(row)
            savepoint["metadata"] = json.loads(savepoint["metadata"] or "{}")

            # Check if IN_PROGRESS savepoint is stale (> 5 minutes old)
            if savepoint.get("savepoint_status") == "IN_PROGRESS":
                created_at = datetime.fromisoformat(savepoint["created_at"])
                age_minutes = (datetime.now() - created_at).total_seconds() / 60

                if age_minutes > 5:
                    # Mark stale savepoint as FAILED
                    self.logger.warning(
                        f"Marking stale savepoint as FAILED (age: {age_minutes:.1f} min)"
                    )
                    self.update_savepoint_status(savepoint["id"], "FAILED")
                    savepoint["savepoint_status"] = "FAILED"

            return savepoint

    def update_savepoint_status(
        self,
        savepoint_id: int,
        status: str,
        request_id: str = None,
        savepoint_path: str = None,
        metadata_update: Dict = None,
    ):
        """Update savepoint status and related fields"""
        with self.get_connection() as conn:
            updates = ["savepoint_status = ?"]
            params = [status]

            if request_id:
                updates.append("request_id = ?")
                params.append(request_id)

            if savepoint_path:
                updates.append("savepoint_path = ?")
                params.append(savepoint_path)

            if metadata_update:
                # Get current metadata and merge
                current = conn.execute(
                    "SELECT metadata FROM savepoints WHERE id = ?", (savepoint_id,)
                ).fetchone()
                current_metadata = (
                    json.loads(current["metadata"] or "{}") if current else {}
                )
                current_metadata.update(metadata_update)
                updates.append("metadata = ?")
                params.append(json.dumps(current_metadata))

            params.append(savepoint_id)
            query = f"UPDATE savepoints SET {', '.join(updates)} WHERE id = ?"

            conn.execute(query, params)
            conn.commit()

    def get_active_savepoints(self) -> List[Dict]:
        """Get all active savepoints (IN_PROGRESS status)"""
        with self.get_connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM savepoints
                WHERE savepoint_status = 'IN_PROGRESS'
                ORDER BY created_at DESC
            """
            ).fetchall()

            savepoints = []
            for row in rows:
                savepoint = dict(row)
                savepoint["metadata"] = json.loads(savepoint["metadata"] or "{}")

                # Calculate age
                created_at = datetime.fromisoformat(savepoint["created_at"])
                age_seconds = (datetime.now() - created_at).total_seconds()
                savepoint["age_minutes"] = age_seconds / 60
                savepoint["is_stale"] = age_seconds > 300  # 5 minutes

                savepoints.append(savepoint)

            return savepoints

    def get_savepoint_details(self, job_id: str = None) -> List[Dict]:
        """Get detailed savepoint information, optionally filtered by job_id"""
        with self.get_connection() as conn:
            if job_id:
                query = """
                    SELECT * FROM savepoints 
                    WHERE job_id = ?
                    ORDER BY created_at DESC
                """
                params = (job_id,)
            else:
                query = """
                    SELECT * FROM savepoints 
                    ORDER BY created_at DESC
                """
                params = ()

            rows = conn.execute(query, params).fetchall()

            savepoints = []
            for row in rows:
                savepoint = dict(row)
                savepoint["metadata"] = json.loads(savepoint["metadata"] or "{}")

                # Calculate age
                created_at = datetime.fromisoformat(savepoint["created_at"])
                age_seconds = (datetime.now() - created_at).total_seconds()
                savepoint["age_minutes"] = age_seconds / 60
                savepoint["age_formatted"] = self._format_duration(age_seconds)

                savepoints.append(savepoint)

            return savepoints

    def _format_duration(self, seconds: float) -> str:
        """Format duration in human-readable format"""
        if seconds < 60:
            return f"{int(seconds)}s"
        elif seconds < 3600:
            return f"{int(seconds/60)}m {int(seconds%60)}s"
        else:
            hours = int(seconds / 3600)
            minutes = int((seconds % 3600) / 60)
            return f"{hours}h {minutes}m"

    def create_savepoint_record(
        self, job_id: str, job_name: str, savepoint_type: str = "PAUSE"
    ) -> int:
        """Create initial savepoint record with IN_PROGRESS status"""
        with self.get_connection() as conn:
            # Mark all existing entries as not latest
            conn.execute(
                "UPDATE savepoints SET is_latest = FALSE WHERE job_id = ?", (job_id,)
            )

            # Insert new IN_PROGRESS savepoint entry
            cursor = conn.execute(
                """
                INSERT INTO savepoints 
                (job_id, job_name, savepoint_path, savepoint_type, savepoint_status, 
                 is_latest, metadata)
                VALUES (?, ?, ?, ?, 'IN_PROGRESS', TRUE, ?)
            """,
                (
                    job_id,
                    job_name,
                    f"IN_PROGRESS_{job_id}_{int(time.time())}",  # Temporary placeholder
                    savepoint_type,
                    json.dumps(
                        {
                            "started_at": datetime.now().isoformat(),
                            "status": "savepoint_creation_initiated",
                        }
                    ),
                ),
            )

            conn.commit()
            return cursor.lastrowid
        """Get all jobs that can be resumed (PAUSED status with actual savepoints)"""
        with self.get_connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM savepoints
                WHERE is_latest = TRUE 
                    AND job_status = 'PAUSED'
                    AND savepoint_path != 'RUNNING_JOB'
                ORDER BY created_at DESC
            """
            ).fetchall()

            jobs = []
            for row in rows:
                job = dict(row)
                job["tags"] = json.loads(job["tags"] or "[]")
                job["metadata"] = json.loads(job["metadata"] or "{}")
                job["status"] = job["job_status"]  # Alias for compatibility
                jobs.append(job)
            return jobs

    # Resume Event Management Methods
    def create_resume_event(
        self,
        savepoint_id: int,
        original_job_id: str,
        savepoint_path: str,
        sql_file_path: str,
        metadata: Dict = None,
    ) -> int:
        """Create a new resume event record"""
        with self.get_connection() as conn:
            cursor = conn.execute(
                """
                INSERT INTO resume_events 
                (savepoint_id, original_job_id, savepoint_path, sql_file_path, 
                 resume_status, metadata)
                VALUES (?, ?, ?, ?, 'STARTED', ?)
            """,
                (
                    savepoint_id,
                    original_job_id,
                    savepoint_path,
                    sql_file_path,
                    json.dumps(metadata or {}),
                ),
            )

            conn.commit()
            return cursor.lastrowid

    def update_resume_event(
        self,
        resume_event_id: int,
        status: str,
        new_job_id: str = None,
        error_message: str = None,
        metadata_update: Dict = None,
    ):
        """Update resume event with completion status"""
        with self.get_connection() as conn:
            updates = ["resume_status = ?"]
            params = [status]

            if new_job_id:
                updates.append("new_job_id = ?")
                params.append(new_job_id)

            if error_message:
                updates.append("error_message = ?")
                params.append(error_message)

            if status in ["COMPLETED", "FAILED"]:
                updates.append("completed_at = ?")
                params.append(datetime.now().isoformat())

            if metadata_update:
                # Get current metadata and merge
                current = conn.execute(
                    "SELECT metadata FROM resume_events WHERE id = ?",
                    (resume_event_id,),
                ).fetchone()
                current_metadata = (
                    json.loads(current["metadata"] or "{}") if current else {}
                )
                current_metadata.update(metadata_update)
                updates.append("metadata = ?")
                params.append(json.dumps(current_metadata))

            params.append(resume_event_id)
            query = f"UPDATE resume_events SET {', '.join(updates)} WHERE id = ?"

            conn.execute(query, params)
            conn.commit()

    def get_resume_events(
        self, savepoint_id: int = None, original_job_id: str = None
    ) -> List[Dict]:
        """Get resume events, optionally filtered by savepoint_id or original_job_id"""
        with self.get_connection() as conn:
            if savepoint_id:
                query = "SELECT * FROM resume_events WHERE savepoint_id = ? ORDER BY created_at DESC"
                params = (savepoint_id,)
            elif original_job_id:
                query = "SELECT * FROM resume_events WHERE original_job_id = ? ORDER BY created_at DESC"
                params = (original_job_id,)
            else:
                query = "SELECT * FROM resume_events ORDER BY created_at DESC"
                params = ()

            rows = conn.execute(query, params).fetchall()

            events = []
            for row in rows:
                event = dict(row)
                event["metadata"] = json.loads(event["metadata"] or "{}")
                events.append(event)

            return events

    def check_savepoint_usage(self, savepoint_path: str) -> List[Dict]:
        """Check if a savepoint is currently being used by running jobs"""
        with self.get_connection() as conn:
            # Check recent resume events that might still be running
            recent_resumes = conn.execute(
                """
                SELECT * FROM resume_events 
                WHERE savepoint_path = ? 
                AND resume_status = 'STARTED'
                AND created_at > datetime('now', '-1 hour')
                ORDER BY created_at DESC
            """,
                (savepoint_path,),
            ).fetchall()

            return [dict(row) for row in recent_resumes]


class FlinkRestClient:
    """
    Direct REST API client for advanced Flink operations
    """

    def __init__(self, rest_url: str):
        self.rest_url = rest_url.rstrip("/")
        self.logger = logging.getLogger(__name__)

    def get_job_details(self, job_id: str) -> Optional[Dict]:
        """Get detailed job information from Flink REST API"""
        try:
            response = requests.get(f"{self.rest_url}/jobs/{job_id}", timeout=10)
            if response.status_code == 200:
                job_details = response.json()
                # Debug: log available fields (only in debug mode)
                # self.logger.debug(f"Available fields for job {job_id}: {list(job_details.keys())}")
                return job_details
            else:
                self.logger.warning(
                    f"Failed to get job details: {response.status_code}"
                )
                return None
        except requests.RequestException as e:
            self.logger.error(f"Error getting job details: {e}")
            return None

    def trigger_savepoint(
        self, job_id: str, target_directory: str = None
    ) -> Optional[str]:
        """Trigger savepoint creation via REST API"""
        try:
            payload = {}
            if target_directory:
                payload["target-directory"] = target_directory

            response = requests.post(
                f"{self.rest_url}/jobs/{job_id}/savepoints", json=payload, timeout=30
            )

            if response.status_code == 202:  # Accepted
                result = response.json()
                return result.get("request-id")
            else:
                self.logger.error(
                    f"Failed to trigger savepoint: {response.status_code} - {response.text}"
                )
                return None

        except requests.RequestException as e:
            self.logger.error(f"Error triggering savepoint: {e}")
            return None

    def get_savepoint_status(self, job_id: str, request_id: str) -> Optional[Dict]:
        """Get savepoint operation status"""
        try:
            url = f"{self.rest_url}/jobs/{job_id}/savepoints/{request_id}"
            self.logger.debug(f"Checking savepoint status at: {url}")

            response = requests.get(url, timeout=10)

            self.logger.debug(f"Savepoint status response: {response.status_code}")
            if response.status_code == 200:
                result = response.json()
                self.logger.debug(f"Savepoint status result: {result}")
                return result
            else:
                self.logger.warning(
                    f"Savepoint status check failed: {response.status_code} - {response.text}"
                )
                return None

        except requests.RequestException as e:
            self.logger.error(f"Error getting savepoint status: {e}")
            return None

    def stop_job_with_savepoint(self, job_id: str) -> Optional[str]:
        """Stop job with savepoint creation"""
        try:
            payload = {"mode": "stop"}

            response = requests.patch(
                f"{self.rest_url}/jobs/{job_id}", json=payload, timeout=30
            )

            if response.status_code == 202:
                result = response.json()
                return result.get("request-id")
            else:
                self.logger.error(
                    f"Failed to stop job with savepoint: {response.status_code}"
                )
                return None

        except requests.RequestException as e:
            self.logger.error(f"Error stopping job with savepoint: {e}")
            return None

    def get_all_jobs(self) -> Optional[List[Dict]]:
        """Get all jobs from Flink cluster with detailed information"""
        try:
            # First get the list of jobs with basic info
            response = requests.get(f"{self.rest_url}/jobs", timeout=10)
            if response.status_code != 200:
                self.logger.error(f"Failed to get jobs: {response.status_code}")
                return None

            result = response.json()
            basic_jobs = result.get("jobs", [])

            # Get detailed info for each job
            detailed_jobs = []
            for job in basic_jobs:
                job_id = job.get("id")
                if job_id:
                    # Get detailed info for each job
                    detailed = self.get_job_details(job_id)
                    if detailed:
                        detailed_jobs.append(detailed)
                    else:
                        # If we can't get details, use basic info
                        detailed_jobs.append(job)

            return detailed_jobs
        except requests.RequestException as e:
            self.logger.error(f"Error getting jobs: {e}")
            return None
        except Exception as e:
            self.logger.error(f"Error getting detailed jobs: {e}")
            return None

    def cancel_job(self, job_id: str) -> bool:
        """Cancel a job"""
        try:
            response = requests.patch(
                f"{self.rest_url}/jobs/{job_id}", json={"mode": "cancel"}, timeout=30
            )
            return response.status_code == 202
        except requests.RequestException as e:
            self.logger.error(f"Error cancelling job: {e}")
            return False

    def create_savepoint(
        self, job_id: str, target_directory: str = None
    ) -> Optional[str]:
        """Create savepoint via REST API"""
        try:
            payload = {}
            if target_directory:
                payload["target-directory"] = target_directory

            response = requests.post(
                f"{self.rest_url}/jobs/{job_id}/savepoints", json=payload, timeout=30
            )

            if response.status_code == 202:  # Accepted
                result = response.json()
                return result.get("request-id")
            else:
                self.logger.error(
                    f"Failed to create savepoint: {response.status_code} - {response.text}"
                )
                return None

        except requests.RequestException as e:
            self.logger.error(f"Error creating savepoint: {e}")
            return None

    def check_jobs_using_savepoint(self, savepoint_path: str) -> List[Dict]:
        """Check if any running jobs are using the specified savepoint path"""
        try:
            # Get all running jobs from Flink cluster
            jobs = self.get_all_jobs()
            if not jobs:
                return []

            # Filter for running jobs and check their savepoint paths
            savepoint_jobs = []
            for job in jobs:
                try:
                    job_id = job.get("jid") or job.get("id")  # Try both field names
                    job_state = job.get("state") or job.get("status")

                    if job_state in ["RUNNING", "RESTARTING"] and job_id:
                        # Get job details to check savepoint configuration
                        job_details = self.get_job_details(job_id)
                        if job_details:
                            # Check if job was started from this savepoint
                            execution_config = job_details.get("execution-config", {})
                            job_savepoint = execution_config.get(
                                "execution.savepoint.path"
                            )

                            if job_savepoint == savepoint_path:
                                savepoint_jobs.append(
                                    {
                                        "job_id": job_id,
                                        "job_name": job.get("name", "unknown"),
                                        "state": job_state,
                                        "savepoint_path": job_savepoint,
                                        "start_time": job.get("start-time"),
                                    }
                                )
                except Exception as job_error:
                    self.logger.debug(f"Error processing job {job}: {job_error}")
                    continue

            return savepoint_jobs

        except Exception as e:
            self.logger.error(f"Error checking jobs using savepoint: {e}")
            return []


class FlinkJobManager:
    """
    Simplified job management - only for savepoint operations and resume
    """

    def __init__(
        self, executor, database: FlinkJobDatabase, rest_client: FlinkRestClient
    ):
        self.executor = executor
        self.database = database
        self.rest_client = rest_client  # Mandatory - no optional fallback
        self.logger = logging.getLogger(__name__)

    def stop_job_with_savepoint(self, job_id: str) -> bool:
        """Stop job gracefully with savepoint creation using REST API only"""
        self.logger.info(f"🛑 Stopping job {job_id} with savepoint...")

        try:
            request_id = self.rest_client.stop_job_with_savepoint(job_id)
            if not request_id:
                self.logger.error(
                    f"❌ Failed to trigger stop with savepoint for job {job_id}"
                )
                return False

            # Poll for completion to get actual savepoint path
            max_wait = 60
            start_time = time.time()

            while time.time() - start_time < max_wait:
                status = self.rest_client.get_savepoint_status(job_id, request_id)
                if not status:
                    break

                if status.get("status") == "COMPLETED":
                    savepoint_path = status.get("operation", {}).get("location")
                    if savepoint_path:
                        # Get job info from Flink to store with savepoint
                        job_info = self._get_job_info_from_flink(job_id)
                        job_name = (
                            job_info.get("name", f"job_{job_id[:8]}")
                            if job_info
                            else f"job_{job_id[:8]}"
                        )

                        # Store the actual savepoint path with job metadata
                        self.database.store_savepoint(
                            job_id,
                            savepoint_path,
                            "STOP_WITH_SAVEPOINT",
                            {
                                "stopped_at": datetime.now().isoformat(),
                                "method": "REST_API",
                            },
                            job_name=job_name,
                        )
                        self.logger.info(
                            f"✅ Job {job_id} stopped with savepoint: {savepoint_path}"
                        )
                        return True
                    break
                elif status.get("status") == "FAILED":
                    error_msg = status.get("operation", {}).get(
                        "failure-cause", "Unknown error"
                    )
                    self.logger.error(f"❌ Stop with savepoint failed: {error_msg}")
                    break

                time.sleep(2)

            self.logger.error(f"❌ Stop with savepoint timed out for job {job_id}")
            return False

        except Exception as e:
            self.logger.error(f"❌ Error stopping job {job_id}: {e}")
            return False

    def pause_job(self, job_id: str, savepoint_dir: str = "/tmp/savepoints") -> bool:
        """Pause a job by creating a savepoint and stopping it using Flink REST API"""
        self.logger.info(f"⏸️ Pausing job {job_id}...")

        # Get job details from Flink REST API
        job_details = self.rest_client.get_job_details(job_id)
        if not job_details:
            self.logger.error(f"❌ Job {job_id} not found in Flink cluster")
            return False

        job_status = job_details.get("state", "UNKNOWN")
        job_name = job_details.get("name", f"job_{job_id[:8]}")

        # Smart savepoint status check
        existing_savepoint = self.database.get_savepoint_status_for_job(job_id)

        if existing_savepoint:
            sp_status = existing_savepoint.get("savepoint_status", "COMPLETED")

            if sp_status == "COMPLETED":
                if job_status == "CANCELED":
                    self.logger.info(f"✅ Job {job_id} is already paused")
                    self.logger.info(
                        f"📍 Existing savepoint: {existing_savepoint['savepoint_path']}"
                    )
                    return True
                else:
                    self.logger.info(
                        f"🔄 Job {job_id} was restarted after savepoint, creating new savepoint"
                    )

            elif sp_status == "IN_PROGRESS":
                # Resume polling for the existing savepoint
                request_id = existing_savepoint.get("request_id")
                if request_id:
                    self.logger.info(f"🔄 Resuming savepoint creation for job {job_id}")
                    return self._poll_savepoint_completion(
                        job_id, job_name, request_id, existing_savepoint["id"]
                    )
                else:
                    self.logger.warning(
                        f"⚠️ IN_PROGRESS savepoint missing request_id, creating new"
                    )

        # Check if job can be paused
        if job_status not in ["RUNNING", "CREATED"]:
            self.logger.error(f"❌ Cannot pause job {job_id} with status: {job_status}")
            return False

        # Create new savepoint record in database FIRST
        savepoint_record_id = self.database.create_savepoint_record(
            job_id, job_name, "PAUSE"
        )
        self.logger.info(f"💾 Creating savepoint for job {job_id} ({job_name})...")

        # Trigger savepoint creation via REST API
        request_id = self.rest_client.trigger_savepoint(job_id, savepoint_dir)
        self.logger.info(f"Savepoint request ID: {request_id}")

        if not request_id:
            # Mark as failed in database
            self.database.update_savepoint_status(
                savepoint_record_id,
                "FAILED",
                metadata_update={"error": "Failed to trigger savepoint creation"},
            )
            self.logger.error(f"❌ Failed to trigger savepoint for job {job_id}")
            return False

        # Update database with request_id
        self.database.update_savepoint_status(
            savepoint_record_id, "IN_PROGRESS", request_id
        )

        # Poll for completion
        return self._poll_savepoint_completion(
            job_id, job_name, request_id, savepoint_record_id
        )

    def _poll_savepoint_completion(
        self, job_id: str, job_name: str, request_id: str, savepoint_record_id: int
    ) -> bool:
        """Poll for savepoint completion with robust error handling"""
        max_wait = 120  # Increased timeout
        start_time = time.time()

        while time.time() - start_time < max_wait:
            status = self.rest_client.get_savepoint_status(job_id, request_id)
            self.logger.debug(f"Savepoint status: {status}")

            if not status:
                self.logger.warning("No status returned from savepoint status check")
                time.sleep(2)
                continue

            status_value = (
                status.get("status", {}).get("id")
                if isinstance(status.get("status"), dict)
                else status.get("status")
            )
            self.logger.debug(f"Status value: {status_value}")

            if status_value == "COMPLETED":
                savepoint_path = status.get("operation", {}).get("location")
                if savepoint_path:
                    # Update database with final savepoint path
                    self.database.update_savepoint_status(
                        savepoint_record_id,
                        "COMPLETED",
                        savepoint_path=savepoint_path,
                        metadata_update={
                            "completed_at": datetime.now().isoformat(),
                            "job_name": job_name,
                        },
                    )

                    # Cancel the job
                    if self.rest_client.cancel_job(job_id):
                        self.logger.info(
                            f"✅ Job {job_id} ({job_name}) paused successfully"
                        )
                        self.logger.info(f"📍 Savepoint location: {savepoint_path}")
                        return True
                    else:
                        self.logger.error(
                            f"❌ Created savepoint but failed to cancel job {job_id}"
                        )
                        return False
                break
            elif status_value == "FAILED":
                error_msg = status.get("operation", {}).get(
                    "failure-cause", "Unknown error"
                )
                self.database.update_savepoint_status(
                    savepoint_record_id,
                    "FAILED",
                    metadata_update={
                        "error": error_msg,
                        "failed_at": datetime.now().isoformat(),
                    },
                )
                self.logger.error(f"❌ Savepoint creation failed: {error_msg}")
                return False

            time.sleep(2)

        # Timeout - mark as failed
        self.database.update_savepoint_status(
            savepoint_record_id,
            "FAILED",
            metadata_update={
                "error": "Timeout waiting for savepoint completion",
                "timed_out_at": datetime.now().isoformat(),
            },
        )
        self.logger.error(f"❌ Savepoint creation timed out for job {job_id}")
        return False

    def resume_job(
        self, job_id_or_name: str, sql_file_path: str, env_vars: Dict[str, str] = None
    ) -> bool:
        """Resume a paused job from its latest savepoint using a provided SQL file"""
        self.logger.info(
            f"▶️ Resuming job {job_id_or_name} with SQL file {sql_file_path}..."
        )

        # Get savepoint from database (this is what we actually need)
        savepoint = None
        if len(job_id_or_name) == 32:  # Looks like a job ID
            savepoint = self.database.get_latest_savepoint(job_id_or_name)

        if not savepoint:
            # Try to find savepoint by job name
            all_savepoints = self.database.list_all_savepoints()
            for sp in all_savepoints:
                if sp.get("job_name") == job_id_or_name or job_id_or_name in sp.get(
                    "job_name", ""
                ):
                    savepoint = sp
                    break

        if not savepoint:
            self.logger.error(f"❌ No savepoint found for job: {job_id_or_name}")
            return False

        if (
            not savepoint.get("savepoint_path")
            or savepoint["savepoint_path"] == "RUNNING_JOB"
        ):
            self.logger.error(f"❌ Invalid savepoint path for job: {job_id_or_name}")
            return False

        savepoint_path = savepoint["savepoint_path"]
        original_job_id = savepoint["job_id"]
        job_name = savepoint.get("job_name", f"job_{original_job_id[:8]}")

        # Safety Check: Check if savepoint is already being used by running jobs
        self.logger.info("🔍 Checking if savepoint is already in use...")
        running_jobs = self.rest_client.check_jobs_using_savepoint(savepoint_path)
        if running_jobs:
            self.logger.error(
                f"❌ Savepoint is already being used by {len(running_jobs)} running job(s):"
            )
            for job in running_jobs:
                self.logger.error(
                    f"   - Job ID: {job['job_id']}, Name: {job['job_name']}, State: {job['state']}"
                )
            self.logger.error(
                "💡 Stop the conflicting jobs before resuming from this savepoint"
            )
            return False

        # Read SQL file
        try:
            with open(sql_file_path, "r", encoding="utf-8") as f:
                sql_content = f.read().strip()
        except Exception as e:
            self.logger.error(f"❌ Error reading SQL file {sql_file_path}: {e}")
            return False

        if not sql_content:
            self.logger.error(f"❌ SQL file {sql_file_path} is empty")
            return False

        # Validate environment variables in SQL content
        try:
            # Check if SQL contains variable placeholders
            var_pattern = r"\$\{([^}]+)\}"
            required_vars = re.findall(var_pattern, sql_content)

            if required_vars:
                self.logger.info(
                    f"📋 SQL file contains {len(set(required_vars))} environment variable(s): {', '.join(set(required_vars))}"
                )

                # Use provided environment variables or fall back to OS environment
                available_env_vars = (
                    env_vars if env_vars is not None else dict(os.environ)
                )

                # Check for missing variables
                missing_vars = [
                    var for var in set(required_vars) if var not in available_env_vars
                ]

                if missing_vars:
                    self.logger.error(
                        f"❌ SQL file contains {len(missing_vars)} required environment variable(s) "
                        f"that are not provided: {', '.join(missing_vars)}. "
                        f"Please provide these variables via environment file (.env) or environment variables."
                    )
                    return False

                # Substitute environment variables
                sql_content = substitute_env_variables(
                    sql_content, available_env_vars, strict=True
                )
                self.logger.info(
                    "✅ All required environment variables are available and substituted"
                )
            else:
                self.logger.info("📋 No environment variables found in SQL file")

        except ValueError as e:
            self.logger.error(f"❌ Environment variable validation failed: {e}")
            return False
        except Exception as e:
            self.logger.error(f"❌ Error validating environment variables: {e}")
            return False

        self.logger.info(f"📍 Using savepoint: {savepoint_path}")
        self.logger.info(f"📄 Using SQL file: {sql_file_path}")

        # Check if SQL contains streaming job pattern
        if "INSERT INTO" in sql_content.upper() and "SELECT" in sql_content.upper():
            # For streaming jobs, we need to add SET statement for savepoint
            resume_sql = f"""
SET 'execution.savepoint.path' = '{savepoint_path}';
{sql_content}
"""
        else:
            self.logger.warning(
                f"⚠️ SQL may not be a streaming job, resume might not work as expected"
            )
            resume_sql = f"""
SET 'execution.savepoint.path' = '{savepoint_path}';
{sql_content}
"""

        try:
            # Execute the resumed job with strict error handling
            success, results = self.executor.execute_multiple_statements(
                resume_sql, f"resume_job_{job_name}", continue_on_error=False
            )

            if success:
                self.logger.info(
                    f"✅ Job {job_id_or_name} resumed successfully from savepoint: {savepoint_path}"
                )
                return True
            else:
                self.logger.error(f"❌ Failed to execute resumed job SQL")
                return False

        except Exception as e:
            self.logger.error(f"❌ Error resuming job {job_id_or_name}: {e}")
            return False

    def resume_from_savepoint_id(
        self, savepoint_id: int, sql_file_path: str, env_vars: Dict[str, str] = None
    ) -> bool:
        """Resume from a specific savepoint ID using a provided SQL file with safety checks"""
        self.logger.info(
            f"▶️ Resuming from savepoint ID {savepoint_id} with SQL file {sql_file_path}..."
        )

        # Get savepoint by ID from database
        savepoint = None
        with self.database.get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM savepoints WHERE id = ?", (savepoint_id,)
            ).fetchone()
            if row:
                savepoint = dict(row)
                savepoint["metadata"] = json.loads(savepoint["metadata"] or "{}")

        if not savepoint:
            self.logger.error(f"❌ Savepoint with ID {savepoint_id} not found")
            return False

        if (
            not savepoint.get("savepoint_path")
            or savepoint["savepoint_path"] == "RUNNING_JOB"
        ):
            self.logger.error(f"❌ Invalid savepoint path for ID {savepoint_id}")
            return False

        savepoint_path = savepoint["savepoint_path"]
        original_job_id = savepoint["job_id"]
        job_name = savepoint.get("job_name", f"job_{original_job_id[:8]}")

        # Safety Check 1: Check if savepoint is already being used by running jobs
        self.logger.info("🔍 Checking if savepoint is already in use...")
        running_jobs = self.rest_client.check_jobs_using_savepoint(savepoint_path)
        if running_jobs:
            self.logger.error(
                f"❌ Savepoint is already being used by {len(running_jobs)} running job(s):"
            )
            for job in running_jobs:
                self.logger.error(
                    f"   - Job ID: {job['job_id']}, Name: {job['job_name']}, State: {job['state']}"
                )
            self.logger.error(
                "💡 Stop the conflicting jobs before resuming from this savepoint"
            )
            return False

        # Safety Check 2: Check database for recent resume events using this savepoint
        recent_resumes = self.database.check_savepoint_usage(savepoint_path)
        if recent_resumes:
            self.logger.warning(
                f"⚠️ Found {len(recent_resumes)} recent resume event(s) for this savepoint:"
            )
            for resume in recent_resumes:
                self.logger.warning(
                    f"   - Started: {resume['created_at']}, Status: {resume['resume_status']}"
                )

        # Create resume event record for tracking
        resume_event_id = self.database.create_resume_event(
            savepoint_id,
            original_job_id,
            savepoint_path,
            sql_file_path,
            {
                "job_name": job_name,
                "initiated_by": "sql-executor",
                "checks_passed": True,
            },
        )
        self.logger.info(f"📝 Created resume event record: {resume_event_id}")

        # Read SQL file
        try:
            with open(sql_file_path, "r", encoding="utf-8") as f:
                sql_content = f.read().strip()
        except Exception as e:
            error_msg = f"Error reading SQL file {sql_file_path}: {e}"
            self.logger.error(f"❌ {error_msg}")
            self.database.update_resume_event(
                resume_event_id, "FAILED", error_message=error_msg
            )
            return False

        if not sql_content:
            error_msg = f"SQL file {sql_file_path} is empty"
            self.logger.error(f"❌ {error_msg}")
            self.database.update_resume_event(
                resume_event_id, "FAILED", error_message=error_msg
            )
            return False

        # Validate environment variables in SQL content
        try:
            # Check if SQL contains variable placeholders
            var_pattern = r"\$\{([^}]+)\}"
            required_vars = re.findall(var_pattern, sql_content)

            if required_vars:
                self.logger.info(
                    f"📋 SQL file contains {len(set(required_vars))} environment variable(s): {', '.join(set(required_vars))}"
                )

                # Use provided environment variables or fall back to OS environment
                available_env_vars = (
                    env_vars if env_vars is not None else dict(os.environ)
                )

                # Check for missing variables
                missing_vars = [
                    var for var in set(required_vars) if var not in available_env_vars
                ]

                if missing_vars:
                    error_msg = (
                        f"SQL file contains {len(missing_vars)} required environment variable(s) "
                        f"that are not provided: {', '.join(missing_vars)}. "
                        f"Please provide these variables via environment file (.env) or environment variables."
                    )
                    self.logger.error(f"❌ {error_msg}")
                    self.database.update_resume_event(
                        resume_event_id, "FAILED", error_message=error_msg
                    )
                    return False

                # Substitute environment variables
                sql_content = substitute_env_variables(
                    sql_content, available_env_vars, strict=True
                )
                self.logger.info(
                    "✅ All required environment variables are available and substituted"
                )
            else:
                self.logger.info("📋 No environment variables found in SQL file")

        except ValueError as e:
            error_msg = f"Environment variable validation failed: {e}"
            self.logger.error(f"❌ {error_msg}")
            self.database.update_resume_event(
                resume_event_id, "FAILED", error_message=error_msg
            )
            return False
        except Exception as e:
            error_msg = f"Error validating environment variables: {e}"
            self.logger.error(f"❌ {error_msg}")
            self.database.update_resume_event(
                resume_event_id, "FAILED", error_message=error_msg
            )
            return False

        self.logger.info(f"📍 Using savepoint: {savepoint_path}")
        self.logger.info(f"📄 Using SQL file: {sql_file_path}")

        # Check if SQL contains streaming job pattern
        if "INSERT INTO" in sql_content.upper() and "SELECT" in sql_content.upper():
            # For streaming jobs, we need to add SET statement for savepoint
            resume_sql = f"""
SET 'execution.savepoint.path' = '{savepoint_path}';
{sql_content}
"""
        else:
            self.logger.warning(
                f"⚠️ SQL may not be a streaming job, resume might not work as expected"
            )
            resume_sql = f"""
SET 'execution.savepoint.path' = '{savepoint_path}';
{sql_content}
"""

        try:
            # Execute the resumed job with strict error handling
            success, results = self.executor.execute_multiple_statements(
                resume_sql,
                f"resume_savepoint_{savepoint_id}_{job_name}",
                continue_on_error=False,  # Stop on first error for resume operations
            )

            if success:
                # Try to extract new job ID from results if available
                new_job_id = None
                for result in results:
                    if result.get("result", {}).get("jobID"):
                        new_job_id = result["result"]["jobID"]
                        break

                # Update resume event as completed
                self.database.update_resume_event(
                    resume_event_id,
                    "COMPLETED",
                    new_job_id=new_job_id,
                    metadata_update={
                        "execution_results": len(results),
                        "new_job_started": new_job_id is not None,
                    },
                )

                self.logger.info(
                    f"✅ Job resumed successfully from savepoint ID {savepoint_id}"
                )
                self.logger.info(f"📍 Savepoint location: {savepoint_path}")
                if new_job_id:
                    self.logger.info(f"🆔 New job ID: {new_job_id}")
                return True
            else:
                error_msg = "Failed to execute resumed job SQL"
                self.logger.error(f"❌ {error_msg}")
                self.database.update_resume_event(
                    resume_event_id,
                    "FAILED",
                    error_message=error_msg,
                    metadata_update={"execution_results": len(results)},
                )
                return False

        except Exception as e:
            error_msg = f"Error resuming job from savepoint ID {savepoint_id}: {e}"
            self.logger.error(f"❌ {error_msg}")
            self.database.update_resume_event(
                resume_event_id, "FAILED", error_message=error_msg
            )
            return False

    def get_savepoint_details(self, job_id: str = None) -> List[Dict]:
        """Get detailed savepoint information with optional Flink cluster status for active savepoints only"""
        savepoints = self.database.get_savepoint_details(job_id)

        # Only enrich with current Flink job status for savepoints that might be active/running
        for savepoint in savepoints:
            # Only check Flink status for savepoints that are potentially still active
            # Skip completed, failed, or canceled savepoints to avoid unnecessary API calls
            savepoint_status = savepoint.get("savepoint_status", "")
            if savepoint_status in ["IN_PROGRESS", "RUNNING", "PENDING", ""]:
                sp_job_id = savepoint["job_id"]
                try:
                    job_details = self.rest_client.get_job_details(sp_job_id)
                    if job_details:
                        savepoint["current_job_status"] = job_details.get(
                            "state", "NOT_FOUND"
                        )
                        savepoint["current_start_time"] = job_details.get("start-time")
                    else:
                        savepoint["current_job_status"] = "NOT_FOUND"
                except Exception as e:
                    # If we can't connect to Flink or get job details, just skip enrichment
                    self.logger.warning(
                        f"Could not fetch current job status for {sp_job_id}: {e}"
                    )
                    savepoint["current_job_status"] = "UNAVAILABLE"
            else:
                # For completed savepoints, don't hit Flink API
                savepoint["current_job_status"] = "N/A (completed)"

        return savepoints

    def get_active_savepoints(self) -> List[Dict]:
        """Get all active (IN_PROGRESS) savepoints with current status"""
        active_savepoints = self.database.get_active_savepoints()

        # Check actual status in Flink for active savepoints
        for savepoint in active_savepoints:
            job_id = savepoint["job_id"]
            request_id = savepoint.get("request_id")

            if request_id:
                # Check current savepoint status in Flink
                status = self.rest_client.get_savepoint_status(job_id, request_id)
                if status:
                    flink_status = (
                        status.get("status", {}).get("id")
                        if isinstance(status.get("status"), dict)
                        else status.get("status")
                    )
                    savepoint["flink_status"] = flink_status

                    if flink_status == "COMPLETED":
                        savepoint_path = status.get("operation", {}).get("location")
                        savepoint["actual_savepoint_path"] = savepoint_path
                    elif flink_status == "FAILED":
                        savepoint["error"] = status.get("operation", {}).get(
                            "failure-cause", "Unknown error"
                        )
                else:
                    savepoint["flink_status"] = "UNKNOWN"

        return active_savepoints

    def _get_job_info_from_flink(self, job_id: str) -> Optional[Dict]:
        """Get job information from Flink REST API"""
        try:
            return self.rest_client.get_job_details(job_id)
        except Exception as e:
            self.logger.warning(f"Could not fetch job info for {job_id}: {e}")
            return None


def check_sql_gateway_connectivity(url: str) -> bool:
    """Check if Flink SQL Gateway is accessible"""
    try:
        print(f"ℹ️  Checking Flink SQL Gateway connectivity at {url}...")
        response = requests.get(f"{url}/v1/info", timeout=5)
        if response.status_code == 200:
            print(f"✅ Flink SQL Gateway is accessible")
            return True
        else:
            print(f"⚠️  Flink SQL Gateway returned status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"⚠️  Flink SQL Gateway is not accessible at {url}")
        print(
            f"⚠️  Make sure the Flink cluster is running and the SQL Gateway is enabled"
        )
        print(f"    Error: {e}")
        return False


class FlinkSQLExecutor:
    """
    Manages execution of SQL statements against Flink SQL Gateway
    """

    def __init__(
        self,
        sql_gateway_url: str,
        session_timeout: int = 300,
        enable_job_tracking: bool = True,
        db_path: str = "flink_jobs.db",
        flink_rest_url: str = None,
    ):
        self.sql_gateway_url = sql_gateway_url.rstrip("/")
        self.session_timeout = session_timeout
        self.session_handle: Optional[str] = None
        self.logger = logging.getLogger(__name__)

        # Job management components
        self.enable_job_tracking = enable_job_tracking
        self.database = FlinkJobDatabase(db_path) if enable_job_tracking else None
        self.rest_client = FlinkRestClient(flink_rest_url) if flink_rest_url else None
        self.job_manager = (
            FlinkJobManager(self, self.database, self.rest_client)
            if enable_job_tracking
            else None
        )

    def create_session(self) -> bool:
        """Create a new SQL Gateway session"""
        try:
            url = f"{self.sql_gateway_url}/v1/sessions"
            payload = {"properties": {"execution.runtime-mode": "streaming"}}

            self.logger.info(f"Creating SQL Gateway session at {url}")
            response = requests.post(url, json=payload, timeout=30)

            if response.status_code == 200:
                result = response.json()
                self.session_handle = result.get("sessionHandle")
                self.logger.info(
                    f"✓ SQL Gateway session created: {self.session_handle}"
                )
                self.logger.debug(
                    f"Session will be reused for all SQL statements in this execution"
                )
                return True
            else:
                self.logger.error(
                    f"✗ Failed to create session: {response.status_code} - {response.text}"
                )
                return False

        except requests.RequestException as e:
            self.logger.error(f"✗ Connection error creating session: {e}")
            return False

    def close_session(self) -> bool:
        """Close the current SQL Gateway session"""
        if not self.session_handle:
            return True

        try:
            url = f"{self.sql_gateway_url}/v1/sessions/{self.session_handle}"
            response = requests.delete(url, timeout=30)

            if response.status_code in [200, 404]:
                self.logger.info(f"✓ SQL Gateway session closed: {self.session_handle}")
                self.session_handle = None
                return True
            else:
                self.logger.warning(f"⚠ Session close returned: {response.status_code}")
                return False

        except requests.RequestException as e:
            self.logger.error(f"✗ Error closing session: {e}")
            return False

    def parse_sql_statements(self, sql_content: str) -> List[str]:
        """
        Parse multiple SQL statements from a string, handling comments and semicolons properly

        Args:
            sql_content: Raw SQL content that may contain multiple statements

        Returns:
            List of individual SQL statements
        """
        if not sql_content.strip():
            return []

        # Remove SQL comments (both -- and /* */ style)
        # Handle -- comments
        lines = sql_content.split("\n")
        cleaned_lines = []

        for line in lines:
            # Find -- comments, but ignore them inside string literals
            in_string = False
            quote_char = None
            comment_pos = -1

            for i, char in enumerate(line):
                if not in_string:
                    if char in ('"', "'"):
                        in_string = True
                        quote_char = char
                    elif char == "-" and i < len(line) - 1 and line[i + 1] == "-":
                        comment_pos = i
                        break
                else:
                    if char == quote_char and (i == 0 or line[i - 1] != "\\"):
                        in_string = False
                        quote_char = None

            if comment_pos >= 0:
                line = line[:comment_pos]

            cleaned_lines.append(line)

        sql_content = "\n".join(cleaned_lines)

        # Remove /* */ comments
        sql_content = re.sub(r"/\*.*?\*/", "", sql_content, flags=re.DOTALL)

        # Split by semicolons, but be careful about semicolons in string literals
        statements = []
        current_statement = ""
        in_string = False
        quote_char = None

        for char in sql_content:
            if not in_string:
                if char in ('"', "'"):
                    in_string = True
                    quote_char = char
                    current_statement += char
                elif char == ";":
                    # End of statement
                    if current_statement.strip():
                        statements.append(current_statement.strip())
                    current_statement = ""
                else:
                    current_statement += char
            else:
                current_statement += char
                if char == quote_char:
                    # Check if it's escaped
                    if len(current_statement) < 2 or current_statement[-2] != "\\":
                        in_string = False
                        quote_char = None

        # Add the last statement if it doesn't end with semicolon
        if current_statement.strip():
            statements.append(current_statement.strip())

        # Filter out empty statements
        statements = [stmt for stmt in statements if stmt and not stmt.isspace()]

        return statements

    def execute_multiple_statements(
        self,
        sql_content: str,
        source_name: str = "",
        continue_on_error: bool = False,
        format_style: str = "table",
    ) -> Tuple[bool, List[Dict]]:
        """
        Execute multiple SQL statements from a string

        Args:
            sql_content: Raw SQL content containing multiple statements
            source_name: Name/description of the source (file name, etc.)
            continue_on_error: Whether to continue executing remaining statements after an error

        Returns:
            Tuple[bool, List[Dict]]: (overall_success, list_of_results)
        """
        statements = self.parse_sql_statements(sql_content)

        if not statements:
            self.logger.warning(f"No SQL statements found in {source_name or 'input'}")
            return True, []

        self.logger.info(
            f"Found {len(statements)} SQL statement(s) in {source_name or 'input'}"
        )
        self.logger.info(f"Using session {self.session_handle} for all statements")

        results = []
        overall_success = True
        has_streaming_queries = False

        for i, statement in enumerate(statements, 1):
            self.logger.info(
                f"Executing statement {i}/{len(statements)} using session {self.session_handle}"
            )
            self.logger.debug(
                f"Statement {i}: {statement[:100]}{'...' if len(statement) > 100 else ''}"
            )

            statement_name = (
                f"{source_name}_stmt_{i}" if source_name else f"statement_{i}"
            )
            success, result = self.execute_statement(
                statement, statement_name, format_style
            )

            # Track if we have streaming queries
            if success and result.get("is_streaming", False):
                has_streaming_queries = True

            result["statement_number"] = i
            result["statement"] = statement
            result["success"] = success
            results.append(result)

            if not success:
                overall_success = False
                self.logger.error(f"Statement {i} failed")

                if not continue_on_error:
                    self.logger.info(
                        f"Stopping execution due to error (continue_on_error=False)"
                    )
                    break
                else:
                    self.logger.info(
                        f"Continuing with remaining statements (continue_on_error=True)"
                    )

        # Add delay before session closure if we had streaming queries
        if has_streaming_queries:
            self.logger.info(
                "Waiting additional 3 seconds before closing session for streaming query cleanup..."
            )
            time.sleep(3)

        if overall_success:
            self.logger.info(
                f"✅ All {len(statements)} statements executed successfully"
            )
        else:
            failed_count = sum(1 for r in results if not r.get("success", False))
            success_count = len(results) - failed_count
            self.logger.warning(
                f"⚠️ {success_count}/{len(statements)} statements succeeded, {failed_count} failed"
            )

        return overall_success, results

    def execute_statement(
        self, sql_statement: str, statement_name: str = "", format_style: str = "table"
    ) -> Tuple[bool, Dict]:
        """
        Execute a SQL statement and return success status with details

        Returns:
            Tuple[bool, Dict]: (success, result_info)
        """
        if not self.session_handle:
            return False, {"error": "No active session"}

        try:
            # Submit statement
            url = f"{self.sql_gateway_url}/v1/sessions/{self.session_handle}/statements"
            payload = {"statement": sql_statement}

            self.logger.info(f"Executing: {statement_name or 'SQL Statement'}")
            self.logger.debug(f"SQL: {sql_statement}")

            response = requests.post(url, json=payload, timeout=30)

            if response.status_code != 200:
                error_msg = f"Failed to submit statement: {response.status_code} - {response.text}"
                self.logger.error(f"✗ {error_msg}")
                return False, {"error": error_msg}

            result = response.json()
            operation_handle = result.get("operationHandle")

            if not operation_handle:
                error_msg = f"No operation handle received: {result}"
                self.logger.error(f"✗ {error_msg}")
                return False, {"error": error_msg}

            # Poll for completion
            return self._poll_operation_status(
                operation_handle, statement_name, format_style
            )

        except requests.RequestException as e:
            error_msg = f"Connection error executing statement: {e}"
            self.logger.error(f"✗ {error_msg}")
            return False, {"error": error_msg}

    def _poll_operation_status(
        self,
        operation_handle: str,
        statement_name: str,
        format_style: str = "table",
        max_wait: int = 60,
    ) -> Tuple[bool, Dict]:
        """Poll operation status until completion"""
        url = f"{self.sql_gateway_url}/v1/sessions/{self.session_handle}/operations/{operation_handle}/status"

        start_time = time.time()
        poll_count = 0

        while time.time() - start_time < max_wait:
            try:
                response = requests.get(url, timeout=10)

                if response.status_code != 200:
                    error_msg = (
                        f"Failed to get operation status: {response.status_code}"
                    )
                    return False, {"error": error_msg}

                status_result = response.json()
                status = status_result.get("status", "UNKNOWN")

                poll_count += 1
                self.logger.debug(f"Poll #{poll_count}: Status = {status}")

                if status == "FINISHED":
                    duration = time.time() - start_time

                    # Fetch results for queries that return data
                    result_data = self._fetch_operation_result(operation_handle)

                    # Check if this is a streaming query that needs more time to collect results
                    is_streaming_query = (
                        result_data and result_data.get("jobID") is not None
                    )

                    if is_streaming_query:
                        self.logger.info(
                            f"✓ {statement_name or 'Statement'} streaming job submitted successfully ({duration:.1f}s)"
                        )
                        # For streaming queries, we already have the initial results, don't re-fetch
                    else:
                        self.logger.info(
                            f"✓ {statement_name or 'Statement'} completed successfully ({duration:.1f}s)"
                        )

                    # Print results - always show row count summary, even for 0 rows
                    if result_data and result_data.get("results"):
                        self._print_query_results(
                            result_data, statement_name, format_style
                        )

                    return True, {
                        "status": status,
                        "duration": duration,
                        "polls": poll_count,
                        "result": result_data,
                        "is_streaming": is_streaming_query,
                    }
                elif status == "ERROR":
                    error_info = status_result.get("errorMessage", {})
                    self.logger.debug(
                        f"Full error response: {json.dumps(status_result, indent=2)}"
                    )

                    detailed_error = None
                    # Try to fetch the operation result for more detailed error info
                    try:
                        result_url = f"{self.sql_gateway_url}/v1/sessions/{self.session_handle}/operations/{operation_handle}/result/0"
                        result_response = requests.get(result_url, timeout=10)
                        if result_response.status_code == 200:
                            result_data = result_response.json()
                            self.logger.debug(
                                f"Error result data: {json.dumps(result_data, indent=2)}"
                            )
                        elif result_response.status_code >= 400:
                            # The error details are likely in the response text
                            error_text = result_response.text
                            self.logger.debug(
                                f"Detailed error from result endpoint: {error_text}"
                            )
                            detailed_error = error_text

                            # Try to parse the JSON to get the actual error
                            try:
                                error_json = json.loads(error_text)
                                if (
                                    "errors" in error_json
                                    and len(error_json["errors"]) > 1
                                ):
                                    # The second element often contains the detailed error
                                    detailed_error = error_json["errors"][1]
                            except:
                                pass  # Use raw error_text if JSON parsing fails

                    except Exception as e:
                        self.logger.debug(f"Could not fetch error result: {e}")

                    # Use detailed error if available, otherwise fall back to basic error message
                    if detailed_error:
                        error_msg = detailed_error
                    else:
                        error_msg = error_info.get(
                            "errorMessage",
                            status_result.get("errorMessage", "SQL execution failed"),
                        )

                    # Always show formatted error message (not just in debug mode)
                    formatted_error = format_sql_error(error_msg, debug_mode=False)
                    self.logger.error(f"✗ {statement_name or 'Statement'} failed")
                    print(formatted_error)  # Print the pretty error message to console

                    return False, {
                        "status": status,
                        "error": error_msg,
                        "full_error": error_info,
                    }
                elif status in ["RUNNING", "PENDING"]:
                    time.sleep(2)  # Wait before next poll
                    continue
                else:
                    self.logger.warning(f"⚠ Unexpected status: {status}")
                    time.sleep(2)
                    continue

            except requests.RequestException as e:
                self.logger.error(f"✗ Error polling status: {e}")
                return False, {"error": f"Polling error: {e}"}

        # Timeout
        duration = time.time() - start_time
        error_msg = f"Operation timed out after {duration:.1f}s"
        self.logger.error(f"✗ {statement_name or 'Statement'} {error_msg}")
        return False, {"error": error_msg, "timeout": True}

    def _fetch_operation_result(
        self, operation_handle: str, max_fetch_attempts: int = 20
    ) -> Optional[Dict]:
        """Fetch the result data from a completed operation using proper pagination protocol"""
        all_results = {
            "results": {"columns": [], "data": []},
            "resultType": None,
            "isQueryResult": False,
            "resultKind": None,
            "jobID": None,
        }

        # Start with token 0 as per Flink documentation
        # Use JSON row format for proper data parsing
        next_result_uri = f"/v1/sessions/{self.session_handle}/operations/{operation_handle}/result/0?rowFormat=JSON"
        fetch_attempts = 0

        try:
            while next_result_uri and fetch_attempts < max_fetch_attempts:
                fetch_attempts += 1
                url = f"{self.sql_gateway_url}{next_result_uri}"

                self.logger.debug(
                    f"🔄 Fetching results (attempt {fetch_attempts}): {url}"
                )
                response = requests.get(url, timeout=10)

                if response.status_code != 200:
                    self.logger.debug(
                        f"No result data available: {response.status_code} - {response.text}"
                    )
                    if fetch_attempts == 1:
                        return None  # No results at all
                    else:
                        break  # Stop fetching but return what we have

                result_data = response.json()
                self.logger.debug(
                    f"Raw API response: {json.dumps(result_data, indent=2)}"
                )

                # Initialize all_results with metadata from first response
                if fetch_attempts == 1:
                    all_results["resultType"] = result_data.get("resultType")
                    all_results["isQueryResult"] = result_data.get(
                        "isQueryResult", False
                    )
                    all_results["resultKind"] = result_data.get("resultKind")
                    all_results["jobID"] = result_data.get("jobID")

                    # Set columns from first response - API uses 'columns'
                    results = result_data.get("results", {})
                    if results.get("columns"):
                        all_results["results"]["columns"] = results["columns"]

                # Check resultType first - if EOS, we're done
                current_result_type = result_data.get("resultType")
                self.logger.debug(f"📋 Result type: {current_result_type}")

                if current_result_type == "EOS":
                    self.logger.debug(
                        f"🏁 Reached End of Stream (EOS) - stopping fetch"
                    )
                    break

                # Accumulate data from each response
                results = result_data.get("results", {})
                data_in_batch = results.get("data", [])
                if data_in_batch:
                    all_results["results"]["data"].extend(data_in_batch)

                # Check for nextResultUri to continue pagination
                next_result_uri = result_data.get("nextResultUri")

                self.logger.debug(
                    f"📦 Fetched {len(data_in_batch)} rows, nextResultUri: {'Present' if next_result_uri else 'None'}"
                )
                if data_in_batch and len(data_in_batch) > 0:
                    self.logger.debug(f"📊 Sample data: {data_in_batch[0]}")
                self.logger.debug(
                    f"📊 Total accumulated rows: {len(all_results['results']['data'])}"
                )

                # If we are done (no nextResultUri), stop
                if not next_result_uri:
                    self.logger.debug(f"🏁 No more nextResultUri - stopping fetch")
                    break

                # For NOT_READY results, wait before polling again
                if current_result_type == "NOT_READY":
                    self.logger.debug(
                        "⏳ Results not ready, waiting before next poll..."
                    )
                    time.sleep(1)
                    continue

                # If we received no data in this batch but have nextResultUri, wait briefly
                if not data_in_batch and next_result_uri:
                    # If we keep getting nextResultUri but no data for too many attempts, stop
                    if len(all_results["results"]["data"]) == 0 and fetch_attempts >= 5:
                        self.logger.debug(
                            f"🛑 Stopping after {fetch_attempts} attempts with no data - likely empty result set"
                        )
                        break

                    self.logger.debug(
                        "No data in this batch but nextResultUri present, waiting..."
                    )
                    time.sleep(1)

            total_rows = len(all_results["results"]["data"])
            self.logger.debug(
                f"✅ Total rows fetched: {total_rows} in {fetch_attempts} attempts"
            )

            # Return results even if empty (let the caller decide how to handle)
            return all_results

        except requests.RequestException as e:
            self.logger.debug(f"Error fetching result: {e}")
            return None

    def _print_query_results(
        self, result_data: Dict, statement_name: str = "", format_style: str = "table"
    ):
        """Print formatted query results using tabulate for better presentation"""
        try:
            # Check if there are results to display
            results = result_data.get("results", {})
            if not results:
                if format_style == "json":
                    print(json.dumps([], indent=2))
                else:
                    print(f"\n📊 Results for {statement_name}:")
                    print("=" * 60)
                    print("❌ No results structure returned")
                    print("=" * 60)
                return

            # Get column information and data
            columns = results.get(
                "columns", results.get("columns", [])
            )  # Support both API field names
            data_rows = results.get("data", [])

            # Enhanced debugging info (only show if debug logging enabled)
            result_type = result_data.get("resultType", "UNKNOWN")
            is_query_result = result_data.get(
                "isQueryResult", result_data.get("isQueryResult", False)
            )  # Support both field names
            job_id = result_data.get("jobID", "N/A")

            # Count actual data rows (excluding metadata)
            actual_data_rows = (
                [row for row in data_rows if row.get("kind") == "INSERT"]
                if data_rows
                else []
            )  # API uses 'kind' not 'kind'
            data_rows_count = len(actual_data_rows)

            if self.logger.isEnabledFor(logging.DEBUG):
                print(f"\n� Results for {statement_name}:")
                print("=" * 60)
                print(
                    f"📈 Debug Info: Total rows: {len(data_rows)}, Data rows: {data_rows_count}, Columns: {len(columns)}"
                )
                print(f"📈 Result Type: {result_type}, Job ID: {job_id}")
                print()

            if not data_rows:
                if format_style == "json":
                    print(json.dumps([], indent=2))
                else:
                    print(f"\n📊 Results for {statement_name}:")
                    print("=" * 60)
                    print(
                        "❌ No data returned - the query executed successfully but returned 0 rows."
                    )
                    if is_query_result and job_id != "N/A":
                        print(
                            f"💡 Streaming job ID: {job_id} (may still be collecting data)"
                        )
                    print("=" * 60)
                return

            if not actual_data_rows:
                if format_style == "json":
                    print(json.dumps([], indent=2))
                else:
                    print(f"\n📊 Results for {statement_name}:")
                    print("=" * 60)
                    print("❌ No INSERT data rows found.")
                    print("=" * 60)
                return

            if columns and actual_data_rows:
                print(f"\n📊 Results for {statement_name}:")
                print("=" * 60)

                # Prepare headers
                headers = [col.get("name", f"col_{i}") for i, col in enumerate(columns)]

                # Prepare data for tabulate
                table_data = []
                for row_data in actual_data_rows:
                    # The actual row data might be in different fields depending on the RowFormat
                    if isinstance(row_data, dict):
                        # For structured data, extract the actual field values
                        if "fields" in row_data:
                            fields = row_data["fields"]
                        else:
                            # Direct field access for some formats
                            fields = [
                                row_data.get(col.get("name", f"col_{i}"), None)
                                for i, col in enumerate(columns)
                            ]
                    else:
                        # For array-like data
                        fields = row_data if isinstance(row_data, list) else [row_data]

                    # Convert None values to 'NULL' for better display
                    formatted_row = [
                        str(cell) if cell is not None else "NULL" for cell in fields
                    ]
                    table_data.append(formatted_row)

                # Handle JSON format
                if format_style == "json":
                    # Convert data to JSON format
                    json_data = []
                    for row_data in actual_data_rows:
                        if isinstance(row_data, dict):
                            if "fields" in row_data:
                                fields = row_data["fields"]
                            else:
                                fields = [
                                    row_data.get(col.get("name", f"col_{i}"), None)
                                    for i, col in enumerate(columns)
                                ]
                        else:
                            fields = (
                                row_data if isinstance(row_data, list) else [row_data]
                            )

                        # Create a dictionary for this row
                        row_dict = {}
                        for i, header in enumerate(headers):
                            value = fields[i] if i < len(fields) else None
                            row_dict[header] = value
                        json_data.append(row_dict)

                    # Pretty print the JSON
                    print(json.dumps(json_data, indent=2, ensure_ascii=False))
                    print()
                    print(f"✅ Displayed {data_rows_count} row(s) in JSON format")
                    print("=" * 60)
                    return

                # Print the table using tabulate for other formats
                if format_style == "table":
                    table_format = "grid"
                elif format_style == "simple":
                    table_format = "simple"
                elif format_style == "plain":
                    table_format = "plain"
                else:
                    table_format = "grid"

                try:
                    formatted_table = tabulate(
                        table_data,
                        headers=headers,
                        tablefmt=table_format,
                        numalign="left",
                        stralign="left",
                    )
                    print(formatted_table)
                except Exception as e:
                    # Fallback to simple format if tabulate fails
                    self.logger.debug(
                        f"Tabulate formatting failed: {e}, using simple format"
                    )
                    self._print_simple_table(headers, table_data)

                print()
                print(f"✅ Displayed {data_rows_count} row(s)")
                print("=" * 60)
            else:
                # Fallback: print raw data
                if format_style == "json":
                    # Convert raw data to JSON as best as possible
                    print(json.dumps(data_rows, indent=2, ensure_ascii=False))
                else:
                    print(f"\n📊 Raw results for {statement_name}:")
                    print("=" * 60)
                    for i, row in enumerate(data_rows[:5]):  # Show first 5 rows
                        print(f"  Row {i+1}: {row}")
                    if len(data_rows) > 5:
                        print(f"  ... and {len(data_rows) - 5} more rows")
                    print("=" * 60)

        except Exception as e:
            self.logger.debug(f"Error printing results: {e}")
            # Print raw results as fallback
            if format_style == "json":
                try:
                    print(json.dumps(result_data, indent=2, ensure_ascii=False))
                except:
                    print(
                        json.dumps(
                            {
                                "error": "Failed to format results as JSON",
                                "raw_data": str(result_data),
                            },
                            indent=2,
                        )
                    )
            else:
                print(f"\n📊 Raw results for {statement_name}:")
                print("=" * 60)
                print(json.dumps(result_data, indent=2))
                print("=" * 60)

    def _print_simple_table(self, headers: List[str], data: List[List[str]]):
        """Simple table printing fallback when tabulate is not available"""
        if not headers or not data:
            return

        # Calculate column widths
        col_widths = [len(header) for header in headers]
        for row in data:
            for i, cell in enumerate(row):
                if i < len(col_widths):
                    col_widths[i] = max(col_widths[i], len(str(cell)))

        # Print header
        header_row = " | ".join(
            header.ljust(width) for header, width in zip(headers, col_widths)
        )
        print(header_row)
        print("-" * len(header_row))

        # Print data rows
        for row in data:
            formatted_cells = []
            for i, cell in enumerate(row):
                width = col_widths[i] if i < len(col_widths) else 20
                formatted_cells.append(str(cell).ljust(width))
            print(" | ".join(formatted_cells))

    def pause_job(self, job_id_or_name: str, savepoint_dir: str = None) -> bool:
        """Pause a job by ID or name"""
        if not self.job_manager:
            self.logger.error("Job management not enabled")
            return False
        return self.job_manager.pause_job(job_id_or_name, savepoint_dir)

    def resume_job(
        self, job_id_or_name: str, sql_file_path: str, env_vars: Dict[str, str] = None
    ) -> bool:
        """Resume a paused job by ID or name using a provided SQL file"""
        if not self.job_manager:
            self.logger.error("Job management not enabled")
            return False
        return self.job_manager.resume_job(job_id_or_name, sql_file_path, env_vars)

    def resume_from_savepoint_id(
        self, savepoint_id: int, sql_file_path: str, env_vars: Dict[str, str] = None
    ) -> bool:
        """Resume from a specific savepoint ID using a provided SQL file"""
        if not self.job_manager:
            self.logger.error("Job management not enabled")
            return False
        return self.job_manager.resume_from_savepoint_id(
            savepoint_id, sql_file_path, env_vars
        )

    def get_active_savepoints(self) -> List[Dict]:
        """Get all active savepoint operations"""
        if not self.job_manager:
            return []
        return self.job_manager.get_active_savepoints()

    def get_savepoint_details(self, job_id: str = None) -> List[Dict]:
        """Get detailed savepoint information"""
        if not self.job_manager:
            return []
        return self.job_manager.get_savepoint_details(job_id)

    def print_jobs_table(self, jobs: List[Dict], format_style: str = "table"):
        """Print jobs in a formatted table"""
        if not jobs:
            print("📋 No jobs found")
            return

        if format_style == "json":
            print(json.dumps(jobs, indent=2, default=str))
            return

        # Prepare data for table
        headers = [
            "Job ID (Short)",
            "Job Name",
            "Status",
            "Created",
            "Duration",
            "Tags",
        ]
        data = []

        for job in jobs:
            job_id_short = (
                job["job_id"][:12] + "..." if len(job["job_id"]) > 15 else job["job_id"]
            )

            # Calculate duration
            created_at = job.get("created_at", "")
            duration = "N/A"
            if created_at:
                try:
                    created_time = datetime.fromisoformat(
                        created_at.replace("Z", "+00:00")
                    )
                    if job.get("finished_at"):
                        finished_time = datetime.fromisoformat(
                            job["finished_at"].replace("Z", "+00:00")
                        )
                        duration_delta = finished_time - created_time
                    else:
                        duration_delta = datetime.now() - created_time

                    # Format duration
                    total_seconds = int(duration_delta.total_seconds())
                    hours, remainder = divmod(total_seconds, 3600)
                    minutes, seconds = divmod(remainder, 60)

                    if hours > 0:
                        duration = f"{hours}h {minutes}m"
                    elif minutes > 0:
                        duration = f"{minutes}m {seconds}s"
                    else:
                        duration = f"{seconds}s"
                except:
                    duration = "N/A"

            # Format creation time
            created_display = "N/A"
            if created_at:
                try:
                    created_time = datetime.fromisoformat(
                        created_at.replace("Z", "+00:00")
                    )
                    now = datetime.now()
                    time_diff = now - created_time

                    if time_diff.days > 0:
                        created_display = f"{time_diff.days}d ago"
                    elif time_diff.seconds > 3600:
                        hours = time_diff.seconds // 3600
                        created_display = f"{hours}h ago"
                    elif time_diff.seconds > 60:
                        minutes = time_diff.seconds // 60
                        created_display = f"{minutes}m ago"
                    else:
                        created_display = "just now"
                except:
                    created_display = (
                        created_at[:16] if len(created_at) > 16 else created_at
                    )

            tags_display = ", ".join(job.get("tags", [])[:3])  # Show first 3 tags
            if len(job.get("tags", [])) > 3:
                tags_display += "..."

            data.append(
                [
                    job_id_short,
                    (
                        job["job_name"][:25] + "..."
                        if len(job["job_name"]) > 28
                        else job["job_name"]
                    ),
                    job["status"],
                    created_display,
                    duration,
                    tags_display,
                ]
            )

        # Print table
        try:
            print("\n📋 Flink Jobs Overview")
            print("=" * 80)
            print(tabulate(data, headers=headers, tablefmt="grid"))

            # Summary
            status_counts = {}
            for job in jobs:
                status = job["status"]
                status_counts[status] = status_counts.get(status, 0) + 1

            summary_parts = [
                f"{count} {status.lower()}" for status, count in status_counts.items()
            ]
            print(f"\n💾 Total: {len(jobs)} jobs ({', '.join(summary_parts)})")

        except Exception as e:
            # Fallback to simple table
            self.logger.debug(f"Tabulate failed, using simple table: {e}")
            self._print_simple_table(headers, data)

    def print_savepoints_table(
        self, savepoints: List[Dict], format_style: str = "table"
    ):
        """Print savepoints in a formatted table"""
        if not savepoints:
            print("📋 No savepoints found")
            return

        if format_style == "json":
            print(json.dumps(savepoints, indent=2, default=str))
            return

        # Determine if these are active savepoints or all savepoints based on available fields
        is_active_savepoints = any(
            sp.get("flink_status") is not None for sp in savepoints
        )

        if is_active_savepoints:
            # Active savepoints table format
            headers = [
                "ID",
                "Job ID (Short)",
                "Job Name",
                "Savepoint Status",
                "Request ID",
                "Created",
                "Age",
                "Flink Status",
            ]
            title = "💾 Active Savepoint Operations"
        else:
            # All savepoints table format
            headers = [
                "ID",
                "Job ID (Short)",
                "Job Name",
                "Savepoint Status",
                "Age",
                "Savepoint Path",
            ]
            title = "💾 All Savepoints"

        data = []

        for sp in savepoints:
            job_id_short = (
                sp["job_id"][:12] + "..." if len(sp["job_id"]) > 15 else sp["job_id"]
            )
            job_name = sp.get("job_name", "unknown")[:20]
            if len(sp.get("job_name", "")) > 23:
                job_name += "..."

            # Use existing age_formatted if available, otherwise calculate
            age_display = sp.get("age_formatted", "N/A")
            if age_display == "N/A":
                created_at = sp.get("created_at", "")
                if created_at:
                    try:
                        created_time = datetime.fromisoformat(
                            created_at.replace("Z", "+00:00")
                        )
                        now = datetime.now()
                        time_diff = now - created_time

                        if time_diff.days > 0:
                            age_display = (
                                f"{time_diff.days}d {time_diff.seconds//3600}h"
                            )
                        elif time_diff.seconds > 3600:
                            hours = time_diff.seconds // 3600
                            minutes = (time_diff.seconds % 3600) // 60
                            age_display = f"{hours}h {minutes}m"
                        elif time_diff.seconds > 60:
                            minutes = time_diff.seconds // 60
                            seconds = time_diff.seconds % 60
                            age_display = f"{minutes}m {seconds}s"
                        else:
                            age_display = f"{time_diff.seconds}s"
                    except:
                        age_display = "N/A"

            if is_active_savepoints:
                # Active savepoints row
                created_display = "N/A"
                created_at = sp.get("created_at", "")
                if created_at:
                    try:
                        created_time = datetime.fromisoformat(
                            created_at.replace("Z", "+00:00")
                        )
                        created_display = created_time.strftime("%m/%d %H:%M")
                    except:
                        created_display = (
                            created_at[:16] if len(created_at) > 16 else created_at
                        )

                request_id_display = sp.get("request_id", "N/A")
                if len(request_id_display) > 8:
                    request_id_display = request_id_display[:8] + "..."

                data.append(
                    [
                        sp.get("id", "N/A"),
                        job_id_short,
                        job_name,
                        sp.get("savepoint_status", "UNKNOWN"),
                        request_id_display,
                        created_display,
                        age_display,
                        sp.get("flink_status", "N/A"),
                    ]
                )
            else:
                # All savepoints row
                savepoint_path = sp.get("savepoint_path", "unknown")
                if len(savepoint_path) > 50:
                    savepoint_path = "..." + savepoint_path[-47:]

                data.append(
                    [
                        sp.get("id", "N/A"),
                        job_id_short,
                        job_name,
                        sp.get("savepoint_status", "UNKNOWN"),
                        age_display,
                        savepoint_path,
                    ]
                )

        # Print table
        try:
            print(f"\n{title}")
            print("=" * 100)
            print(tabulate(data, headers=headers, tablefmt="grid"))

            # Summary
            status_counts = {}
            for sp in savepoints:
                status = sp.get("savepoint_status", "UNKNOWN")
                status_counts[status] = status_counts.get(status, 0) + 1

            summary_parts = [
                f"{count} {status.lower()}" for status, count in status_counts.items()
            ]
            print(
                f"\n📊 Total: {len(savepoints)} savepoints ({', '.join(summary_parts)})"
            )

        except Exception as e:
            # Fallback to simple table
            self.logger.debug(f"Tabulate failed, using simple table: {e}")
            print(f"\n{title}:")
            for i, sp in enumerate(savepoints, 1):
                print(
                    f"{i}. Job: {sp.get('job_name', 'unknown')} ({sp['job_id'][:12]}...)"
                )
                print(f"   Status: {sp.get('savepoint_status', 'UNKNOWN')}")
                print(f"   Age: {age_display}")
                if not is_active_savepoints:
                    print(f"   Path: {sp.get('savepoint_path', 'unknown')}")
                print()

    def print_job_details(self, job: Dict):
        """Print detailed job information"""
        print(f"\n🔍 Job Details: {job['job_name']}")
        print("=" * 80)

        print("📊 Basic Information:")
        print(f"   Job ID: {job['job_id']}")
        print(f"   Name: {job['job_name']}")
        print(f"   Status: {job['status']}")
        print(f"   Type: {job.get('job_type', 'UNKNOWN')}")

        if job.get("error_message"):
            print(f"   Error: {job['error_message']}")

        print("\n⏰ Timeline:")
        if job.get("created_at"):
            print(f"   Created: {job['created_at']}")
        if job.get("started_at"):
            print(f"   Started: {job['started_at']}")
        if job.get("finished_at"):
            print(f"   Finished: {job['finished_at']}")

        if job.get("savepoints"):
            print(f"\n💾 Savepoints ({len(job['savepoints'])}):")
            for sp in job["savepoints"][:3]:  # Show last 3
                created = sp.get("created_at", "Unknown")
                print(f"   {sp['savepoint_path']} ({created})")
            if len(job["savepoints"]) > 3:
                print(f"   ... and {len(job['savepoints']) - 3} more")

        if job.get("tags"):
            print(f"\n🏷️  Tags: {', '.join(job['tags'])}")

        if job.get("sql_content"):
            sql_preview = (
                job["sql_content"][:200] + "..."
                if len(job["sql_content"]) > 200
                else job["sql_content"]
            )
            print(f"\n📝 SQL Content:")
            print(f"   {sql_preview}")

        print(f"\n🔧 Management Commands:")
        print(f"   Cancel job (with savepoint): --cancel-job {job['job_id']}")


def print_jobs_from_rest_api(jobs: List[Dict], format_style: str = "table"):
    """Print jobs from Flink REST API in a formatted table"""
    if not jobs:
        print("📋 No jobs found")
        return

    if format_style == "json":
        print(json.dumps(jobs, indent=2, default=str))
        return

    # Prepare data for table
    headers = ["Job ID", "Job Name", "Status", "Start Time", "Duration"]
    data = []

    for job in jobs:
        # Handle both basic job info (from /jobs) and detailed info (from /jobs/{id})
        job_id = job.get("id") or job.get("jid", "unknown")

        # Status can be in 'status' (basic) or 'state' (detailed)
        status = job.get("status") or job.get("state", "UNKNOWN")

        # Job name - only available in detailed response
        job_name = job.get("name", "N/A")
        if job_name == "N/A" and "jid" in job:
            # This is a detailed response but no name, use a placeholder
            job_name = "unnamed"

        # Calculate duration and start time - only available in detailed response
        start_time = job.get("start-time")
        duration = "N/A"
        start_display = "N/A"

        if start_time and start_time > 0:
            try:
                start_time_ms = int(start_time)
                start_time_dt = datetime.fromtimestamp(start_time_ms / 1000)

                end_time = job.get("end-time")
                if end_time and end_time > 0:
                    end_time_dt = datetime.fromtimestamp(int(end_time) / 1000)
                    duration_delta = end_time_dt - start_time_dt
                else:
                    # Use the duration field if available, or calculate from now
                    duration_ms = job.get("duration")
                    if duration_ms and duration_ms > 0:
                        duration_delta = timedelta(milliseconds=duration_ms)
                    else:
                        duration_delta = datetime.now() - start_time_dt

                # Format duration
                total_seconds = int(duration_delta.total_seconds())
                hours, remainder = divmod(total_seconds, 3600)
                minutes, seconds = divmod(remainder, 60)

                if hours > 0:
                    duration = f"{hours}h {minutes}m"
                elif minutes > 0:
                    duration = f"{minutes}m {seconds}s"
                else:
                    duration = f"{seconds}s"

                # Format start time
                start_display = start_time_dt.strftime("%m-%d %H:%M")
            except Exception as e:
                # Silent fallback for any datetime issues
                duration = "N/A"
                start_display = "N/A"

        data.append(
            [
                job_id,
                job_name[:30] + "..." if len(job_name) > 33 else job_name,
                status,
                start_display,
                duration,
            ]
        )

    # Print table
    try:
        print("\n📋 Flink Jobs Overview (from cluster)")
        print("=" * 80)
        print(tabulate(data, headers=headers, tablefmt="grid"))

        # Summary
        status_counts = {}
        for job in jobs:
            status = job.get("status") or job.get("state", "UNKNOWN")
            status_counts[status] = status_counts.get(status, 0) + 1

        summary_parts = [
            f"{count} {status.lower()}" for status, count in status_counts.items()
        ]
        print(f"\n💾 Total: {len(jobs)} jobs ({', '.join(summary_parts)})")

    except Exception as e:
        # Fallback to simple table
        print("Jobs:")
        for i, row in enumerate(data):
            print(f"{i+1}. {' | '.join(str(cell) for cell in row)}")
        print(f"Error with table formatting: {e}")


def print_job_details_from_rest_api(job_details: Dict):
    """Print detailed job information from REST API"""
    print(f"\n🔍 Job Details: {job_details.get('name', 'Unknown')}")
    print("=" * 80)

    print("📊 Basic Information:")
    print(f"   Job ID: {job_details.get('jid', 'unknown')}")
    print(f"   Name: {job_details.get('name', 'unknown')}")
    print(f"   State: {job_details.get('state', 'UNKNOWN')}")
    print(f"   Is Stoppable: {job_details.get('isStoppable', False)}")

    start_time = job_details.get("start-time")
    if start_time:
        try:
            start_dt = datetime.fromtimestamp(int(start_time) / 1000)
            print(f"   Start Time: {start_dt.strftime('%Y-%m-%d %H:%M:%S')}")
        except:
            print(f"   Start Time: {start_time}")

    end_time = job_details.get("end-time")
    if end_time and end_time > 0:
        try:
            end_dt = datetime.fromtimestamp(int(end_time) / 1000)
            print(f"   End Time: {end_dt.strftime('%Y-%m-%d %H:%M:%S')}")
        except:
            print(f"   End Time: {end_time}")

    duration = job_details.get("duration")
    if duration:
        try:
            duration_seconds = int(duration) // 1000
            hours, remainder = divmod(duration_seconds, 3600)
            minutes, seconds = divmod(remainder, 60)
            if hours > 0:
                duration_str = f"{hours}h {minutes}m {seconds}s"
            elif minutes > 0:
                duration_str = f"{minutes}m {seconds}s"
            else:
                duration_str = f"{seconds}s"
            print(f"   Duration: {duration_str}")
        except:
            print(f"   Duration: {duration}")

    # Vertices (tasks) information
    vertices = job_details.get("vertices", [])
    if vertices:
        print(f"\n📋 Tasks ({len(vertices)}):")
        for vertex in vertices[:5]:  # Show first 5 tasks
            name = vertex.get("name", "Unknown")
            status = vertex.get("status", "UNKNOWN")
            parallelism = vertex.get("parallelism", 0)
            print(f"   {name} - {status} (parallelism: {parallelism})")
        if len(vertices) > 5:
            print(f"   ... and {len(vertices) - 5} more tasks")

    print(f"\n🔧 Management Commands:")
    job_id = job_details.get("jid", "unknown")
    print(f"   Cancel job (with savepoint): --cancel-job {job_id}")


def setup_logging(log_level: str, log_file: Optional[str] = None):
    """Setup logging configuration"""
    log_format = "%(asctime)s - %(levelname)s - %(message)s"

    # Configure root logger
    logging.basicConfig(
        level=getattr(logging, log_level.upper()), format=log_format, handlers=[]
    )

    logger = logging.getLogger()

    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(logging.Formatter(log_format))
    logger.addHandler(console_handler)

    # File handler (optional)
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(logging.Formatter(log_format))
        logger.addHandler(file_handler)


def load_config(config_file: str = "config.yaml") -> Dict:
    """Load configuration from YAML file"""
    config_path = Path(config_file)

    # Try to find config.yaml in the same directory as the script if not found
    if not config_path.exists():
        script_dir = Path(__file__).parent
        config_path = script_dir / "config.yaml"

    # Return default config if file doesn't exist
    if not config_path.exists():
        return {
            "sql_gateway": {
                "url": "http://localhost:8083",
                "session_timeout": 300,
                "poll_interval": 2,
                "max_wait_time": 60,
            },
            "logging": {
                "level": "INFO",
                "format": "%(asctime)s - %(levelname)s - %(message)s",
            },
            "execution": {"continue_on_error": True},
            "connection": {"timeout": 30, "retry_count": 3, "retry_delay": 5},
        }

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
            return config if config else {}
    except Exception as e:
        print(f"Warning: Could not load config file {config_path}: {e}")
        return {}


def format_sql_error(error_message: str, debug_mode: bool = False) -> str:
    """Format SQL error message for better readability"""
    if not error_message:
        return "❌ Unknown error occurred"

    # Clean up common unhelpful prefixes
    error_message = error_message.strip()
    if error_message.startswith("<Exception on server side:"):
        error_message = error_message[len("<Exception on server side:") :].strip()

    # Look for SQL parse errors specifically - they can be deeply nested
    if "SQL parse failed" in error_message or "SqlParseException" in error_message:
        # Extract the SQL parse error line
        lines = error_message.split("\n")
        parse_error_line = None

        for line in lines:
            line = line.strip()
            if line.startswith("SQL parse failed"):
                parse_error_line = line
                break
            elif "SqlParseException:" in line and "Encountered" in line:
                # Extract from nested exception
                parse_error_line = line.split("SqlParseException: ")[-1]
                break
            elif line.startswith("Encountered") and (
                "at line" in line or "column" in line
            ):
                parse_error_line = f"SQL parse failed. {line}"
                break

        if parse_error_line:
            # Always show pretty formatted error for SQL parse errors
            return f"""
╭─ SQL Parse Error ─────────────────────────────────────────────────────────╮
│ {parse_error_line}
│ 
│ This usually means:
│ • Invalid SQL syntax
│ • Reserved keyword used as identifier (try adding quotes)
│ • Missing quotes around string literals
│ • Incorrect table/column names
│ 
│ 💡 Suggestion: Check your SQL syntax and ensure all identifiers are properly quoted
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

    # Look for table not found errors
    if "Table" in error_message and "not found" in error_message:
        lines = error_message.split("\n")
        for line in lines:
            if "not found" in line.lower() and "Table" in line:
                # Always show pretty formatted error for table not found
                return f"""
╭─ Table Not Found Error ───────────────────────────────────────────────────╮
│ {line.strip()}
│ 
│ This usually means:
│ • Table doesn't exist in the catalog
│ • Incorrect table name or schema
│ • Table not registered in Flink
│ 
│ 💡 Suggestion: Check available tables with 'SHOW TABLES;'
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

    # Look for Flink-specific errors in the stack trace
    lines = error_message.split("\n")

    # Try to extract meaningful Flink errors from exception messages
    for line in lines:
        line = line.strip()

        # Look for Flink validation errors
        if "ValidationException" in line and ":" in line:
            error_part = line.split("ValidationException:")[-1].strip()
            if error_part and len(error_part) > 10:
                return f"""
╭─ SQL Validation Error ────────────────────────────────────────────────────╮
│ {error_part}
│ 
│ This usually means:
│ • Table or column doesn't exist
│ • Data type mismatch
│ • Invalid SQL operation for the context
│ 
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

        # Look for SQL parser validation errors (more specific pattern)
        if "SQL validation failed" in line:
            return f"""
╭─ SQL Validation Error ────────────────────────────────────────────────────╮
│ {line}
│ 
│ This usually means:
│ • Table or column doesn't exist
│ • Data type mismatch
│ • Invalid SQL operation for the context
│ 
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

        # Look for table resolution errors
        if "org.apache.flink.table.catalog.exceptions.TableNotExistException" in line:
            # Extract table name if possible
            table_match = None
            for next_line in lines[lines.index(line) : lines.index(line) + 3]:
                if "Table" in next_line and "does not exist" in next_line:
                    table_match = next_line.strip()
                    break

            table_info = (
                table_match if table_match else "Table does not exist in catalog"
            )
            return f"""
╭─ Table Not Found Error ───────────────────────────────────────────────────╮
│ {table_info}
│ 
│ This usually means:
│ • Table doesn't exist in the Flink catalog
│ • Incorrect table name or database/schema
│ • Table needs to be created or registered first
│ 
│ 💡 Suggestion: Check available tables with 'SHOW TABLES;'
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

        # Look for catalog errors
        if "CatalogException" in line and ":" in line:
            error_part = line.split("CatalogException:")[-1].strip()
            if error_part and len(error_part) > 10:
                return f"""
╭─ Catalog Error ───────────────────────────────────────────────────────────╮
│ {error_part}
│ 
│ This usually means:
│ • Issue with table catalog configuration
│ • Missing database or schema
│ • Catalog connection problems
│ 
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

    # For other errors, try to extract the most relevant line
    relevant_lines = []

    for line in lines:
        line = line.strip()
        if line and not line.startswith("at ") and not line.startswith("Caused by:"):
            # Look for lines that contain error information
            if (
                any(
                    keyword in line.lower()
                    for keyword in ["error", "failed", "exception", "invalid"]
                )
                and len(line) < 200
                and not line.startswith("org.apache.flink")  # Skip Java class names
            ):
                relevant_lines.append(line)

    if relevant_lines:
        main_error = relevant_lines[0]
        if debug_mode:
            debug_info = "\n".join(lines[:15])  # First 15 lines for context
            return f"""
╭─ SQL Execution Error ─────────────────────────────────────────────────────╮
│ {main_error}
│ 
│ Full error details:
│ {debug_info}
╰───────────────────────────────────────────────────────────────────────────╯"""
        else:
            # Pretty format even without debug mode
            return f"""
╭─ SQL Execution Error ─────────────────────────────────────────────────────╮
│ {main_error}
│ 
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

    # Look for the actual root cause in Flink stack traces
    # Often the real error is buried in "Caused by:" sections
    caused_by_errors = []
    for i, line in enumerate(lines):
        if line.strip().startswith("Caused by:"):
            # Look at the next few lines for the actual error
            for j in range(i + 1, min(i + 5, len(lines))):
                next_line = lines[j].strip()
                if next_line and not next_line.startswith("at "):
                    if any(
                        keyword in next_line.lower()
                        for keyword in ["exception", "error"]
                    ):
                        # Extract the error message part
                        if ":" in next_line:
                            error_part = next_line.split(":", 1)[-1].strip()
                            if error_part and len(error_part) > 5:
                                caused_by_errors.append(error_part)
                        break

    if caused_by_errors:
        main_error = caused_by_errors[0]
        if debug_mode:
            debug_info = "\n".join(lines[:15])
            return f"""
╭─ SQL Execution Error ─────────────────────────────────────────────────────╮
│ {main_error}
│ 
│ Full error details:
│ {debug_info}
╰───────────────────────────────────────────────────────────────────────────╯"""
        else:
            return f"""
╭─ SQL Execution Error ─────────────────────────────────────────────────────╮
│ {main_error}
│ 
│ 💡 Use --debug for more detailed error information
╰───────────────────────────────────────────────────────────────────────────╯"""

    # Final fallback with pretty formatting
    # Try to extract the first meaningful line
    first_meaningful_line = None
    for line in lines:
        line = line.strip()
        if (
            line
            and len(line) > 10
            and not line.startswith("at ")
            and not line.startswith("org.apache.flink")
            and not line.startswith("java.")
            and "Exception" not in line
        ):
            first_meaningful_line = line
            break

    if first_meaningful_line:
        display_error = first_meaningful_line
    else:
        # Last resort - show the cleaned up original message
        truncated_msg = error_message[:150] + (
            "..." if len(error_message) > 150 else ""
        )
        display_error = truncated_msg

    return f"""
╭─ SQL Execution Error ─────────────────────────────────────────────────────╮
│ {display_error}
│ 
│ 💡 Use --debug for more detailed error information
│ 💡 The query may reference non-existent tables or have syntax issues
╰───────────────────────────────────────────────────────────────────────────╯"""


def main():
    # First, create a parser to check if a custom config file is specified
    pre_parser = argparse.ArgumentParser(add_help=False)
    pre_parser.add_argument("--config", default="config.yaml")
    pre_args, _ = pre_parser.parse_known_args()

    # Load configuration using the specified config file
    config = load_config(pre_args.config)

    # Extract default values from config
    default_sql_gateway_url = config.get("sql_gateway", {}).get(
        "url", "http://localhost:8083"
    )
    default_log_level = config.get("logging", {}).get("level", "INFO")

    # Job management configuration
    job_config = config.get("job_management", {})
    flink_cluster_config = config.get("flink_cluster", {})

    default_db_path = job_config.get("database_path", "flink_jobs.db")
    default_flink_rest_url = flink_cluster_config.get("url")
    default_enable_db = job_config.get("enable_database", False)

    parser = argparse.ArgumentParser(
        description="Execute Flink SQL files and manage Flink jobs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Execute SQL from a specific file (supports multiple statements)
    python flink_sql_executor.py --file /path/to/my_query.sql
    
    # Execute multiple inline SQL statements
    python flink_sql_executor.py --sql "CREATE TABLE test AS SELECT 1; SELECT * FROM test;"
    
    # Execute as single statement (disable multi-statement parsing)
    python flink_sql_executor.py --file /path/to/my_query.sql --single-statement
    
    # Stop on first error instead of continuing
    python flink_sql_executor.py --file /path/to/my_query.sql --stop-on-error
    
    # Dry run to check what would be executed
    python flink_sql_executor.py --file /path/to/my_query.sql --dry-run
    
    # Use custom SQL Gateway URL
    python flink_sql_executor.py --file /path/to/my_query.sql --sql-gateway-url http://localhost:8083
    
    # Enable debug logging
    python flink_sql_executor.py --file /path/to/my_query.sql --log-level DEBUG
    
    # Use different table formats
    python flink_sql_executor.py --sql "SELECT * FROM my_table" --format simple
    
    # Output in JSON format
    python flink_sql_executor.py --sql "SELECT * FROM my_table" --format json
    python flink_sql_executor.py --sql "SELECT * FROM my_table" --json

Job Management Examples:
    # List all jobs from Flink cluster
    python flink_sql_executor.py --list-jobs
    
    # List jobs in JSON format
    python flink_sql_executor.py --list-jobs --json
    
    # List running jobs only
    python flink_sql_executor.py --list-jobs --status-filter RUNNING
    
    # List cancelled jobs only (two ways)
    python flink_sql_executor.py --list-jobs --cancelled
    python flink_sql_executor.py --list-jobs --status-filter CANCELED
    
    # List failed jobs
    python flink_sql_executor.py --list-jobs --status-filter FAILED
    
    # Show jobs of all statuses (including finished, failed, etc.)
    python flink_sql_executor.py --list-jobs --show-all
    
    # Get detailed information about a job
    python flink_sql_executor.py --job-info a1b2c3d4e5f6789abcdef123456789abcdef1234
    
    # Cancel a job gracefully with savepoint (uses Flink default savepoint directory)
    python flink_sql_executor.py --cancel-job a1b2c3d4e5f6789abcdef123456789abcdef1234
    
    # Pause a job (creates savepoint and stops the job)
    python flink_sql_executor.py --pause-job a1b2c3d4e5f6
    python flink_sql_executor.py --pause-job "my_streaming_job"  # Can use job name
    
    # Resume a paused job from its latest savepoint
    python flink_sql_executor.py --resume-job a1b2c3d4e5f6 --resume-sql-file /path/to/job.sql
    python flink_sql_executor.py --resume-job "my_streaming_job" --resume-sql-file /path/to/job.sql  # Can use job name
    
    # Resume from a specific savepoint ID with custom SQL
    python flink_sql_executor.py --resume-savepoint 1 --resume-sql-file /path/to/job.sql
    
    # List jobs that can be paused (running jobs)
    python flink_sql_executor.py --list-pausable
    
    # List jobs that can be resumed (paused jobs with savepoints)
    python flink_sql_executor.py --list-resumable
    
    # List active savepoint operations and their status
    python flink_sql_executor.py --list-active-savepoints
    
    # List savepoints with details (newest first, default: top 10)
    python flink_sql_executor.py --list-savepoints
    
    # List top 20 savepoints
    python flink_sql_executor.py --list-savepoints --limit 20
    
    # List all savepoints (no limit)
    python flink_sql_executor.py --list-savepoints --limit 0

Dry Run Examples (preview actions without executing):
    # Preview SQL execution
    python flink_sql_executor.py --file /path/to/my_query.sql --dry-run
    python flink_sql_executor.py --sql "CREATE TABLE test AS SELECT 1" --dry-run
    
    # Preview job management operations
    python flink_sql_executor.py --cancel-job a1b2c3d4e5f6 --dry-run
    python flink_sql_executor.py --pause-job my_job --dry-run
    python flink_sql_executor.py --resume-job my_job --resume-sql-file job.sql --dry-run
    python flink_sql_executor.py --resume-savepoint 1 --resume-sql-file job.sql --dry-run
        """,
    )

    parser.add_argument("--file", "-f", help="Path to SQL file to execute")

    parser.add_argument("--sql", "-s", help="Inline SQL query to execute")

    parser.add_argument(
        "--env-file",
        "-e",
        help="Path to environment file (.env) for variable substitution (default: .sbx-uat.env)",
        default=".sbx-uat.env",
    )

    parser.add_argument(
        "--sql-gateway-url",
        "--url",  # Add bash script compatibility alias
        "-u",  # Add bash script compatibility short form
        default=default_sql_gateway_url,
        help=f"Flink SQL Gateway URL (default: {default_sql_gateway_url})",
    )

    parser.add_argument(
        "--dry-run",
        "-d",  # Add bash script compatibility
        action="store_true",
        help="Show what would be executed without actually performing any operations (works with SQL execution and all job management commands)",
    )

    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug mode with detailed error information",
    )

    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default=default_log_level,
        help=f"Logging level (default: {default_log_level})",
    )

    parser.add_argument(
        "--log-file",
        "-l",  # Add bash script compatibility
        help="Log file path (optional)",
    )

    parser.add_argument(
        "--verbose",
        "-v",  # Add bash script compatibility
        action="store_true",
        help="Enable verbose logging (DEBUG level)",
    )

    parser.add_argument(
        "--continue-on-error",
        action="store_true",
        default=True,
        help="Continue executing remaining statements when one fails (default: True)",
    )

    parser.add_argument(
        "--stop-on-error",
        action="store_true",
        help="Stop execution on first error (overrides --continue-on-error)",
    )

    parser.add_argument(
        "--single-statement",
        action="store_true",
        help="Treat input as a single statement (don't parse multiple statements)",
    )

    parser.add_argument(
        "--config",
        default="config.yaml",
        help="Configuration file path (default: config.yaml)",
    )

    parser.add_argument(
        "--format",
        choices=["table", "simple", "plain", "json"],
        default="table",
        help="Output format for query results (default: table)",
    )

    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results in pretty-printed JSON format (equivalent to --format json)",
    )

    parser.add_argument(
        "--keep-session",
        action="store_true",
        help="Keep the SQL Gateway session open after execution (don't close it)",
    )

    # Job Management Arguments
    job_group = parser.add_argument_group(
        "Job Management", "Commands for managing Flink jobs via REST API"
    )

    job_group.add_argument(
        "--list-jobs",
        action="store_true",
        help="List all jobs from the Flink cluster (via REST API)",
    )

    job_group.add_argument(
        "--job-info",
        metavar="JOB_ID",
        help="Get detailed information about a specific job from Flink cluster",
    )

    job_group.add_argument(
        "--cancel-job",
        metavar="JOB_ID",
        help="Cancel a job gracefully with savepoint (uses Flink default savepoint directory)",
    )

    job_group.add_argument(
        "--pause-job",
        metavar="JOB_ID_OR_NAME",
        help="Pause a job by creating a savepoint and stopping it (can use job ID or job name)",
    )

    job_group.add_argument(
        "--resume-job",
        metavar="JOB_ID_OR_NAME",
        help="Resume a paused job from its latest savepoint (requires --resume-sql-file)",
    )

    job_group.add_argument(
        "--resume-savepoint",
        metavar="SAVEPOINT_ID",
        type=int,
        help="Resume from a specific savepoint ID (requires --resume-sql-file)",
    )

    job_group.add_argument(
        "--resume-sql-file",
        metavar="SQL_FILE",
        help="SQL file to execute when resuming from savepoint (required for --resume-job and --resume-savepoint)",
    )

    job_group.add_argument(
        "--list-pausable",
        action="store_true",
        help="List all jobs that can be paused (RUNNING status)",
    )

    job_group.add_argument(
        "--list-resumable",
        action="store_true",
        help="List all jobs that can be resumed (PAUSED status with savepoints)",
    )

    job_group.add_argument(
        "--list-active-savepoints",
        action="store_true",
        help="List all active/in-progress savepoint operations with their status",
    )

    job_group.add_argument(
        "--list-savepoints",
        action="store_true",
        help="List savepoints with their details and status (newest first, default: top 10)",
    )

    job_group.add_argument(
        "--limit",
        metavar="N",
        type=int,
        default=10,
        help="Maximum number of savepoints to display (default: 10, use 0 for all)",
    )

    job_group.add_argument(
        "--savepoint-dir",
        metavar="PATH",
        help="Target directory for savepoint storage (used with --pause-job only - cancel operations use Flink cluster default)",
    )

    job_group.add_argument(
        "--status-filter",
        metavar="STATUS",
        choices=["RUNNING", "FINISHED", "CANCELED", "FAILED", "CREATED"],
        help="Filter jobs by status (used with --list-jobs)",
    )

    job_group.add_argument(
        "--cancelled",
        action="store_true",
        help="Show only cancelled jobs (shortcut for --status-filter CANCELED)",
    )

    job_group.add_argument(
        "--show-all",
        action="store_true",
        help="Show jobs of all statuses (overrides status filters)",
    )

    job_group.add_argument(
        "--enable-database",
        action="store_true",
        default=default_enable_db,
        help=f"Enable job database for persistence features (default: {default_enable_db})",
    )

    job_group.add_argument(
        "--disable-database",
        action="store_true",
        help="Disable job database - use only REST API",
    )

    job_group.add_argument(
        "--db-path",
        metavar="PATH",
        default=default_db_path,
        help=f"Path to SQLite database for job storage (default: {default_db_path})",
    )

    job_group.add_argument(
        "--flink-rest-url",
        metavar="URL",
        default=default_flink_rest_url,
        help=f"Flink REST API URL for advanced operations. Use empty string to skip Flink connection (default: {default_flink_rest_url or 'None'})",
    )

    args = parser.parse_args()

    # Process error handling arguments
    continue_on_error = args.continue_on_error
    if args.stop_on_error:
        continue_on_error = False

    # Process output format arguments
    format_style = args.format
    if args.json:
        format_style = "json"

    # Handle verbose flag (bash script compatibility)
    log_level = args.log_level
    if args.verbose:
        log_level = "DEBUG"

    # Setup logging
    setup_logging(log_level, args.log_file)
    logger = logging.getLogger(__name__)

    try:
        # Process database settings
        enable_database = args.enable_database and not args.disable_database

        # Handle job management commands that don't require SQL execution
        # Commands that need Flink REST client
        rest_client_commands = [
            args.list_jobs,
            args.job_info,
            args.cancel_job,
        ]
        # Commands that only need database
        database_only_commands = [
            args.list_pausable,
            args.list_resumable,
            args.list_active_savepoints,
            args.list_savepoints,
        ]
        # Commands that need both REST client and database
        complex_commands = [args.pause_job, args.resume_job, args.resume_savepoint]

        if (
            any(rest_client_commands)
            or any(complex_commands)
            or any(database_only_commands)
        ):
            # For commands that need REST client, require the URL
            if (
                any(rest_client_commands) or any(complex_commands)
            ) and not args.flink_rest_url:
                logger.error("Flink REST API URL is required for this operation")
                logger.error(
                    "Please specify --flink-rest-url or configure flink_cluster.url in config.yaml"
                )
                sys.exit(1)

            # Create REST client only for commands that actually need it
            if any(rest_client_commands) or any(complex_commands):
                rest_client = FlinkRestClient(args.flink_rest_url)
            else:
                rest_client = None

            # Handle job management commands using REST API directly
            if args.list_jobs:
                logger.info("📋 Listing jobs from Flink cluster...")
                logger.info("🔍 Fetching detailed information for each job...")

                jobs = rest_client.get_all_jobs()

                if jobs is not None:
                    # Determine status filter
                    status_filter = None
                    if args.show_all:
                        # Show all jobs regardless of status
                        status_filter = None
                    elif args.cancelled:
                        # Shortcut for cancelled jobs
                        status_filter = "CANCELED"
                    elif args.status_filter:
                        # Explicit status filter
                        status_filter = args.status_filter

                    # Filter by status if specified
                    if status_filter:
                        jobs = [
                            job for job in jobs if job.get("state") == status_filter
                        ]

                    # Print jobs using REST API data format
                    print_jobs_from_rest_api(jobs, format_style)
                else:
                    logger.error("❌ Failed to retrieve jobs from Flink cluster")
                    sys.exit(1)
                return

            elif args.job_info:
                logger.info(f"🔍 Getting job information for {args.job_info}...")
                job_details = rest_client.get_job_details(args.job_info)
                if job_details:
                    print_job_details_from_rest_api(job_details)
                else:
                    logger.error(
                        f"Job not found or error retrieving job: {args.job_info}"
                    )
                    sys.exit(1)
                return

            elif args.cancel_job:
                if args.dry_run:
                    logger.info(
                        f"🛑 DRY RUN: Would cancel job {args.cancel_job} with savepoint"
                    )
                    logger.info(
                        "   Savepoint directory: (Flink cluster default configuration)"
                    )
                    if enable_database:
                        logger.info(
                            "   Would update job status to 'STOPPING' in database"
                        )
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    logger.info(f"🛑 Cancelling job {args.cancel_job}...")
                    success = rest_client.stop_job_with_savepoint(args.cancel_job)
                    if success:
                        logger.info("✅ Job cancel request submitted successfully")
                        if enable_database:
                            # Update database if enabled
                            database = FlinkJobDatabase(args.db_path)
                            database.update_job_status(args.cancel_job, "STOPPING")
                    else:
                        logger.error("❌ Failed to cancel job")
                        sys.exit(1)
                return

            elif args.pause_job:
                if not enable_database:
                    logger.error(
                        "Database must be enabled for pause operations (use --enable-database)"
                    )
                    sys.exit(1)

                if args.dry_run:
                    logger.info(f"⏸️ DRY RUN: Would pause job {args.pause_job}")
                    logger.info("   Actions that would be performed:")
                    logger.info("   1. Create savepoint for the running job")
                    if args.savepoint_dir:
                        logger.info(f"      Savepoint directory: {args.savepoint_dir}")
                    else:
                        logger.info(
                            "      Savepoint directory: /tmp/savepoints (default)"
                        )
                    logger.info(
                        "   2. Stop the job gracefully after savepoint completion"
                    )
                    logger.info("   3. Update job status to 'PAUSED' in database")
                    logger.info("   4. Store savepoint information for future resume")
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    # Create executor with database for pause operation
                    executor = FlinkSQLExecutor(
                        args.sql_gateway_url,
                        enable_job_tracking=enable_database,
                        db_path=args.db_path,
                        flink_rest_url=args.flink_rest_url,
                    )

                    if not check_sql_gateway_connectivity(args.sql_gateway_url):
                        logger.error("Cannot pause job without accessible SQL Gateway")
                        sys.exit(1)

                    if not executor.create_session():
                        logger.error("Failed to create session for pause operation")
                        sys.exit(1)

                    try:
                        success = executor.pause_job(args.pause_job, args.savepoint_dir)
                        if success:
                            logger.info("✅ Job paused successfully")
                        else:
                            logger.error("❌ Failed to pause job")
                            sys.exit(1)
                    finally:
                        executor.close_session()
                return

            elif args.resume_job:
                if not enable_database:
                    logger.error(
                        "Database must be enabled for resume operations (use --enable-database)"
                    )
                    sys.exit(1)

                if not args.resume_sql_file:
                    logger.error(
                        "--resume-sql-file is required when using --resume-job"
                    )
                    sys.exit(1)

                if not os.path.exists(args.resume_sql_file):
                    logger.error(f"SQL file not found: {args.resume_sql_file}")
                    sys.exit(1)

                if args.dry_run:
                    logger.info(f"▶️ DRY RUN: Would resume job {args.resume_job}")
                    logger.info(f"   SQL file: {args.resume_sql_file}")
                    if args.env_file:
                        logger.info(f"   Environment file: {args.env_file}")
                    logger.info("   Actions that would be performed:")
                    logger.info(
                        "   1. Look up latest savepoint for the job in database"
                    )
                    logger.info("   2. Perform safety checks (savepoint not in use)")
                    logger.info("   3. Read and validate SQL file")
                    logger.info("   4. Substitute environment variables in SQL")
                    logger.info(
                        "   5. Set 'execution.savepoint.path' to the savepoint location"
                    )
                    logger.info(
                        "   6. Execute the SQL file to restart the job from savepoint"
                    )
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    # Load environment variables if env file is specified
                    env_vars = {}
                    if args.env_file:
                        env_vars = load_env_file(args.env_file)

                    # Add OS environment variables to the mix
                    combined_env_vars = dict(os.environ)
                    if env_vars:
                        combined_env_vars.update(env_vars)

                    # Create executor with database for resume operation
                    executor = FlinkSQLExecutor(
                        args.sql_gateway_url,
                        enable_job_tracking=enable_database,
                        db_path=args.db_path,
                        flink_rest_url=args.flink_rest_url,
                    )

                    if not check_sql_gateway_connectivity(args.sql_gateway_url):
                        logger.error("Cannot resume job without accessible SQL Gateway")
                        sys.exit(1)

                    if not executor.create_session():
                        logger.error("Failed to create session for resume operation")
                        sys.exit(1)

                    try:
                        success = executor.resume_job(
                            args.resume_job, args.resume_sql_file, combined_env_vars
                        )
                        if success:
                            logger.info("✅ Job resumed successfully")
                        else:
                            logger.error("❌ Failed to resume job")
                            sys.exit(1)
                    finally:
                        executor.close_session()
                return

            elif args.resume_savepoint:
                if not enable_database:
                    logger.error(
                        "Database must be enabled for resume operations (use --enable-database)"
                    )
                    sys.exit(1)

                if not args.resume_sql_file:
                    logger.error(
                        "--resume-sql-file is required when using --resume-savepoint"
                    )
                    sys.exit(1)

                if not os.path.exists(args.resume_sql_file):
                    logger.error(f"SQL file not found: {args.resume_sql_file}")
                    sys.exit(1)

                if args.dry_run:
                    logger.info(
                        f"▶️ DRY RUN: Would resume from savepoint ID {args.resume_savepoint}"
                    )
                    logger.info(f"   SQL file: {args.resume_sql_file}")
                    if args.env_file:
                        logger.info(f"   Environment file: {args.env_file}")
                    logger.info("   Actions that would be performed:")
                    logger.info("   1. Look up savepoint details by ID in database")
                    logger.info("   2. Perform safety checks (savepoint not in use)")
                    logger.info("   3. Read and validate SQL file")
                    logger.info("   4. Substitute environment variables in SQL")
                    logger.info(
                        "   5. Set 'execution.savepoint.path' to the savepoint location"
                    )
                    logger.info(
                        "   6. Execute the SQL file to start new job from savepoint"
                    )
                    logger.info("   7. Record resume event in database")
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    # Load environment variables if env file is specified
                    env_vars = {}
                    if args.env_file:
                        env_vars = load_env_file(args.env_file)

                    # Add OS environment variables to the mix
                    combined_env_vars = dict(os.environ)
                    if env_vars:
                        combined_env_vars.update(env_vars)

                    # Create executor with database for resume operation
                    executor = FlinkSQLExecutor(
                        args.sql_gateway_url,
                        enable_job_tracking=enable_database,
                        db_path=args.db_path,
                        flink_rest_url=args.flink_rest_url,
                    )

                    if not check_sql_gateway_connectivity(args.sql_gateway_url):
                        logger.error("Cannot resume job without accessible SQL Gateway")
                        sys.exit(1)

                    if not executor.create_session():
                        logger.error("Failed to create session for resume operation")
                        sys.exit(1)

                    try:
                        success = executor.resume_from_savepoint_id(
                            args.resume_savepoint,
                            args.resume_sql_file,
                            combined_env_vars,
                        )
                        if success:
                            logger.info("✅ Job resumed from savepoint successfully")
                        else:
                            logger.error("❌ Failed to resume job from savepoint")
                            sys.exit(1)
                    finally:
                        executor.close_session()
                return

            elif args.list_pausable:
                if not enable_database:
                    logger.error(
                        "Database must be enabled for listing pausable jobs (use --enable-database)"
                    )
                    sys.exit(1)

                executor = FlinkSQLExecutor(
                    args.sql_gateway_url,
                    enable_job_tracking=enable_database,
                    db_path=args.db_path,
                    flink_rest_url=args.flink_rest_url,
                )

                jobs = executor.list_pausable_jobs()
                if jobs:
                    print("\n⏸️ Pausable Jobs (RUNNING status):")
                    executor.print_jobs_table(jobs, format_style)
                else:
                    print("📋 No pausable jobs found")
                return

            elif args.list_resumable:
                if not enable_database:
                    logger.error(
                        "Database must be enabled for listing resumable jobs (use --enable-database)"
                    )
                    sys.exit(1)

                executor = FlinkSQLExecutor(
                    args.sql_gateway_url,
                    enable_job_tracking=enable_database,
                    db_path=args.db_path,
                    flink_rest_url=args.flink_rest_url,
                )

                jobs = executor.list_resumable_jobs()
                if jobs:
                    print("\n▶️ Resumable Jobs (PAUSED status with savepoints):")
                    executor.print_jobs_table(jobs, format_style)
                else:
                    print("📋 No resumable jobs found")
                return

            elif args.list_active_savepoints:
                if not enable_database:
                    logger.error(
                        "Database must be enabled for listing active savepoints (use --enable-database)"
                    )
                    sys.exit(1)

                executor = FlinkSQLExecutor(
                    args.sql_gateway_url,
                    enable_job_tracking=enable_database,
                    db_path=args.db_path,
                    flink_rest_url=args.flink_rest_url,
                )

                try:
                    savepoints = executor.get_active_savepoints()
                    if savepoints:
                        print("\n💾 Active Savepoint Operations:")
                        executor.print_savepoints_table(savepoints, format_style)
                    else:
                        print("📋 No active savepoint operations found")
                finally:
                    executor.close_session()
                return

            elif args.list_savepoints:
                if not enable_database:
                    logger.error(
                        "Database must be enabled for listing savepoints (use --enable-database)"
                    )
                    sys.exit(1)

                # For listing savepoints, we use the database as primary source
                # REST client is optional and only used for active/running savepoints
                executor = FlinkSQLExecutor(
                    args.sql_gateway_url,
                    enable_job_tracking=enable_database,
                    db_path=args.db_path,
                    flink_rest_url=args.flink_rest_url,
                )

                try:
                    savepoints = executor.get_savepoint_details()
                    if savepoints:
                        # Apply limit (0 means show all)
                        limit = args.limit if args.limit > 0 else len(savepoints)
                        limited_savepoints = savepoints[:limit]

                        if args.limit > 0 and len(savepoints) > args.limit:
                            print(
                                f"\n💾 Savepoints (showing newest {limit} of {len(savepoints)} total):"
                            )
                            print(f"💡 Use --limit 0 to show all savepoints")
                        else:
                            print(f"\n💾 All Savepoints ({len(savepoints)} total):")

                        executor.print_savepoints_table(
                            limited_savepoints, format_style
                        )
                    else:
                        print("📋 No savepoints found")
                finally:
                    executor.close_session()
                return

        # Validate arguments for SQL execution
        if not args.sql and not args.file:
            logger.error("Either --sql or --file must be specified")
            sys.exit(1)

        # Ensure only one execution mode is specified
        if args.sql and args.file:
            logger.error("Only one of --sql or --file can be specified at a time")
            sys.exit(1)

        # Check SQL Gateway connectivity (optional - don't fail if not accessible for dry runs)
        if not args.dry_run:
            if not check_sql_gateway_connectivity(args.sql_gateway_url):
                logger.error("Cannot proceed without accessible SQL Gateway")
                sys.exit(1)
        else:
            # For dry runs, check connectivity but don't fail
            check_sql_gateway_connectivity(args.sql_gateway_url)

        if args.sql:
            # Execute inline SQL
            logger.info("Executing inline SQL query")
            executor = FlinkSQLExecutor(
                args.sql_gateway_url,
                enable_job_tracking=enable_database,
                db_path=args.db_path,
                flink_rest_url=args.flink_rest_url,
            )

            # For inline SQL, use it directly without variable substitution
            sql_content = args.sql

            if not args.dry_run:
                if not executor.create_session():
                    logger.error("Failed to create SQL Gateway session")
                    sys.exit(1)

            try:
                if args.dry_run:
                    # Show what would be executed
                    if args.single_statement:
                        logger.info(
                            f"DRY RUN: Would execute single SQL statement: {sql_content}"
                        )
                    else:
                        statements = executor.parse_sql_statements(sql_content)
                        logger.info(
                            f"DRY RUN: Would execute {len(statements)} SQL statement(s)"
                        )
                        for i, stmt in enumerate(statements, 1):
                            logger.info(
                                f"  Statement {i}: {stmt[:100]}{'...' if len(stmt) > 100 else ''}"
                            )
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    if args.single_statement:
                        # Execute as single statement
                        success, result = executor.execute_statement(
                            sql_content, "inline-query", format_style
                        )
                        if success:
                            logger.info("🎉 Inline SQL executed successfully!")
                        else:
                            logger.error("💥 Inline SQL execution failed!")
                            if "error" in result:
                                formatted_error = format_sql_error(
                                    result["error"], args.debug
                                )
                                print(
                                    formatted_error
                                )  # Always print pretty error to console
                            sys.exit(1)
                    else:
                        # Execute as multiple statements
                        success, results = executor.execute_multiple_statements(
                            sql_content, "inline-query", continue_on_error, format_style
                        )

                        if success:
                            logger.info(
                                "🎉 All inline SQL statements executed successfully!"
                            )
                        else:
                            logger.error("💥 Some inline SQL statements failed!")

                            # Show detailed error information
                            failed_statements = [
                                r for r in results if not r.get("success", True)
                            ]
                            for failed in failed_statements:
                                stmt_num = failed.get("statement_number", "?")
                                error_msg = failed.get("error", "Unknown error")
                                formatted_error = format_sql_error(
                                    error_msg, args.debug
                                )
                                print(f"\n💥 Statement {stmt_num} error:")
                                print(formatted_error)

                            sys.exit(1)
            finally:
                if not args.dry_run and not args.keep_session:
                    executor.close_session()
                elif not args.dry_run and args.keep_session:
                    logger.info(f"🔄 Keeping session open: {executor.session_handle}")
        else:
            # Execute SQL from file
            file_path = Path(args.file)
            if not file_path.exists():
                logger.error(f"SQL file not found: {file_path}")
                sys.exit(1)

            if not file_path.is_file():
                logger.error(f"Path is not a file: {file_path}")
                sys.exit(1)

            logger.info(f"Executing SQL from file: {file_path}")
            executor = FlinkSQLExecutor(
                args.sql_gateway_url,
                enable_job_tracking=enable_database,
                db_path=args.db_path,
                flink_rest_url=args.flink_rest_url,
            )

            if not args.dry_run:
                if not executor.create_session():
                    logger.error("Failed to create SQL Gateway session")
                    sys.exit(1)

            try:
                # Load environment variables if env file is specified
                env_vars = {}
                if args.env_file:
                    env_vars = load_env_file(args.env_file)

                # Add OS environment variables to the mix
                combined_env_vars = dict(os.environ)
                if env_vars:
                    combined_env_vars.update(env_vars)

                # Read SQL content from file
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        sql_content = f.read().strip()

                    if not sql_content:
                        logger.error(f"Empty SQL file: {file_path}")
                        sys.exit(1)

                    # Apply environment variable substitution with strict validation
                    try:
                        sql_content = substitute_env_variables(
                            sql_content, combined_env_vars, strict=True
                        )
                    except ValueError as e:
                        logger.error(f"Environment variable validation failed: {e}")
                        sys.exit(1)

                except Exception as e:
                    logger.error(f"Error reading SQL file {file_path}: {e}")
                    sys.exit(1)

                if args.dry_run:
                    # Show what would be executed
                    if args.single_statement:
                        logger.info(
                            f"DRY RUN: Would execute SQL from {file_path} as single statement"
                        )
                        logger.info(f"SQL content ({len(sql_content)} characters):")
                        logger.info(
                            f"{sql_content[:500]}{'...' if len(sql_content) > 500 else ''}"
                        )
                    else:
                        statements = executor.parse_sql_statements(sql_content)
                        logger.info(
                            f"DRY RUN: Would execute {len(statements)} SQL statement(s) from {file_path}"
                        )
                        for i, stmt in enumerate(statements, 1):
                            logger.info(
                                f"  Statement {i}: {stmt[:100]}{'...' if len(stmt) > 100 else ''}"
                            )
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    if args.single_statement:
                        # Execute as single statement
                        success, result = executor.execute_statement(
                            sql_content, file_path.name, format_style
                        )
                        if success:
                            logger.info(
                                f"🎉 SQL file {file_path.name} executed successfully!"
                            )
                        else:
                            logger.error(
                                f"💥 SQL file {file_path.name} execution failed!"
                            )
                            if "error" in result:
                                formatted_error = format_sql_error(
                                    result["error"], args.debug
                                )
                                print(
                                    formatted_error
                                )  # Always print pretty error to console
                            sys.exit(1)
                    else:
                        # Execute as multiple statements
                        success, results = executor.execute_multiple_statements(
                            sql_content, file_path.name, continue_on_error, format_style
                        )

                        if success:
                            logger.info(
                                f"🎉 All statements in {file_path.name} executed successfully!"
                            )
                        else:
                            logger.error(
                                f"💥 Some statements in {file_path.name} failed!"
                            )

                            # Show detailed error information
                            failed_statements = [
                                r for r in results if not r.get("success", True)
                            ]
                            for failed in failed_statements:
                                stmt_num = failed.get("statement_number", "?")
                                error_msg = failed.get("error", "Unknown error")
                                formatted_error = format_sql_error(
                                    error_msg, args.debug
                                )
                                print(f"\n💥 Statement {stmt_num} error:")
                                print(formatted_error)

                            sys.exit(1)
            finally:
                if not args.dry_run and not args.keep_session:
                    executor.close_session()
                elif not args.dry_run and args.keep_session:
                    logger.info(f"🔄 Keeping session open: {executor.session_handle}")

        sys.exit(0)

    except KeyboardInterrupt:
        logger.info("Execution interrupted by user")
        sys.exit(1)
    except Exception as e:
        # Show pretty formatted error for unexpected exceptions
        formatted_error = f"""
╭─ Unexpected Error ────────────────────────────────────────────────────────╮
│ {str(e)}
│ 
│ This appears to be an unexpected error in the Flink SQL Executor.
│ 
│ 💡 Use --debug for more detailed error information
│ 💡 Check your network connection to the Flink SQL Gateway
╰───────────────────────────────────────────────────────────────────────────╯"""
        print(formatted_error)
        sys.exit(1)


if __name__ == "__main__":
    main()
