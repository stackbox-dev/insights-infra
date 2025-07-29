#!/usr/bin/env python3
"""
Flink Dependency Management System

This script manages dependencies for Flink Docker images, providing:
- Dependency version checking and updates
- Compatibility validation against Flink versions
- Backup and restore functionality
- Integration with Maven repositories
- Comprehensive reporting
"""

import json
import os
import sys
import argparse
import requests
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import re
import shutil
from urllib.parse import urljoin
import hashlib
import time
import logging
from packaging import version as pkg_version


class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color


class Logger:
    """Custom logger with colored output"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        
    def info(self, message: str):
        print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")
        
    def success(self, message: str):
        print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")
        
    def warning(self, message: str):
        print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {message}")
        
    def error(self, message: str):
        print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")
        
    def debug(self, message: str):
        if self.verbose:
            print(f"{Colors.BLUE}[DEBUG]{Colors.NC} {message}")


class CompatibilityMatrix:
    """Manages compatibility rules for Flink dependencies"""
    
    def __init__(self, logger: Logger = None):
        self.logger = logger
        self.rules = {
            'flink-2.0.0': {
                # Kafka ecosystem - based on Kafka broker version 3.8.1
                'kafka': ('3.6.0', '3.8.1'),  # Kafka broker/server libraries must match broker version
                'kafka-clients': ('3.6.0', '3.8.1'),  # Must be compatible with Kafka broker 3.8.1
                'schema-registry': ('7.4.0', '8.99.99'),  # Confluent Schema Registry compatibility (separate versioning)
                
                # Flink connectors - official Flink 2.0.0 versions  
                'flink-connector': ('4.0.0', '4.99.99'),  # Flink 2.0.0 uses 4.0.0-2.0 format
                
                # Avro and schema registry - based on Flink 2.0.0 docs
                'avro': ('1.11.0', '2.99.99'),  # Allow both external Avro and Flink native versions
                'confluent-avro': ('2.0.0', '7.99.99'),  # Allow Flink native and Confluent versions
                'schema-registry': ('7.4.0', '8.99.99'),  # Confluent Schema Registry compatibility
                
                # JSON processing - Jackson versions compatible with Flink 2.0.0
                'jackson': ('2.15.0', '2.18.99'),  # Jackson 2.15+ for Java compatibility
                'jackson-core': ('2.15.0', '2.18.99'),
                'jackson-databind': ('2.15.0', '2.18.99'),
                'jackson-annotations': ('2.15.0', '2.18.99'),
                
                # Scala - Flink 2.0.0 uses Scala 2.12
                'scala': ('2.12.0', '2.12.99'),
                'scala-library': ('2.12.0', '2.12.99'),
                
                # Google libraries - liberal ranges for utility libraries
                'google-guava': ('30.0', '35.99.99'),  # Google Guava broad compatibility
                'google-auth': ('1.0.0', '2.99.99'),   # Google Auth libraries
                'google-cloud': ('1.0.0', '4.99.99'),  # Google Cloud libraries  
                'google-api': ('1.30.0', '3.99.99'),   # Google API client
                'google-http': ('1.40.0', '2.99.99'),  # Google HTTP client
                'gson': ('2.8.0', '2.99.99'),          # Google JSON library
                'jsr305': ('1.0.0', '3.99.99'),        # JSR305 annotations (stable)
                'failureaccess': ('1.0.0', '1.99.99'), # Guava dependency
                'listenablefuture': ('1.0', '9999.99.99'), # Empty jar, version irrelevant
                'protobuf': ('3.19.0', '4.99.99'),     # Protocol Buffers
                'grpc': ('1.50.0', '1.99.99'),         # gRPC broader range
                'perfmark': ('0.25.0', '0.99.99'),     # Performance marking
                
                # Hadoop ecosystem - compatible with Flink 2.0.0
                'hadoop': ('3.3.0', '3.99.99'),
                'hadoop-client': ('3.3.0', '3.99.99'),
                'hadoop-common': ('3.3.0', '3.99.99'),
                
                # Logging - standard logging libraries
                'slf4j': ('1.7.30', '2.99.99'),
                'logback': ('1.2.10', '1.99.99'),
                'log4j': ('2.17.0', '2.99.99'),
                
                # Apache commons - stable utility libraries
                'commons-lang3': ('3.12.0', '3.99.99'),
                'commons-cli': ('1.5.0', '1.99.99'),
                'commons-io': ('2.11.0', '2.99.99'),
                'commons-compress': ('1.20.0', '1.99.99'),
                
                # Compression libraries - broad compatibility
                'snappy': ('1.1.8', '1.99.99'),
                'lz4': ('1.8.0', '1.99.99'),
                'zstd': ('1.5.0', '1.99.99'),
                
                # Netty - network library
                'netty': ('4.1.90', '4.1.99'),
                
                # OpenCensus/Observability - monitoring libraries
                'opencensus': ('0.28.0', '0.99.99'),
                
                # Miscellaneous - stable formats and utilities
                'snakeyaml': ('1.30.0', '2.99.99'),
                'swagger': ('2.2.0', '2.99.99'),
                
                # Other connectors and formats - broad compatibility
                'elasticsearch': ('7.17.0', '8.99.99'),
                'cassandra': ('4.0.0', '5.99.99'),
                'mongodb': ('4.10.0', '6.99.99'),
            }
        }
    
    def is_compatible(self, flink_version: str, dependency_type: str, dep_version: str, dep_name: str = '') -> bool:
        """Check if a dependency version is compatible with Flink version"""
        key = f'flink-{flink_version}'
        
        # Special case handling for specific dependencies
        if dependency_type == 'kafka' and 'schema-registry' in dep_name.lower():
            # Schema registry client has different versioning
            dependency_type = 'schema-registry'
        elif dependency_type == 'kafka' and 'managed-kafka-auth' in dep_name.lower():
            # Google managed Kafka auth handler has its own versioning
            dependency_type = 'google-cloud'
        elif dependency_type == 'jackson' and 'google-http-client' in dep_name.lower():
            # Google HTTP client Jackson integration has different versioning
            dependency_type = 'google-http'
        
        # If no rules defined for this Flink version, be conservative
        if key not in self.rules:
            self.logger.warning(f"No compatibility rules defined for Flink {flink_version}")
            return False
            
        # If no specific rule for this dependency type, check if it's a known type
        if dependency_type not in self.rules[key]:
            if dependency_type == 'unknown':
                # For unknown types, we can't determine compatibility
                return False
            else:
                # For known types without rules, log warning but allow
                return True
            
        min_ver, max_ver = self.rules[key][dependency_type]
        
        try:
            # Handle special version formats
            clean_dep_version = self._clean_version(dep_version)
            clean_min_version = self._clean_version(min_ver)
            clean_max_version = self._clean_version(max_ver)
            
            dep_pkg_version = pkg_version.parse(clean_dep_version)
            min_pkg_version = pkg_version.parse(clean_min_version)
            max_pkg_version = pkg_version.parse(clean_max_version)
            
            is_in_range = min_pkg_version <= dep_pkg_version <= max_pkg_version
            
            if not is_in_range:
                # Log detailed compatibility information
                if hasattr(self, 'logger'):
                    self.logger.debug(f"Version {dep_version} is outside compatible range [{min_ver}, {max_ver}] for {dependency_type}")
            
            return is_in_range
            
        except Exception as e:
            # Version parsing failed - this is a real issue
            if hasattr(self, 'logger'):
                self.logger.warning(f"Failed to parse version {dep_version} for {dependency_type}: {e}")
            return False
    
    def _clean_version(self, version: str) -> str:
        """Clean version string for parsing"""
        # Handle Flink-specific versions like "4.0.0-2.0"
        if '-' in version and version.count('-') == 1:
            parts = version.split('-')
            if len(parts) == 2 and all(c.replace('.', '').isdigit() for c in parts):
                # This looks like a connector version, keep the first part
                return parts[0]
        
        # Handle Maven classifier suffixes like "33.2.1-jre"
        if '-jre' in version:
            return version.replace('-jre', '')
        if '-android' in version:
            return version.replace('-android', '')
        
        # Handle special case for listenablefuture empty jar
        if 'empty-to-avoid-conflict' in version:
            # Extract the version number before the descriptor
            parts = version.split('-')
            if parts and parts[0]:
                return parts[0]
            return '9999.0'  # Default high version for empty jar
        
        return version
    
    def get_compatible_range(self, flink_version: str, dependency_type: str) -> Optional[Tuple[str, str]]:
        """Get the compatible version range for a dependency"""
        key = f'flink-{flink_version}'
        if key in self.rules and dependency_type in self.rules[key]:
            return self.rules[key][dependency_type]
        return None


class MavenRepository:
    """Handles Maven repository interactions"""
    
    def __init__(self, logger: Logger, timeout: int = 30, max_retries: int = 3):
        self.logger = logger
        self.timeout = timeout
        self.max_retries = max_retries
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Flink-Dependency-Manager/1.0'
        })
    
    def get_metadata(self, group_id: str, artifact_id: str, repository: str = None) -> Optional[ET.Element]:
        """Fetch Maven metadata for an artifact"""
        if repository is None:
            repository = "https://repo1.maven.org/maven2"
            
        group_path = group_id.replace('.', '/')
        metadata_url = f"{repository}/{group_path}/{artifact_id}/maven-metadata.xml"
        
        self.logger.debug(f"Fetching metadata from: {metadata_url}")
        
        for attempt in range(self.max_retries):
            try:
                response = self.session.get(metadata_url, timeout=self.timeout)
                response.raise_for_status()
                
                return ET.fromstring(response.content)
                
            except Exception as e:
                self.logger.debug(f"Attempt {attempt + 1} failed for {group_id}:{artifact_id}: {e}")
                if attempt < self.max_retries - 1:
                    time.sleep(1)
                    continue
                    
        self.logger.warning(f"Failed to fetch metadata for {group_id}:{artifact_id}")
        return None
    
    def get_latest_version(self, metadata: ET.Element, include_prereleases: bool = False) -> Optional[str]:
        """Extract latest version from Maven metadata"""
        if metadata is None:
            return None
            
        versions = []
        versioning = metadata.find('versioning')
        if versioning is not None:
            versions_elem = versioning.find('versions')
            if versions_elem is not None:
                for version_elem in versions_elem.findall('version'):
                    if version_elem.text:
                        versions.append(version_elem.text)
        
        if not versions:
            return None
            
        # Filter out snapshots and pre-releases if not wanted
        filtered_versions = []
        for v in versions:
            if 'SNAPSHOT' in v.upper():
                continue
            if not include_prereleases:
                if any(pre in v.upper() for pre in ['ALPHA', 'BETA', 'RC', 'M']):
                    continue
            filtered_versions.append(v)
        
        if not filtered_versions:
            return None
            
        # Sort versions and return latest
        try:
            sorted_versions = sorted(filtered_versions, key=pkg_version.parse, reverse=True)
            return sorted_versions[0]
        except Exception:
            # Fallback to simple string sorting
            return sorted(filtered_versions)[-1]


class Dependency:
    """Represents a single dependency"""
    
    def __init__(self, name: str, group_id: str, artifact_id: str, version: str, 
                 description: str = "", repository: str = None):
        self.name = name
        self.group_id = group_id
        self.artifact_id = artifact_id
        self.version = version
        self.description = description
        self.repository = repository or "https://repo1.maven.org/maven2"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        result = {
            'groupId': self.group_id,
            'artifactId': self.artifact_id,
            'version': self.version,
            'description': self.description
        }
        if self.repository != "https://repo1.maven.org/maven2":
            result['repository'] = self.repository
        return result
    
    @classmethod
    def from_dict(cls, name: str, data: Dict[str, Any]) -> 'Dependency':
        """Create from dictionary"""
        return cls(
            name=name,
            group_id=data['groupId'],
            artifact_id=data['artifactId'],
            version=data['version'],
            description=data.get('description', ''),
            repository=data.get('repository')
        )
    
    def get_dependency_type(self) -> str:
        """Determine dependency type for compatibility checking using groupId and artifactId"""
        name_lower = self.name.lower()
        group_lower = self.group_id.lower()
        artifact_lower = self.artifact_id.lower()
        
        # Flink native connectors
        if (group_lower == 'org.apache.flink' and 
            ('connector' in artifact_lower or 'sql-connector' in artifact_lower)):
            return 'flink-connector'
        
        # Kafka ecosystem
        if ('kafka' in name_lower or 'kafka' in artifact_lower or 
            group_lower == 'org.apache.kafka'):
            if 'clients' in artifact_lower:
                return 'kafka-clients'
            elif artifact_lower.startswith('kafka_2.'):
                # This is the Kafka broker/server library (e.g., kafka_2.12, kafka_2.13)
                return 'kafka'
            return 'kafka'
        
        # Avro and schema registry
        if ('avro' in name_lower or 'avro' in artifact_lower):
            if 'confluent' in name_lower or 'confluent' in artifact_lower:
                return 'confluent-avro'
            return 'avro'
        
        if 'schema-registry' in name_lower or 'schema-registry' in artifact_lower:
            return 'schema-registry'
        
        # Jackson JSON processing
        if ('jackson' in name_lower or 'jackson' in artifact_lower or 
            group_lower.startswith('com.fasterxml.jackson')):
            if 'core' in artifact_lower:
                return 'jackson-core'
            elif 'databind' in artifact_lower:
                return 'jackson-databind'
            elif 'annotations' in artifact_lower:
                return 'jackson-annotations'
            return 'jackson'
        
        # Scala
        if ('scala' in name_lower or 'scala' in artifact_lower or 
            group_lower.startswith('org.scala-lang')):
            if 'library' in artifact_lower:
                return 'scala-library'
            return 'scala'
        
        # Google libraries
        if group_lower.startswith('com.google'):
            if 'guava' in artifact_lower:
                return 'google-guava'
            elif 'auth' in artifact_lower:
                return 'google-auth'
            elif 'cloud' in artifact_lower:
                return 'google-cloud'
            elif 'api' in artifact_lower:
                return 'google-api'
            elif 'http' in artifact_lower:
                return 'google-http'
            elif 'gson' in artifact_lower:
                return 'gson'
            elif 'failureaccess' in artifact_lower:
                return 'failureaccess'
            elif 'listenablefuture' in artifact_lower:
                return 'listenablefuture'
            elif 'protobuf' in artifact_lower:
                return 'protobuf'
        
        # JSR305 annotations
        if 'jsr305' in artifact_lower or group_lower == 'com.google.code.findbugs':
            return 'jsr305'
        
        # gRPC
        if 'grpc' in name_lower or 'grpc' in artifact_lower or group_lower.startswith('io.grpc'):
            return 'grpc'
        
        # Perfmark
        if 'perfmark' in artifact_lower or group_lower.startswith('io.perfmark'):
            return 'perfmark'
        
        # Protobuf
        if 'protobuf' in name_lower or 'protobuf' in artifact_lower:
            return 'protobuf'
        
        # Hadoop ecosystem
        if ('hadoop' in name_lower or 'hadoop' in artifact_lower or 
            group_lower.startswith('org.apache.hadoop')):
            if 'client' in artifact_lower:
                return 'hadoop-client'
            elif 'common' in artifact_lower:
                return 'hadoop-common'
            return 'hadoop'
        
        # Logging
        if 'slf4j' in name_lower or 'slf4j' in artifact_lower:
            return 'slf4j'
        if 'logback' in name_lower or 'logback' in artifact_lower:
            return 'logback'
        if 'log4j' in name_lower or 'log4j' in artifact_lower:
            return 'log4j'
        
        # Apache Commons
        if group_lower.startswith('org.apache.commons'):
            if 'lang3' in artifact_lower:
                return 'commons-lang3'
            elif 'cli' in artifact_lower:
                return 'commons-cli'
            elif 'io' in artifact_lower:
                return 'commons-io'
            elif 'compress' in artifact_lower:
                return 'commons-compress'
        
        # Compression libraries
        if 'snappy' in artifact_lower:
            return 'snappy'
        if 'lz4' in artifact_lower:
            return 'lz4'
        if 'zstd' in artifact_lower:
            return 'zstd'
        
        # Netty
        if 'netty' in name_lower or 'netty' in artifact_lower:
            return 'netty'
        
        # OpenCensus
        if 'opencensus' in artifact_lower or group_lower.startswith('io.opencensus'):
            return 'opencensus'
        
        # Miscellaneous
        if 'snakeyaml' in artifact_lower:
            return 'snakeyaml'
        if 'swagger' in artifact_lower:
            return 'swagger'
        
        # Other connectors
        if 'elasticsearch' in name_lower or 'elasticsearch' in artifact_lower:
            return 'elasticsearch'
        if 'cassandra' in name_lower or 'cassandra' in artifact_lower:
            return 'cassandra'
        if 'mongodb' in name_lower or 'mongodb' in artifact_lower:
            return 'mongodb'
        
        return 'unknown'


class DependencyManager:
    """Main dependency management class"""
    
    def __init__(self, versions_file: str, logger: Logger):
        self.versions_file = Path(versions_file)
        self.logger = logger
        self.maven = MavenRepository(logger)
        self.compatibility = CompatibilityMatrix(logger)
        self.dependencies: Dict[str, Dict[str, Dependency]] = {}
        self.metadata = {}
        
        self._load_dependencies()
    
    def _load_dependencies(self):
        """Load dependencies from JSON file"""
        if not self.versions_file.exists():
            raise FileNotFoundError(f"Versions file not found: {self.versions_file}")
        
        try:
            with open(self.versions_file, 'r') as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in versions file: {e}")
        
        self.metadata = data.get('metadata', {})
        dependencies_data = data.get('dependencies', {})
        
        for category, deps in dependencies_data.items():
            self.dependencies[category] = {}
            for dep_name, dep_data in deps.items():
                self.dependencies[category][dep_name] = Dependency.from_dict(dep_name, dep_data)
    
    def _save_dependencies(self):
        """Save dependencies to JSON file"""
        data = {
            'metadata': self.metadata,
            'dependencies': {}
        }
        
        for category, deps in self.dependencies.items():
            data['dependencies'][category] = {}
            for dep_name, dep in deps.items():
                data['dependencies'][category][dep_name] = dep.to_dict()
        
        # Update last_updated timestamp
        data['metadata']['last_updated'] = datetime.now().strftime('%Y-%m-%d')
        
        with open(self.versions_file, 'w') as f:
            json.dump(data, f, indent=2, sort_keys=True)
    
    def create_backup(self) -> str:
        """Create a backup of the current versions file"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = f"{self.versions_file}.backup.{timestamp}"
        shutil.copy2(self.versions_file, backup_file)
        self.logger.success(f"Backup created: {backup_file}")
        return backup_file
    
    def restore_backup(self, backup_file: str):
        """Restore from a backup file"""
        backup_path = Path(backup_file)
        if not backup_path.exists():
            raise FileNotFoundError(f"Backup file not found: {backup_file}")
        
        # Validate backup file
        try:
            with open(backup_path, 'r') as f:
                json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in backup file: {e}")
        
        shutil.copy2(backup_path, self.versions_file)
        self._load_dependencies()
        self.logger.success(f"Restored from backup: {backup_file}")
    
    def check_updates(self, category: str = None, include_prereleases: bool = False, 
                     exclude: List[str] = None) -> Dict[str, List[Dict[str, Any]]]:
        """Check for available updates"""
        exclude = exclude or []
        categories_to_check = [category] if category else self.dependencies.keys()
        results = {}
        
        flink_version = self.metadata.get('flink_version', '2.0.0')
        
        for cat in categories_to_check:
            if cat not in self.dependencies:
                continue
                
            self.logger.info(f"Checking updates for category: {cat}")
            results[cat] = []
            
            for dep_name, dep in self.dependencies[cat].items():
                if dep_name in exclude:
                    self.logger.debug(f"Skipping excluded dependency: {dep_name}")
                    continue
                
                self.logger.debug(f"Checking dependency: {dep_name}")
                
                # Get latest version
                metadata = self.maven.get_metadata(dep.group_id, dep.artifact_id, dep.repository)
                if metadata is None:
                    continue
                
                # Get dependency type first to check compatibility constraints
                dep_type = dep.get_dependency_type()
                
                # Find the latest compatible version instead of just the absolute latest
                latest_version = self._get_latest_compatible_version(metadata, flink_version, dep_type, dep_name, include_prereleases)
                if latest_version is None:
                    continue
                
                # Compare versions
                try:
                    current_pkg_version = pkg_version.parse(dep.version)
                    latest_pkg_version = pkg_version.parse(latest_version)
                    
                    if latest_pkg_version > current_pkg_version:
                        # Check compatibility (should be True since we filtered for compatible versions)
                        is_compatible = self.compatibility.is_compatible(flink_version, dep_type, latest_version, dep_name)
                        
                        update_info = {
                            'name': dep_name,
                            'current_version': dep.version,
                            'latest_version': latest_version,
                            'compatible': is_compatible,
                            'type': dep_type
                        }
                        results[cat].append(update_info)
                        
                        if is_compatible:
                            self.logger.success(f"  {dep_name}: {dep.version} → {latest_version} (compatible)")
                        else:
                            self.logger.warning(f"  {dep_name}: {dep.version} → {latest_version} (⚠️  compatibility warning)")
                    
                except Exception as e:
                    self.logger.debug(f"Version comparison failed for {dep_name}: {e}")
                    continue
        
        return results
    
    def _get_latest_compatible_version(self, metadata: ET.Element, flink_version: str, 
                                     dep_type: str, dep_name: str, include_prereleases: bool = False) -> Optional[str]:
        """Get the latest version that's compatible with the given Flink version"""
        if metadata is None:
            return None
            
        # Get all available versions
        versions = []
        versioning = metadata.find('versioning')
        if versioning is not None:
            versions_elem = versioning.find('versions')
            if versions_elem is not None:
                for version_elem in versions_elem.findall('version'):
                    if version_elem.text:
                        versions.append(version_elem.text)
        
        if not versions:
            return None
            
        # Filter out snapshots and pre-releases if not wanted
        filtered_versions = []
        for v in versions:
            if 'SNAPSHOT' in v.upper():
                continue
            if not include_prereleases:
                if any(pre in v.upper() for pre in ['ALPHA', 'BETA', 'RC', 'M']):
                    continue
            filtered_versions.append(v)
        
        if not filtered_versions:
            return None
            
        # Sort versions in descending order (latest first)
        try:
            sorted_versions = sorted(filtered_versions, key=pkg_version.parse, reverse=True)
        except Exception:
            # Fallback to simple string sorting
            sorted_versions = sorted(filtered_versions, reverse=True)
        
        # Find the latest version that's compatible
        for version in sorted_versions:
            if self.compatibility.is_compatible(flink_version, dep_type, version, dep_name):
                return version
        
        # If no compatible version found, return None
        return None
    
    def update_dependencies(self, category: str = None, include_prereleases: bool = False,
                          exclude: List[str] = None, force: bool = False, dry_run: bool = False) -> int:
        """Update dependencies"""
        exclude = exclude or []
        
        if dry_run:
            self.logger.info("DRY RUN MODE - No changes will be made")
        
        # Create backup unless dry run
        if not dry_run:
            self.create_backup()
        
        updates = self.check_updates(category, include_prereleases, exclude)
        total_updates = 0
        
        for cat, category_updates in updates.items():
            if not category_updates:
                continue
                
            self.logger.info(f"Processing category: {cat}")
            
            for update_info in category_updates:
                dep_name = update_info['name']
                current_version = update_info['current_version']
                latest_version = update_info['latest_version']
                is_compatible = update_info['compatible']
                
                if is_compatible or force:
                    if dry_run:
                        if is_compatible:
                            self.logger.success(f"[DRY RUN] Would update {cat}/{dep_name}: {current_version} → {latest_version}")
                        else:
                            self.logger.warning(f"[DRY RUN] Would force update {cat}/{dep_name}: {current_version} → {latest_version} (⚠️  compatibility warning)")
                    else:
                        # Perform the update
                        self.dependencies[cat][dep_name].version = latest_version
                        total_updates += 1
                        
                        if is_compatible:
                            self.logger.success(f"Updated {cat}/{dep_name}: {current_version} → {latest_version}")
                        else:
                            self.logger.warning(f"Force updated {cat}/{dep_name}: {current_version} → {latest_version} (⚠️  compatibility warning)")
                else:
                    self.logger.warning(f"Skipping {cat}/{dep_name}: {current_version} → {latest_version} (compatibility warning, use --force to override)")
        
        # Save changes
        if not dry_run and total_updates > 0:
            self._save_dependencies()
            self.logger.success(f"Updated {total_updates} dependencies")
        elif dry_run:
            self.logger.info("Dry run completed - no changes made")
        else:
            self.logger.info("No updates available")
        
        return total_updates
    
    def validate_dependencies(self) -> Tuple[int, int]:
        """Validate current dependencies for compatibility"""
        flink_version = self.metadata.get('flink_version', '2.0.0')
        self.logger.info(f"Validating dependencies for Flink {flink_version} compatibility")
        
        total_deps = 0
        compatible_deps = 0
        unknown_deps = 0
        
        # Track issues by category for detailed reporting
        compatibility_issues = []
        unknown_types = []
        
        for category, deps in self.dependencies.items():
            for dep_name, dep in deps.items():
                total_deps += 1
                dep_type = dep.get_dependency_type()
                
                if dep_type == 'unknown':
                    unknown_deps += 1
                    unknown_types.append({
                        'category': category,
                        'name': dep_name,
                        'groupId': dep.group_id,
                        'artifactId': dep.artifact_id,
                        'version': dep.version
                    })
                    self.logger.warning(f"{category}/{dep_name} has unknown type (groupId: {dep.group_id}, artifactId: {dep.artifact_id})")
                    continue
                
                if self.compatibility.is_compatible(flink_version, dep_type, dep.version, dep_name):
                    compatible_deps += 1
                    self.logger.debug(f"{category}/{dep_name} ({dep.version}) is compatible")
                else:
                    compatibility_issues.append({
                        'category': category,
                        'name': dep_name,
                        'type': dep_type,
                        'version': dep.version,
                        'expected_range': self.compatibility.get_compatible_range(flink_version, dep_type)
                    })
                    self.logger.warning(f"{category}/{dep_name} ({dep.version}) may not be compatible with Flink {flink_version}")
                    
                    # Show expected range if available
                    compat_range = self.compatibility.get_compatible_range(flink_version, dep_type)
                    if compat_range:
                        self.logger.info(f"  Expected range: {compat_range[0]} - {compat_range[1]}")
        
        # Detailed reporting
        incompatible_deps = total_deps - compatible_deps - unknown_deps
        
        self.logger.info("Validation Summary:")
        self.logger.success(f"  Compatible: {compatible_deps}/{total_deps}")
        if incompatible_deps > 0:
            self.logger.warning(f"  Incompatible: {incompatible_deps}/{total_deps}")
        if unknown_deps > 0:
            self.logger.warning(f"  Unknown types: {unknown_deps}/{total_deps}")
        
        # Suggest actions for unknown types
        if unknown_types:
            self.logger.info("Unknown dependency types found. Consider adding compatibility rules for:")
            for dep in unknown_types[:5]:  # Show first 5
                self.logger.info(f"  - {dep['groupId']}:{dep['artifactId']} (used as {dep['name']})")
        
        return compatible_deps, incompatible_deps + unknown_deps
    
    def generate_report(self, output_file: str = None) -> str:
        """Generate a comprehensive compatibility report"""
        flink_version = self.metadata.get('flink_version', '2.0.0')
        
        if output_file is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            output_file = f"dependency-report-{timestamp}.md"
        
        # Gather data
        updates = self.check_updates()
        compatible_deps, incompatible_deps = self.validate_dependencies()
        
        # Generate report
        report_lines = [
            f"# Flink {flink_version} Dependency Report",
            "",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Flink Version: {flink_version}",
            f"Dependencies File: {self.versions_file.name}",
            "",
            "## Summary",
            "",
            f"- Total dependencies: {sum(len(deps) for deps in self.dependencies.values())}",
            f"- Compatible: {compatible_deps}",
            f"- Potential issues: {incompatible_deps}",
            f"- Available updates: {sum(len(cat_updates) for cat_updates in updates.values())}",
            "",
            "## Dependency Analysis",
            ""
        ]
        
        for category, deps in self.dependencies.items():
            report_lines.extend([
                f"### {category}",
                "",
                "| Dependency | Current Version | Latest Available | Status | Compatible |",
                "|------------|-----------------|------------------|--------|------------|"
            ])
            
            category_updates = updates.get(category, [])
            update_dict = {u['name']: u for u in category_updates}
            
            for dep_name, dep in deps.items():
                dep_type = dep.get_dependency_type()
                is_current_compatible = self.compatibility.is_compatible(flink_version, dep_type, dep.version, dep_name)
                
                if dep_name in update_dict:
                    update_info = update_dict[dep_name]
                    latest_version = update_info['latest_version']
                    is_latest_compatible = update_info['compatible']
                    
                    status = "📈 Update Available"
                    compatible_status = "✅" if is_latest_compatible else "⚠️"
                else:
                    latest_version = dep.version
                    status = "✅ Up to date"
                    compatible_status = "✅" if is_current_compatible else "⚠️"
                
                current_compatible = "✅" if is_current_compatible else "⚠️"
                
                report_lines.append(
                    f"| {dep_name} | {dep.version} | {latest_version} | {status} | {current_compatible} → {compatible_status} |"
                )
            
            report_lines.append("")
        
        report_lines.extend([
            "## Recommendations",
            "",
            "1. **Compatible Updates (✅)**: Safe to update",
            "2. **Compatibility Warnings (⚠️)**: Review carefully before updating",
            "3. **Current Issues**: Address incompatible current versions",
            "",
            "## Next Steps",
            "",
            f"1. Run `python {Path(__file__).name} update --dry-run` to preview updates",
            f"2. Run `python {Path(__file__).name} update` to apply safe updates",
            "3. Test thoroughly before deploying to production",
            ""
        ])
        
        # Write report
        report_content = "\n".join(report_lines)
        with open(output_file, 'w') as f:
            f.write(report_content)
        
        self.logger.success(f"Report generated: {output_file}")
        return output_file
    
    def get_status(self) -> Dict[str, Any]:
        """Get current status summary"""
        flink_version = self.metadata.get('flink_version', '2.0.0')
        last_updated = self.metadata.get('last_updated', 'unknown')
        
        total_deps = sum(len(deps) for deps in self.dependencies.values())
        updates = self.check_updates()
        available_updates = sum(len(cat_updates) for cat_updates in updates.values())
        compatible_deps, incompatible_deps = self.validate_dependencies()
        
        return {
            'flink_version': flink_version,
            'last_updated': last_updated,
            'total_dependencies': total_deps,
            'categories': len(self.dependencies),
            'available_updates': available_updates,
            'compatible_dependencies': compatible_deps,
            'incompatible_dependencies': incompatible_deps,
            'versions_file': str(self.versions_file)
        }


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Flink Dependency Management System",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s status                      # Show current status
  %(prog)s check                       # Check for updates
  %(prog)s update --dry-run            # Preview updates
  %(prog)s update                      # Apply updates
  %(prog)s update --category kafka     # Update specific category
  %(prog)s validate                    # Validate compatibility
  %(prog)s backup                      # Create backup
  %(prog)s restore backup.json         # Restore from backup
  %(prog)s report                      # Generate report
        """
    )
    
    # Commands
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Show current dependency status')
    status_parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    # Check command
    check_parser = subparsers.add_parser('check', help='Check for available updates')
    check_parser.add_argument('--category', '-c', help='Check specific category only')
    check_parser.add_argument('--include-prereleases', action='store_true', help='Include pre-release versions')
    check_parser.add_argument('--exclude', help='Comma-separated list of dependencies to exclude')
    check_parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    # Update command
    update_parser = subparsers.add_parser('update', help='Update dependencies')
    update_parser.add_argument('--category', '-c', help='Update specific category only')
    update_parser.add_argument('--include-prereleases', action='store_true', help='Include pre-release versions')
    update_parser.add_argument('--exclude', help='Comma-separated list of dependencies to exclude')
    update_parser.add_argument('--force', '-f', action='store_true', help='Force update even with compatibility warnings')
    update_parser.add_argument('--dry-run', '-n', action='store_true', help='Show what would be updated without making changes')
    update_parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate current dependency versions')
    validate_parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    # Backup command
    backup_parser = subparsers.add_parser('backup', help='Create backup of versions file')
    backup_parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    # Restore command
    restore_parser = subparsers.add_parser('restore', help='Restore from backup file')
    restore_parser.add_argument('backup_file', help='Backup file to restore from')
    restore_parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    # Report command
    report_parser = subparsers.add_parser('report', help='Generate comprehensive report')
    report_parser.add_argument('--output', '-o', help='Output file name')
    report_parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose output')
    
    # Global options
    parser.add_argument('--versions-file', default='dependency-versions.json', 
                       help='Path to versions file (default: dependency-versions.json)')
    
    args = parser.parse_args()
    
    # Default to status if no command provided
    if args.command is None:
        args.command = 'status'
        args.verbose = False
    
    # Setup logger
    verbose = getattr(args, 'verbose', False)
    logger = Logger(verbose=verbose)
    
    try:
        # Initialize dependency manager
        manager = DependencyManager(args.versions_file, logger)
        
        # Execute command
        if args.command == 'status':
            status = manager.get_status()
            
            print(f"{Colors.CYAN}╔══════════════════════════════════════════════════════════════════════════════╗{Colors.NC}")
            print(f"{Colors.CYAN}║                    Flink Dependency Management Status                        ║{Colors.NC}")
            print(f"{Colors.CYAN}╚══════════════════════════════════════════════════════════════════════════════╝{Colors.NC}")
            print()
            
            logger.info("Configuration:")
            print(f"  Versions file: {status['versions_file']}")
            print(f"  Flink version: {status['flink_version']}")
            print(f"  Last updated: {status['last_updated']}")
            print()
            
            logger.info("Dependencies:")
            print(f"  Total: {status['total_dependencies']} dependencies across {status['categories']} categories")
            print(f"  Available updates: {status['available_updates']}")
            print(f"  Compatible: {status['compatible_dependencies']}")
            if status['incompatible_dependencies'] > 0:
                print(f"  Potential issues: {status['incompatible_dependencies']}")
            
        elif args.command == 'check':
            exclude_list = args.exclude.split(',') if args.exclude else []
            updates = manager.check_updates(
                category=args.category,
                include_prereleases=args.include_prereleases,
                exclude=exclude_list
            )
            
            total_updates = sum(len(cat_updates) for cat_updates in updates.values())
            if total_updates == 0:
                logger.success("All dependencies are up to date")
            else:
                logger.info(f"Found {total_updates} available updates")
        
        elif args.command == 'update':
            exclude_list = args.exclude.split(',') if args.exclude else []
            updated_count = manager.update_dependencies(
                category=args.category,
                include_prereleases=args.include_prereleases,
                exclude=exclude_list,
                force=args.force,
                dry_run=args.dry_run
            )
            
            if not args.dry_run and updated_count > 0:
                logger.info("Run 'validate' command to check compatibility after updates")
        
        elif args.command == 'validate':
            compatible, incompatible = manager.validate_dependencies()
            sys.exit(0 if incompatible == 0 else 1)
        
        elif args.command == 'backup':
            manager.create_backup()
        
        elif args.command == 'restore':
            manager.restore_backup(args.backup_file)
        
        elif args.command == 'report':
            manager.generate_report(args.output)
        
    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error: {e}")
        if verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
