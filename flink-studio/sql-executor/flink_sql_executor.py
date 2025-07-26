#!/usr/bin/env python3
"""
Flink SQL Executor

This script executes SQL files or inline queries against the Flink SQL Gateway 
with comprehensive status checking and error reporting.

Features:
- Executes SQL from individual files or inline queries
- Provides detailed status monitoring and error reporting
- Supports configuration via command line arguments
- Handles Flink SQL Gateway session management
- Comprehensive logging and debug information

Usage:
    python flink_sql_executor.py --file /path/to/my_query.sql
    python flink_sql_executor.py --sql "SELECT * FROM my_table LIMIT 10"
    python flink_sql_executor.py --file /path/to/my_query.sql --sql-gateway-url http://localhost:8083
"""

import argparse
import json
import logging
import os
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
                    
                    self.logger.info(f"✓ {statement_name or 'Statement'} completed successfully ({duration:.1f}s)")
                    
                    # Print results if available
                    if result_data and result_data.get('results', {}).get('data'):
                        self._print_query_results(result_data, statement_name)
                    
                    return True, {
                        "status": status,
                        "duration": duration,
                        "polls": poll_count,
                        "result": result_data
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
    
    def _fetch_operation_result(self, operation_handle: str) -> Optional[Dict]:
        """Fetch the result data from a completed operation"""
        try:
            url = f"{self.sql_gateway_url}/v1/sessions/{self.session_handle}/operations/{operation_handle}/result/0"
            response = requests.get(url, timeout=10)
            
            if response.status_code != 200:
                self.logger.debug(f"No result data available: {response.status_code}")
                return None
            
            result_data = response.json()
            self.logger.debug(f"Result data keys: {list(result_data.keys())}")
            self.logger.debug(f"Result data structure: {json.dumps(result_data, indent=2)[:500]}...")
            
            return result_data
            
        except requests.RequestException as e:
            self.logger.debug(f"Error fetching result: {e}")
            return None
    
    def _print_query_results(self, result_data: Dict, statement_name: str):
        """Print formatted query results"""
        try:
            # Check if there are results to display
            results = result_data.get('results', {})
            if not results or not results.get('data'):
                return
            
            print(f"\n📊 Results for {statement_name}:")
            print("=" * 60)
            
            # Get column information
            columns = results.get('columns', [])
            data_rows = results.get('data', [])
            
            if columns and data_rows:
                # Print column headers
                headers = [col.get('name', f'col_{i}') for i, col in enumerate(columns)]
                col_widths = [max(20, len(header)) for header in headers]
                
                # Print header row
                header_row = " | ".join(header.ljust(width) for header, width in zip(headers, col_widths))
                print(header_row)
                print("-" * len(header_row))
                
                # Print data rows
                for row_data in data_rows:
                    if row_data.get('kind') == 'INSERT':
                        fields = row_data.get('fields', [])
                        # Format each cell and pad to column width
                        formatted_cells = []
                        for i, cell in enumerate(fields):
                            cell_str = str(cell) if cell is not None else 'NULL'
                            width = col_widths[i] if i < len(col_widths) else 20
                            formatted_cells.append(cell_str.ljust(width))
                        print(" | ".join(formatted_cells))
            else:
                # Fallback: print raw data
                print("Raw result data:")
                for row in data_rows:
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
    # Execute SQL from a specific file
    python flink_sql_executor.py --file /path/to/my_query.sql
    
    # Execute inline SQL query
    python flink_sql_executor.py --sql "SELECT * FROM my_table LIMIT 10"
    
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
        "--config",
        default="config.yaml",
        help="Configuration file path (default: config.yaml)"
    )
    
    args = parser.parse_args()
    
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
                    logger.info(f"DRY RUN: Would execute SQL: {args.sql}")
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    success, result = executor.execute_statement(args.sql, "inline-query")
                    if success:
                        logger.info("🎉 Inline SQL executed successfully!")
                    else:
                        logger.error("💥 Inline SQL execution failed!")
                        if "error" in result:
                            formatted_error = format_sql_error(result['error'], args.debug)
                            logger.error(formatted_error)
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
                    logger.info(f"DRY RUN: Would execute SQL from {file_path}")
                    logger.info(f"SQL content ({len(sql_content)} characters):")
                    logger.info(f"{sql_content[:500]}{'...' if len(sql_content) > 500 else ''}")
                    logger.info("🎉 Dry run completed successfully!")
                else:
                    success, result = executor.execute_statement(sql_content, file_path.name)
                    if success:
                        logger.info(f"🎉 SQL file {file_path.name} executed successfully!")
                    else:
                        logger.error(f"💥 SQL file {file_path.name} execution failed!")
                        if "error" in result:
                            formatted_error = format_sql_error(result['error'], args.debug)
                            logger.error(formatted_error)
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
