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


class FlinkSQLExecutor:
    """
    Manages execution of SQL statements against Flink SQL Gateway
    """
    
    def __init__(self, sql_gateway_url: str, session_timeout: int = 300):
        self.sql_gateway_url = sql_gateway_url.rstrip('/')
        self.session_timeout = session_timeout
        self.session_handle: Optional[str] = None
        self.logger = logging.getLogger(__name__)
        
    def create_session(self) -> bool:
        """Create a new SQL Gateway session"""
        try:
            url = f"{self.sql_gateway_url}/v1/sessions"
            payload = {
                "properties": {
                    "execution.runtime-mode": "streaming"
                }
            }
            
            self.logger.info(f"Creating SQL Gateway session at {url}")
            response = requests.post(url, json=payload, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                self.session_handle = result.get('sessionHandle')
                self.logger.info(f"✓ SQL Gateway session created: {self.session_handle}")
                self.logger.debug(f"Session will be reused for all SQL statements in this execution")
                return True
            else:
                self.logger.error(f"✗ Failed to create session: {response.status_code} - {response.text}")
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
        lines = sql_content.split('\n')
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
                    elif char == '-' and i < len(line) - 1 and line[i + 1] == '-':
                        comment_pos = i
                        break
                else:
                    if char == quote_char and (i == 0 or line[i - 1] != '\\'):
                        in_string = False
                        quote_char = None
            
            if comment_pos >= 0:
                line = line[:comment_pos]
            
            cleaned_lines.append(line)
        
        sql_content = '\n'.join(cleaned_lines)
        
        # Remove /* */ comments
        sql_content = re.sub(r'/\*.*?\*/', '', sql_content, flags=re.DOTALL)
        
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
                elif char == ';':
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
                    if len(current_statement) < 2 or current_statement[-2] != '\\':
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
        continue_on_error: bool = True
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
        
        self.logger.info(f"Found {len(statements)} SQL statement(s) in {source_name or 'input'}")
        self.logger.info(f"Using session {self.session_handle} for all statements")
        
        results = []
        overall_success = True
        has_streaming_queries = False
        
        for i, statement in enumerate(statements, 1):
            self.logger.info(f"Executing statement {i}/{len(statements)} using session {self.session_handle}")
            self.logger.debug(f"Statement {i}: {statement[:100]}{'...' if len(statement) > 100 else ''}")
            
            statement_name = f"{source_name}_stmt_{i}" if source_name else f"statement_{i}"
            success, result = self.execute_statement(statement, statement_name)
            
            # Track if we have streaming queries
            if success and result.get('is_streaming', False):
                has_streaming_queries = True
            
            result['statement_number'] = i
            result['statement'] = statement
            result['success'] = success
            results.append(result)
            
            if not success:
                overall_success = False
                self.logger.error(f"Statement {i} failed")
                
                if not continue_on_error:
                    self.logger.info(f"Stopping execution due to error (continue_on_error=False)")
                    break
                else:
                    self.logger.info(f"Continuing with remaining statements (continue_on_error=True)")
        
        # Add delay before session closure if we had streaming queries
        if has_streaming_queries:
            self.logger.info("Waiting additional 3 seconds before closing session for streaming query cleanup...")
            time.sleep(3)
        
        if overall_success:
            self.logger.info(f"✅ All {len(statements)} statements executed successfully")
        else:
            failed_count = sum(1 for r in results if not r.get('success', False))
            success_count = len(results) - failed_count
            self.logger.warning(f"⚠️ {success_count}/{len(statements)} statements succeeded, {failed_count} failed")
        
        return overall_success, results
    
    def execute_statement(self, sql_statement: str, statement_name: str = "") -> Tuple[bool, Dict]:
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
            operation_handle = result.get('operationHandle')
            
            if not operation_handle:
                error_msg = f"No operation handle received: {result}"
                self.logger.error(f"✗ {error_msg}")
                return False, {"error": error_msg}
            
            # Poll for completion
            return self._poll_operation_status(operation_handle, statement_name)
            
        except requests.RequestException as e:
            error_msg = f"Connection error executing statement: {e}"
            self.logger.error(f"✗ {error_msg}")
            return False, {"error": error_msg}
    
    def _poll_operation_status(self, operation_handle: str, statement_name: str, max_wait: int = 60) -> Tuple[bool, Dict]:
        """Poll operation status until completion"""
        url = f"{self.sql_gateway_url}/v1/sessions/{self.session_handle}/operations/{operation_handle}/status"
        
        start_time = time.time()
        poll_count = 0
        
        while time.time() - start_time < max_wait:
            try:
                response = requests.get(url, timeout=10)
                
                if response.status_code != 200:
                    error_msg = f"Failed to get operation status: {response.status_code}"
                    return False, {"error": error_msg}
                
                status_result = response.json()
                status = status_result.get('status', 'UNKNOWN')
                
                poll_count += 1
                self.logger.debug(f"Poll #{poll_count}: Status = {status}")
                
                if status == 'FINISHED':
                    duration = time.time() - start_time
                    
                    # Fetch results for queries that return data
                    result_data = self._fetch_operation_result(operation_handle)
                    
                    # Check if this is a streaming query that needs more time to collect results
                    is_streaming_query = result_data and result_data.get('jobID') is not None
                    
                    if is_streaming_query:
                        self.logger.info(f"✓ {statement_name or 'Statement'} streaming job submitted successfully ({duration:.1f}s)")
                        self.logger.info(f"Waiting 5 seconds for streaming job to collect initial results...")
                        time.sleep(5)  # Give streaming job time to collect results
                        
                        # Re-fetch results after waiting
                        result_data = self._fetch_operation_result(operation_handle)
                    else:
                        self.logger.info(f"✓ {statement_name or 'Statement'} completed successfully ({duration:.1f}s)")
                    
                    # Print results - always show row count summary, even for 0 rows
                    if result_data and result_data.get('results'):
                        self._print_query_results(result_data, statement_name)
                    
                    return True, {
                        "status": status,
                        "duration": duration,
                        "polls": poll_count,
                        "result": result_data,
                        "is_streaming": is_streaming_query
                    }
                elif status == 'ERROR':
                    error_info = status_result.get('errorMessage', {})
                    self.logger.debug(f"Full error response: {json.dumps(status_result, indent=2)}")
                    
                    detailed_error = None
                    # Try to fetch the operation result for more detailed error info
                    try:
                        result_url = f"{self.sql_gateway_url}/v1/sessions/{self.session_handle}/operations/{operation_handle}/result/0"
                        result_response = requests.get(result_url, timeout=10)
                        if result_response.status_code == 200:
                            result_data = result_response.json()
                            self.logger.debug(f"Error result data: {json.dumps(result_data, indent=2)}")
                        elif result_response.status_code >= 400:
                            # The error details are likely in the response text
                            error_text = result_response.text
                            self.logger.debug(f"Detailed error from result endpoint: {error_text}")
                            detailed_error = error_text
                            
                            # Try to parse the JSON to get the actual error
                            try:
                                error_json = json.loads(error_text)
                                if 'errors' in error_json and len(error_json['errors']) > 1:
                                    # The second element often contains the detailed error
                                    detailed_error = error_json['errors'][1]
                            except:
                                pass  # Use raw error_text if JSON parsing fails
                                
                    except Exception as e:
                        self.logger.debug(f"Could not fetch error result: {e}")
                    
                    # Use detailed error if available, otherwise fall back to basic error message
                    if detailed_error:
                        error_msg = detailed_error
                    else:
                        error_msg = error_info.get('errorMessage', status_result.get('errorMessage', 'SQL execution failed'))
                    
                    self.logger.error(f"✗ {statement_name or 'Statement'} failed")
                    return False, {
                        "status": status,
                        "error": error_msg,
                        "full_error": error_info
                    }
                elif status in ['RUNNING', 'PENDING']:
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
    
    def _fetch_operation_result(self, operation_handle: str, max_fetch_attempts: int = 100) -> Optional[Dict]:
        """Fetch the result data from a completed operation using proper pagination protocol"""
        all_results = {
            'results': {
                'columns': [],
                'data': []
            },
            'resultType': None,
            'isQueryResult': False,
            'resultKind': None,
            'jobID': None
        }
        
        # Start with token 0 as per Flink documentation
        next_result_uri = f"/v1/sessions/{self.session_handle}/operations/{operation_handle}/result/0"
        fetch_attempts = 0
        
        try:
            while next_result_uri and fetch_attempts < max_fetch_attempts:
                fetch_attempts += 1
                url = f"{self.sql_gateway_url}{next_result_uri}"
                
                self.logger.debug(f"🔄 Fetching results (attempt {fetch_attempts}): {url}")
                response = requests.get(url, timeout=10)
                
                if response.status_code != 200:
                    self.logger.debug(f"No result data available: {response.status_code}")
                    if fetch_attempts == 1:
                        return None  # No results at all
                    else:
                        break  # Stop fetching but return what we have
                
                result_data = response.json()
                
                # Initialize all_results with metadata from first response
                if fetch_attempts == 1:
                    all_results['resultType'] = result_data.get('resultType')
                    all_results['isQueryResult'] = result_data.get('isQueryResult', False)
                    all_results['resultKind'] = result_data.get('resultKind')
                    all_results['jobID'] = result_data.get('jobID')
                    
                    # Set columns from first response
                    results = result_data.get('results', {})
                    if results.get('columns'):
                        all_results['results']['columns'] = results['columns']
                
                # Accumulate data from each response
                results = result_data.get('results', {})
                if results.get('data'):
                    all_results['results']['data'].extend(results['data'])
                
                # Check for nextResultUri to continue pagination
                next_result_uri = result_data.get('nextResultUri')
                
                self.logger.debug(f"📦 Fetched {len(results.get('data', []))} rows, nextResultUri: {next_result_uri}")
                
                # For streaming queries, if we get some data but no nextResultUri, 
                # we might need to wait a bit for more data
                if not next_result_uri and all_results['isQueryResult'] and len(all_results['results']['data']) == 0:
                    self.logger.debug("🕐 No data yet for streaming query, waiting...")
                    time.sleep(5)
                    # Reset to try fetching from current position again
                    next_result_uri = f"/v1/sessions/{self.session_handle}/operations/{operation_handle}/result/{fetch_attempts - 1}"
                    continue
                
                # If we have data and no more nextResultUri, we're done
                if not next_result_uri:
                    break
                    
                # Longer delay between fetches to give streaming data time to arrive
                time.sleep(5)
            
            total_rows = len(all_results['results']['data'])
            self.logger.debug(f"✅ Total rows fetched: {total_rows} in {fetch_attempts} attempts")
            
            if total_rows > 0 or fetch_attempts == 1:
                return all_results
            else:
                return None
            
        except requests.RequestException as e:
            self.logger.debug(f"Error fetching result: {e}")
            return None
    
    def _print_query_results(self, result_data: Dict, statement_name: str):
        """Print formatted query results"""
        try:
            # Check if there are results to display
            results = result_data.get('results', {})
            if not results:
                self.logger.info(f"No results structure returned for {statement_name}")
                print(f"\n📊 Results for {statement_name}:")
                print("=" * 60)
                print("❌ No results structure returned")
                print("=" * 60)
                print()
                return

            print(f"\n📊 Results for {statement_name}:")
            print("=" * 60)

            # Get column information and data
            columns = results.get('columns', [])
            data_rows = results.get('data', [])
            
            # Enhanced debugging for Kafka streaming queries
            result_type = result_data.get('resultType', 'UNKNOWN')
            is_query_result = result_data.get('isQueryResult', False)
            result_kind = result_data.get('resultKind', 'UNKNOWN')
            job_id = result_data.get('jobID', 'N/A')
            
            # Count actual data rows (excluding metadata)
            actual_data_rows = [row for row in data_rows if row.get('kind') == 'INSERT'] if data_rows else []
            total_rows_returned = len(data_rows) if data_rows else 0
            data_rows_count = len(actual_data_rows)
            
            print(f"📈 Row Summary:")
            print(f"  • Total rows returned: {total_rows_returned}")
            print(f"  • Data rows (INSERT): {data_rows_count}")
            print(f"  • Columns: {len(columns)}")
            print(f"  • Result Type: {result_type}")
            print(f"  • Is Query Result: {is_query_result}")
            print(f"  • Result Kind: {result_kind}")
            print(f"  • Job ID: {job_id}")
            print()

            if not data_rows:
                print("❌ No data returned - the query executed successfully but returned 0 rows.")
                print("This could mean:")
                print("  • The Kafka topic is empty")
                print("  • No data matches the query criteria")
                print("  • The table source is not producing data yet")
                print("  • Schema registry issues preventing deserialization")
                print("  • Avro schema mismatch")
                print("  • Authentication working but no read permissions")
                print("  • Topic exists but partitions are empty")
                print("  • Watermark configuration preventing data from being read")
                
                # For streaming queries, suggest checking the Flink job
                if is_query_result and job_id != 'N/A':
                    print(f"  • Check Flink job status: {job_id}")
                    print("  • The streaming job may still be starting up")
                    print("  • Consider increasing the query timeout or checking job metrics")
                
                print("=" * 60)
                print()
                return
            
            if not actual_data_rows:
                print("❌ No INSERT data rows found.")
                print("Raw data structure received:")
                for i, row in enumerate(data_rows[:3]):  # Show first 3 rows for debugging
                    print(f"  Row {i+1}: kind='{row.get('kind', 'UNKNOWN')}', fields={len(row.get('fields', []))}")
                print("=" * 60)
                print()
                return

            if columns and actual_data_rows:
                # Print column headers
                headers = [col.get('name', f'col_{i}') for i, col in enumerate(columns)]
                col_widths = [max(20, len(header)) for header in headers]
                
                # Print header row
                header_row = " | ".join(header.ljust(width) for header, width in zip(headers, col_widths))
                print(header_row)
                print("-" * len(header_row))
                
                # Print data rows
                for row_data in actual_data_rows:
                    fields = row_data.get('fields', [])
                    # Format each cell and pad to column width
                    formatted_cells = []
                    for i, cell in enumerate(fields):
                        cell_str = str(cell) if cell is not None else 'NULL'
                        width = col_widths[i] if i < len(col_widths) else 20
                        formatted_cells.append(cell_str.ljust(width))
                    print(" | ".join(formatted_cells))
                
                print()
                print(f"✅ Displayed {data_rows_count} data rows")
            else:
                # Fallback: print raw data
                print("Raw result data:")
                for row in data_rows[:5]:  # Show first 5 rows for debugging
                    print(f"  {row}")
            
            print("=" * 60)
            print()
            
        except Exception as e:
            self.logger.debug(f"Error printing results: {e}")
            # Print raw results as fallback
            print(f"\n📊 Raw results for {statement_name}:")
            print(json.dumps(result_data, indent=2))


def setup_logging(log_level: str, log_file: Optional[str] = None):
    """Setup logging configuration"""
    log_format = "%(asctime)s - %(levelname)s - %(message)s"
    
    # Configure root logger
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format=log_format,
        handlers=[]
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
                "max_wait_time": 60
            },
            "logging": {
                "level": "INFO",
                "format": "%(asctime)s - %(levelname)s - %(message)s"
            },
            "execution": {
                "continue_on_error": True
            },
            "connection": {
                "timeout": 30,
                "retry_count": 3,
                "retry_delay": 5
            }
        }
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
            return config if config else {}
    except Exception as e:
        print(f"Warning: Could not load config file {config_path}: {e}")
        return {}


def format_sql_error(error_message: str, debug_mode: bool = False) -> str:
    """Format SQL error message for better readability"""
    if not error_message:
        return "Unknown error occurred"
    
    # Look for SQL parse errors specifically - they can be deeply nested
    if "SQL parse failed" in error_message or "SqlParseException" in error_message:
        # Extract the SQL parse error line
        lines = error_message.split('\n')
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
            elif line.startswith("Encountered") and ("at line" in line or "column" in line):
                parse_error_line = f"SQL parse failed. {line}"
                break
        
        if parse_error_line:
            if debug_mode:
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
│ Suggestion: Check your SQL syntax and ensure all identifiers are properly quoted
╰───────────────────────────────────────────────────────────────────────────╯"""
            else:
                return f"❌ {parse_error_line}"
    
    # Look for table not found errors
    if "Table" in error_message and "not found" in error_message:
        lines = error_message.split('\n')
        for line in lines:
            if "not found" in line.lower() and "Table" in line:
                if debug_mode:
                    return f"""
╭─ Table Not Found Error ───────────────────────────────────────────────────╮
│ {line.strip()}
│ 
│ This usually means:
│ • Table doesn't exist in the catalog
│ • Incorrect table name or schema
│ • Table not registered in Flink
│ 
│ Suggestion: Check available tables with 'SHOW TABLES;'
╰───────────────────────────────────────────────────────────────────────────╯"""
                else:
                    return f"❌ {line.strip()}"
    
    # For other errors, try to extract the most relevant line
    lines = error_message.split('\n')
    relevant_lines = []
    
    for line in lines:
        line = line.strip()
        if line and not line.startswith('at ') and not line.startswith('Caused by:'):
            # Look for lines that contain error information
            if any(keyword in line.lower() for keyword in ['error', 'failed', 'exception', 'invalid']) and len(line) < 200:
                relevant_lines.append(line)
    
    if relevant_lines:
        main_error = relevant_lines[0]
        if debug_mode:
            debug_info = '\n'.join(lines[:15])  # First 15 lines for context
            return f"""
╭─ SQL Execution Error ─────────────────────────────────────────────────────╮
│ {main_error}
│ 
│ Full error details:
│ {debug_info}
╰───────────────────────────────────────────────────────────────────────────╯"""
        else:
            return f"❌ {main_error}"
    
    # Fallback: return first non-empty line
    for line in lines:
        line = line.strip()
        if line and len(line) > 10:  # Skip very short lines
            return f"❌ {line}" if not debug_mode else f"""
╭─ Error Details ───────────────────────────────────────────────────────────╮
│ {line}
│ 
│ Full error message:
│ {error_message[:500]}{'...' if len(error_message) > 500 else ''}
╰───────────────────────────────────────────────────────────────────────────╯"""
    
    return f"❌ {error_message[:100]}{'...' if len(error_message) > 100 else ''}"


def main():
    # First, create a parser to check if a custom config file is specified
    pre_parser = argparse.ArgumentParser(add_help=False)
    pre_parser.add_argument("--config", default="config.yaml")
    pre_args, _ = pre_parser.parse_known_args()
    
    # Load configuration using the specified config file
    config = load_config(pre_args.config)
    
    # Extract default values from config
    default_sql_gateway_url = config.get("sql_gateway", {}).get("url", "http://localhost:8083")
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
        """
    )
    
    parser.add_argument(
        "--file", "-f",
        help="Path to SQL file to execute"
    )
    
    parser.add_argument(
        "--sql", "-s",
        help="Inline SQL query to execute"
    )
    
    parser.add_argument(
        "--sql-gateway-url",
        default=default_sql_gateway_url,
        help=f"Flink SQL Gateway URL (default: {default_sql_gateway_url})"
    )
    
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be executed without running SQL statements"
    )
    
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug mode with detailed error information"
    )
    
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default=default_log_level,
        help=f"Logging level (default: {default_log_level})"
    )
    
    parser.add_argument(
        "--log-file",
        help="Log file path (optional)"
    )
    
    parser.add_argument(
        "--continue-on-error",
        action="store_true",
        default=True,
        help="Continue executing remaining statements when one fails (default: True)"
    )
    
    parser.add_argument(
        "--stop-on-error",
        action="store_true",
        help="Stop execution on first error (overrides --continue-on-error)"
    )
    
    parser.add_argument(
        "--single-statement",
        action="store_true",
        help="Treat input as a single statement (don't parse multiple statements)"
    )
    
    parser.add_argument(
        "--config",
        default="config.yaml",
        help="Configuration file path (default: config.yaml)"
    )
    
    args = parser.parse_args()
    
    # Process error handling arguments
    continue_on_error = args.continue_on_error
    if args.stop_on_error:
        continue_on_error = False
    
    # Setup logging
    setup_logging(args.log_level, args.log_file)
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
        
        if args.sql:
            # Execute inline SQL
            logger.info("Executing inline SQL query")
            executor = FlinkSQLExecutor(args.sql_gateway_url)
            
            if not args.dry_run:
                if not executor.create_session():
                    logger.error("Failed to create SQL Gateway session")
                    sys.exit(1)
            
            try:
                if args.dry_run:
                    # Show what would be executed
                    if args.single_statement:
                        logger.info(f"DRY RUN: Would execute single SQL statement: {args.sql}")
                    else:
                        statements = executor.parse_sql_statements(args.sql)
                        logger.info(f"DRY RUN: Would execute {len(statements)} SQL statement(s)")
                        for i, stmt in enumerate(statements, 1):
                            logger.info(f"  Statement {i}: {stmt[:100]}{'...' if len(stmt) > 100 else ''}")
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    if args.single_statement:
                        # Execute as single statement
                        success, result = executor.execute_statement(args.sql, "inline-query")
                        if success:
                            logger.info("🎉 Inline SQL executed successfully!")
                        else:
                            logger.error("💥 Inline SQL execution failed!")
                            if "error" in result:
                                formatted_error = format_sql_error(result['error'], args.debug)
                                logger.error(formatted_error)
                            sys.exit(1)
                    else:
                        # Execute as multiple statements
                        success, results = executor.execute_multiple_statements(
                            args.sql, 
                            "inline-query", 
                            continue_on_error
                        )
                        
                        if success:
                            logger.info("🎉 All inline SQL statements executed successfully!")
                        else:
                            logger.error("💥 Some inline SQL statements failed!")
                            
                            # Show detailed error information
                            failed_statements = [r for r in results if not r.get('success', True)]
                            for failed in failed_statements:
                                stmt_num = failed.get('statement_number', '?')
                                error_msg = failed.get('error', 'Unknown error')
                                formatted_error = format_sql_error(error_msg, args.debug)
                                logger.error(f"Statement {stmt_num} error: {formatted_error}")
                            
                            sys.exit(1)
            finally:
                if not args.dry_run:
                    executor.close_session()
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
                # Read SQL content from file
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        sql_content = f.read().strip()
                    
                    if not sql_content:
                        logger.error(f"Empty SQL file: {file_path}")
                        sys.exit(1)
                        
                except Exception as e:
                    logger.error(f"Error reading SQL file {file_path}: {e}")
                    sys.exit(1)
                
                if args.dry_run:
                    # Show what would be executed
                    if args.single_statement:
                        logger.info(f"DRY RUN: Would execute SQL from {file_path} as single statement")
                        logger.info(f"SQL content ({len(sql_content)} characters):")
                        logger.info(f"{sql_content[:500]}{'...' if len(sql_content) > 500 else ''}")
                    else:
                        statements = executor.parse_sql_statements(sql_content)
                        logger.info(f"DRY RUN: Would execute {len(statements)} SQL statement(s) from {file_path}")
                        for i, stmt in enumerate(statements, 1):
                            logger.info(f"  Statement {i}: {stmt[:100]}{'...' if len(stmt) > 100 else ''}")
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    if args.single_statement:
                        # Execute as single statement
                        success, result = executor.execute_statement(sql_content, file_path.name)
                        if success:
                            logger.info(f"🎉 SQL file {file_path.name} executed successfully!")
                        else:
                            logger.error(f"💥 SQL file {file_path.name} execution failed!")
                            if "error" in result:
                                formatted_error = format_sql_error(result['error'], args.debug)
                                logger.error(formatted_error)
                            sys.exit(1)
                    else:
                        # Execute as multiple statements
                        success, results = executor.execute_multiple_statements(
                            sql_content, 
                            file_path.name, 
                            continue_on_error
                        )
                        
                        if success:
                            logger.info(f"🎉 All statements in {file_path.name} executed successfully!")
                        else:
                            logger.error(f"💥 Some statements in {file_path.name} failed!")
                            
                            # Show detailed error information
                            failed_statements = [r for r in results if not r.get('success', True)]
                            for failed in failed_statements:
                                stmt_num = failed.get('statement_number', '?')
                                error_msg = failed.get('error', 'Unknown error')
                                formatted_error = format_sql_error(error_msg, args.debug)
                                logger.error(f"Statement {stmt_num} error: {formatted_error}")
                            
                            sys.exit(1)
            finally:
                if not args.dry_run:
                    executor.close_session()
        
        sys.exit(0)
            
    except KeyboardInterrupt:
        logger.info("Execution interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
