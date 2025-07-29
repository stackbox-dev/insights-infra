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
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import requests
import yaml
from datetime import datetime
from tabulate import tabulate


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
        with open(env_file_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                
                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue
                
                # Parse KEY=VALUE format
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    # Remove quotes if present
                    if (value.startswith('"') and value.endswith('"')) or \
                       (value.startswith("'") and value.endswith("'")):
                        value = value[1:-1]
                    
                    env_vars[key] = value
                else:
                    print(f"⚠️  Invalid format in {env_file_path} line {line_num}: {line}")
        
        print(f"✅ Loaded {len(env_vars)} environment variables from {env_file_path}")
        return env_vars
        
    except Exception as e:
        print(f"❌ Error reading environment file {env_file_path}: {e}")
        return env_vars


def substitute_env_variables(sql_content: str, env_vars: Dict[str, str]) -> str:
    """
    Substitute environment variables in SQL content
    
    Args:
        sql_content: SQL content with ${VAR_NAME} placeholders
        env_vars: Dictionary of environment variables
        
    Returns:
        SQL content with variables substituted
    """
    if not env_vars:
        return sql_content
    
    # Pattern to match ${VARIABLE_NAME}
    pattern = r'\$\{([^}]+)\}'
    
    def replace_var(match):
        var_name = match.group(1)
        if var_name in env_vars:
            return env_vars[var_name]
        else:
            print(f"⚠️  Environment variable not found: {var_name}")
            return match.group(0)  # Return original placeholder if variable not found
    
    substituted_content = re.sub(pattern, replace_var, sql_content)
    
    # Count substitutions made
    original_vars = re.findall(pattern, sql_content)
    if original_vars:
        print(f"✅ Substituted {len(original_vars)} environment variables: {original_vars}")
    
    return substituted_content


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
        print(f"⚠️  Make sure the Flink cluster is running and the SQL Gateway is enabled")
        print(f"    Error: {e}")
        return False


class FlinkSQLExecutor:
    """
    Manages execution of SQL statements against Flink SQL Gateway
    """

    def __init__(self, sql_gateway_url: str, session_timeout: int = 300):
        self.sql_gateway_url = sql_gateway_url.rstrip("/")
        self.session_timeout = session_timeout
        self.session_handle: Optional[str] = None
        self.logger = logging.getLogger(__name__)

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
        continue_on_error: bool = True,
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
        error_message = error_message[len("<Exception on server side:"):].strip()

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
            for next_line in lines[lines.index(line):lines.index(line)+3]:
                if "Table" in next_line and "does not exist" in next_line:
                    table_match = next_line.strip()
                    break
            
            table_info = table_match if table_match else "Table does not exist in catalog"
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
            for j in range(i+1, min(i+5, len(lines))):
                next_line = lines[j].strip()
                if next_line and not next_line.startswith("at "):
                    if any(keyword in next_line.lower() for keyword in ["exception", "error"]):
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
        if (line and 
            len(line) > 10 and 
            not line.startswith("at ") and 
            not line.startswith("org.apache.flink") and
            not line.startswith("java.") and
            "Exception" not in line):
            first_meaningful_line = line
            break

    if first_meaningful_line:
        display_error = first_meaningful_line
    else:
        # Last resort - show the cleaned up original message
        truncated_msg = error_message[:150] + ('...' if len(error_message) > 150 else '')
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

    parser = argparse.ArgumentParser(
        description="Execute Flink SQL files for landscape environments",
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
        """,
    )

    parser.add_argument("--file", "-f", help="Path to SQL file to execute")

    parser.add_argument("--sql", "-s", help="Inline SQL query to execute")

    parser.add_argument(
        "--env-file",
        "-e",
        help="Path to environment file (.env) for variable substitution (default: .sbx-uat.env)",
        default=".sbx-uat.env"
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
        help="Show what would be executed without running SQL statements",
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
        help="Log file path (optional)"
    )

    parser.add_argument(
        "--verbose",
        "-v",  # Add bash script compatibility
        action="store_true",
        help="Enable verbose logging (DEBUG level)"
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
        # Validate arguments
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
            executor = FlinkSQLExecutor(args.sql_gateway_url)

            # Load environment variables if env file is specified
            env_vars = {}
            if args.env_file:
                env_vars = load_env_file(args.env_file)

            # Apply environment variable substitution to inline SQL
            sql_content = args.sql
            if env_vars:
                sql_content = substitute_env_variables(sql_content, env_vars)

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
                                print(formatted_error)  # Always print pretty error to console
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
            executor = FlinkSQLExecutor(args.sql_gateway_url)

            if not args.dry_run:
                if not executor.create_session():
                    logger.error("Failed to create SQL Gateway session")
                    sys.exit(1)

            try:
                # Load environment variables if env file is specified
                env_vars = {}
                if args.env_file:
                    env_vars = load_env_file(args.env_file)
                
                # Read SQL content from file
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        sql_content = f.read().strip()

                    if not sql_content:
                        logger.error(f"Empty SQL file: {file_path}")
                        sys.exit(1)
                    
                    # Apply environment variable substitution
                    if env_vars:
                        sql_content = substitute_env_variables(sql_content, env_vars)

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
                                print(formatted_error)  # Always print pretty error to console
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
