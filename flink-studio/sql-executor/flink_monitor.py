#!/usr/bin/env python3
"""
Flink Cluster Monitoring Tool

Monitor Apache Flink jobs for exceptions, health status, and performance metrics.
Uses the same configuration as flink_sql_executor.py
"""

import argparse
import json
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import requests
import yaml
from tabulate import tabulate


class FlinkMonitor:
    """Monitor Flink cluster and jobs"""

    def __init__(self, config_file: str = "config.yaml"):
        """Initialize monitor with configuration"""
        self.config = self.load_config(config_file)
        self.flink_url = self.config.get("flink_cluster", {}).get("url")
        
        if not self.flink_url:
            raise ValueError(
                "Flink cluster URL not found in config. "
                "Please configure flink_cluster.url in config.yaml"
            )
        
        # Remove any trailing slash and port if incorrectly specified
        self.flink_url = self.flink_url.rstrip("/")
        if ":8081" in self.flink_url:
            self.flink_url = self.flink_url.replace(":8081", "")
        
        self.session = requests.Session()
        self.session.headers.update({"Accept": "application/json"})

    def load_config(self, config_file: str) -> Dict:
        """Load configuration from YAML file"""
        config_path = Path(config_file)
        
        if not config_path.exists():
            print(f"Warning: Config file {config_path} not found, using defaults")
            return {}
        
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                config = yaml.safe_load(f)
                return config if config else {}
        except Exception as e:
            print(f"Warning: Could not load config file {config_path}: {e}")
            return {}

    def get_jobs_overview(self) -> List[Dict]:
        """Get overview of all jobs"""
        try:
            response = self.session.get(f"{self.flink_url}/jobs/overview")
            response.raise_for_status()
            data = response.json()
            return data.get("jobs", [])
        except requests.exceptions.RequestException as e:
            print(f"Error fetching jobs overview: {e}")
            return []

    def get_job_details(self, job_id: str) -> Optional[Dict]:
        """Get detailed information about a specific job"""
        try:
            response = self.session.get(f"{self.flink_url}/jobs/{job_id}")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching job {job_id} details: {e}")
            return None

    def get_job_exceptions(self, job_id: str) -> List[Dict]:
        """Get exceptions for a specific job"""
        try:
            response = self.session.get(f"{self.flink_url}/jobs/{job_id}/exceptions")
            response.raise_for_status()
            data = response.json()
            return data.get("exceptionHistory", {}).get("entries", [])
        except requests.exceptions.RequestException as e:
            print(f"Error fetching exceptions for job {job_id}: {e}")
            return []

    def get_job_checkpoints(self, job_id: str) -> Optional[Dict]:
        """Get checkpoint statistics for a job"""
        try:
            response = self.session.get(f"{self.flink_url}/jobs/{job_id}/checkpoints")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching checkpoints for job {job_id}: {e}")
            return None

    def get_cluster_overview(self) -> Optional[Dict]:
        """Get cluster overview including task managers"""
        try:
            response = self.session.get(f"{self.flink_url}/overview")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching cluster overview: {e}")
            return None

    def check_exceptions(self, threshold: int = 5) -> List[Tuple[Dict, List[Dict]]]:
        """Check all running jobs for exceptions exceeding threshold"""
        jobs = self.get_jobs_overview()
        problematic_jobs = []
        
        for job in jobs:
            if job.get("state") in ["RUNNING", "RESTARTING"]:
                exceptions = self.get_job_exceptions(job["jid"])
                if len(exceptions) > threshold:
                    problematic_jobs.append((job, exceptions))
        
        return problematic_jobs

    def format_duration(self, milliseconds: int) -> str:
        """Format duration from milliseconds to human-readable string"""
        if milliseconds < 0:
            return "N/A"
        
        duration = timedelta(milliseconds=milliseconds)
        days = duration.days
        hours, remainder = divmod(duration.seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        
        if days > 0:
            return f"{days}d {hours}h {minutes}m"
        elif hours > 0:
            return f"{hours}h {minutes}m {seconds}s"
        else:
            return f"{minutes}m {seconds}s"

    def format_timestamp(self, timestamp: int) -> str:
        """Format timestamp to human-readable string"""
        if timestamp <= 0:
            return "N/A"
        
        dt = datetime.fromtimestamp(timestamp / 1000)
        return dt.strftime("%Y-%m-%d %H:%M:%S")

    def print_exceptions_report(self, threshold: int = 5):
        """Print report of jobs with exceptions"""
        print(f"\n🔍 Checking for jobs with more than {threshold} exceptions...")
        
        problematic_jobs = self.check_exceptions(threshold)
        
        if not problematic_jobs:
            print(f"✅ No jobs found with more than {threshold} exceptions\n")
            return
        
        print(f"\n⚠️  Found {len(problematic_jobs)} job(s) with exceptions:\n")
        
        for job, exceptions in problematic_jobs:
            print(f"Job: {job['name']}")
            print(f"  ID: {job['jid']}")
            print(f"  State: {job['state']}")
            print(f"  Exception Count: {len(exceptions)}")
            
            # Show recent exceptions
            recent_exceptions = exceptions[:3]  # Show only first 3
            for i, exc in enumerate(recent_exceptions, 1):
                timestamp = self.format_timestamp(exc.get("timestamp", 0))
                print(f"\n  Exception {i} ({timestamp}):")
                
                # Get stacktrace if available
                stacktrace = exc.get("stacktrace")
                if stacktrace:
                    lines = stacktrace.split("\n")[:5]  # First 5 lines
                    for line in lines:
                        print(f"    {line[:100]}")  # Limit line length
                
            if len(exceptions) > 3:
                print(f"\n  ... and {len(exceptions) - 3} more exceptions")
            
            print("-" * 80)

    def print_health_report(self):
        """Print overall cluster health report"""
        print("\n📊 Flink Cluster Health Report")
        print("=" * 80)
        
        # Cluster overview
        cluster = self.get_cluster_overview()
        if cluster:
            print(f"\n🖥️  Cluster Status:")
            print(f"  Flink Version: {cluster.get('flink-version', 'Unknown')}")
            print(f"  Task Managers: {cluster.get('taskmanagers', 0)}")
            print(f"  Total Slots: {cluster.get('slots-total', 0)}")
            print(f"  Available Slots: {cluster.get('slots-available', 0)}")
            print(f"  Jobs Running: {cluster.get('jobs-running', 0)}")
            print(f"  Jobs Finished: {cluster.get('jobs-finished', 0)}")
            print(f"  Jobs Cancelled: {cluster.get('jobs-cancelled', 0)}")
            print(f"  Jobs Failed: {cluster.get('jobs-failed', 0)}")
        
        # Jobs overview
        jobs = self.get_jobs_overview()
        if jobs:
            print(f"\n📋 Jobs Overview ({len(jobs)} total):")
            
            # Group by state
            states = {}
            for job in jobs:
                state = job.get("state", "UNKNOWN")
                states[state] = states.get(state, 0) + 1
            
            for state, count in sorted(states.items()):
                status_icon = "✅" if state == "RUNNING" else "⚠️" if state in ["RESTARTING", "CREATED"] else "❌"
                print(f"  {status_icon} {state}: {count}")
            
            # Show running jobs details
            running_jobs = [j for j in jobs if j.get("state") == "RUNNING"]
            if running_jobs:
                print(f"\n🏃 Running Jobs:")
                
                table_data = []
                for job in running_jobs[:10]:  # Limit to 10 jobs
                    job_details = self.get_job_details(job["jid"])
                    checkpoints = self.get_job_checkpoints(job["jid"])
                    exceptions = self.get_job_exceptions(job["jid"])
                    
                    duration = self.format_duration(job.get("duration", 0))
                    
                    # Get checkpoint info
                    checkpoint_status = "N/A"
                    if checkpoints and checkpoints.get("latest"):
                        latest = checkpoints["latest"]
                        if latest.get("completed"):
                            checkpoint_status = "✅"
                        elif latest.get("failed"):
                            checkpoint_status = "❌"
                        else:
                            checkpoint_status = "⏳"
                    
                    # Get restart count if available
                    restart_count = "0"
                    if job_details:
                        # Try to get from job details
                        restart_count = str(job_details.get("status-counts", {}).get("RESTARTING", 0))
                    
                    table_data.append([
                        job["name"][:40],  # Truncate long names
                        duration,
                        len(exceptions),
                        restart_count,
                        checkpoint_status
                    ])
                
                headers = ["Job Name", "Duration", "Exceptions", "Restarts", "Checkpoint"]
                print(tabulate(table_data, headers=headers, tablefmt="grid"))
                
                if len(running_jobs) > 10:
                    print(f"\n  ... and {len(running_jobs) - 10} more running jobs")

    def print_job_details(self, job_pattern: Optional[str] = None):
        """Print detailed information about specific job(s)"""
        jobs = self.get_jobs_overview()
        
        if job_pattern:
            jobs = [j for j in jobs if job_pattern.lower() in j.get("name", "").lower()]
        
        if not jobs:
            print(f"No jobs found matching pattern: {job_pattern}")
            return
        
        for job in jobs:
            print(f"\n{'=' * 80}")
            print(f"Job: {job['name']}")
            print(f"ID: {job['jid']}")
            print(f"State: {job['state']}")
            print(f"Start Time: {self.format_timestamp(job.get('start-time', 0))}")
            print(f"Duration: {self.format_duration(job.get('duration', 0))}")
            
            # Get detailed info
            details = self.get_job_details(job['jid'])
            if details:
                print(f"Parallelism: {details.get('parallelism', 'N/A')}")
                
                # Status counts
                status_counts = details.get("status-counts", {})
                if status_counts:
                    print("\nTask Status Counts:")
                    for status, count in status_counts.items():
                        print(f"  {status}: {count}")
            
            # Checkpoint info
            checkpoints = self.get_job_checkpoints(job['jid'])
            if checkpoints:
                print("\nCheckpoint Statistics:")
                counts = checkpoints.get("counts", {})
                print(f"  Total: {counts.get('total', 0)}")
                print(f"  In Progress: {counts.get('in_progress', 0)}")
                print(f"  Completed: {counts.get('completed', 0)}")
                print(f"  Failed: {counts.get('failed', 0)}")
                
                latest = checkpoints.get("latest", {})
                if latest.get("completed"):
                    latest_cp = latest["completed"]
                    print(f"\nLatest Checkpoint:")
                    print(f"  ID: {latest_cp.get('id', 'N/A')}")
                    print(f"  Trigger Time: {self.format_timestamp(latest_cp.get('trigger_timestamp', 0))}")
                    print(f"  Duration: {latest_cp.get('duration', 0)}ms")
                    print(f"  State Size: {latest_cp.get('state_size', 0)} bytes")

    def watch_jobs(self, interval: int = 30, threshold: int = 5):
        """Continuously monitor jobs"""
        print(f"👀 Starting continuous monitoring (checking every {interval} seconds)")
        print("Press Ctrl+C to stop\n")
        
        try:
            while True:
                # Clear screen (works on Unix-like systems)
                print("\033[2J\033[H")
                
                print(f"🕐 Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                
                # Check exceptions
                problematic_jobs = self.check_exceptions(threshold)
                if problematic_jobs:
                    print(f"\n⚠️  ALERT: {len(problematic_jobs)} job(s) with >{threshold} exceptions!")
                    for job, exceptions in problematic_jobs:
                        print(f"  - {job['name']}: {len(exceptions)} exceptions")
                else:
                    print(f"\n✅ All jobs healthy (no jobs with >{threshold} exceptions)")
                
                # Show cluster summary
                cluster = self.get_cluster_overview()
                if cluster:
                    print(f"\n📊 Cluster: {cluster.get('taskmanagers', 0)} TMs, "
                          f"{cluster.get('slots-available', 0)}/{cluster.get('slots-total', 0)} slots available, "
                          f"{cluster.get('jobs-running', 0)} jobs running")
                
                # Show running jobs
                jobs = self.get_jobs_overview()
                running_jobs = [j for j in jobs if j.get("state") == "RUNNING"]
                if running_jobs:
                    print(f"\n🏃 Running Jobs ({len(running_jobs)}):")
                    for job in running_jobs[:5]:
                        exceptions = self.get_job_exceptions(job["jid"])
                        exc_indicator = f"⚠️ {len(exceptions)} exc" if exceptions else "✅"
                        print(f"  - {job['name'][:50]}: {self.format_duration(job.get('duration', 0))} {exc_indicator}")
                    
                    if len(running_jobs) > 5:
                        print(f"  ... and {len(running_jobs) - 5} more")
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n\n👋 Monitoring stopped")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Monitor Flink cluster and jobs for exceptions and health status"
    )
    
    parser.add_argument(
        "--config",
        default="config.yaml",
        help="Path to configuration file (default: config.yaml)"
    )
    
    parser.add_argument(
        "--exceptions",
        action="store_true",
        help="Check for jobs with exceptions"
    )
    
    parser.add_argument(
        "--threshold",
        type=int,
        default=5,
        help="Exception count threshold (default: 5)"
    )
    
    parser.add_argument(
        "--health",
        action="store_true",
        help="Show overall cluster health report"
    )
    
    parser.add_argument(
        "--job",
        type=str,
        help="Show details for job(s) matching pattern"
    )
    
    parser.add_argument(
        "--watch",
        action="store_true",
        help="Continuously monitor cluster"
    )
    
    parser.add_argument(
        "--interval",
        type=int,
        default=30,
        help="Watch interval in seconds (default: 30)"
    )
    
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output in JSON format"
    )
    
    args = parser.parse_args()
    
    try:
        monitor = FlinkMonitor(args.config)
        
        if args.watch:
            monitor.watch_jobs(args.interval, args.threshold)
        elif args.exceptions:
            if args.json:
                problematic_jobs = monitor.check_exceptions(args.threshold)
                result = []
                for job, exceptions in problematic_jobs:
                    result.append({
                        "job_id": job["jid"],
                        "job_name": job["name"],
                        "state": job["state"],
                        "exception_count": len(exceptions),
                        "exceptions": exceptions[:5]  # Limit to 5 exceptions in JSON
                    })
                print(json.dumps(result, indent=2))
            else:
                monitor.print_exceptions_report(args.threshold)
        elif args.health:
            monitor.print_health_report()
        elif args.job:
            monitor.print_job_details(args.job)
        else:
            # Default: show both exceptions and health
            monitor.print_exceptions_report(args.threshold)
            monitor.print_health_report()
            
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()