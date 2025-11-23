#!/usr/bin/env node

/**
 * ClickHouse Sink Connector Manager
 *
 * Interactive CLI tool for managing ClickHouse sink connectors
 *
 * Usage:
 *   node manager.js --env <env-file>
 *   npm start -- --env .sbx-uat.env
 *
 * Examples:
 *   node manager.js --env .sbx-uat.env
 *   node manager.js --env .huldc-prod.env
 */

import React from 'react';
import { render } from 'ink';
import fs from 'fs';
import { KafkaConnectClient } from './kafka-connect-client.js';
import { ConnectorManagerUI } from './ui.js';

// Parse command line arguments
const args = process.argv.slice(2);

// Find --env flag
const envFlagIndex = args.indexOf('--env');
if (envFlagIndex === -1 || envFlagIndex === args.length - 1) {
  console.error('ClickHouse Sink Connector Manager');
  console.error('=================================\n');
  console.error('Usage: node manager.js --env <env-file>');
  console.error('\nExamples:');
  console.error('  node manager.js --env .sbx-uat.env');
  console.error('  node manager.js --env .huldc-prod.env');
  console.error('  node manager.js --env .samadhan-prod.env');
  console.error('\nAvailable env files:');
  console.error('  .sbx-uat.env         - SBX UAT environment');
  console.error('  .huldc-prod.env      - HUL DC Production');
  console.error('  .samadhan-prod.env   - Samadhan Production');
  process.exit(1);
}

const envFile = args[envFlagIndex + 1];

// Load environment variables from file into process.env
function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: Environment file '${filePath}' not found`);
    process.exit(1);
  }

  const envContent = fs.readFileSync(filePath, 'utf-8');

  envContent.split('\n').forEach(line => {
    line = line.trim();
    // Skip comments and empty lines
    if (line.startsWith('#') || line === '') return;

    const [key, ...valueParts] = line.split('=');
    if (key && valueParts.length > 0) {
      process.env[key.trim()] = valueParts.join('=').trim();
    }
  });
}

// Validate required environment variables
function validateEnv() {
  const required = [
    'TOPIC_PREFIX',
    'CLICKHOUSE_HOSTNAME',
    'CLICKHOUSE_PORT',
    'CLICKHOUSE_DATABASE',
    'SCHEMA_REGISTRY_URL',
    'CP_CONNECT_URL',
    'CLICKHOUSE_ADMIN_PASSWORD',
    'SCHEMA_REGISTRY_AUTH',
    'CLUSTER_USER_NAME',
    'CLUSTER_PASSWORD',
    'AIVEN_TRUSTSTORE'
  ];

  const missing = required.filter(key => !process.env[key]);
  if (missing.length > 0) {
    console.error('Error: Missing required environment variables:');
    missing.forEach(key => console.error(`  - ${key}`));
    console.error('\nPlease check your environment file and ensure all credentials are set.');
    process.exit(1);
  }
}

// Load and validate environment
loadEnvFile(envFile);
validateEnv();

// Import config after environment is loaded
const { sinkConfigurations, buildConfig } = await import('./config.js');

// Create Kafka Connect client
const client = new KafkaConnectClient(process.env.CP_CONNECT_URL);

// Test connection
console.log('Connecting to Kafka Connect...');
console.log(`URL: ${process.env.CP_CONNECT_URL}`);
console.log(`Environment: ${process.env.TOPIC_PREFIX}\n`);

try {
  await client.listConnectors();
  console.log('✓ Connected successfully\n');
} catch (error) {
  console.error('✗ Failed to connect to Kafka Connect:');
  console.error(`  ${error.message}\n`);
  console.error('Please ensure:');
  console.error('  1. CP_CONNECT_URL is correct in your env file');
  console.error('  2. Kafka Connect is running and accessible');
  console.error('  3. Port forwarding is active (if using localhost:8083)\n');
  process.exit(1);
}

// Render the UI
render(
  React.createElement(ConnectorManagerUI, {
    client: client,
    env: process.env.TOPIC_PREFIX,
    sinkConfigurations: sinkConfigurations,
    buildConfig: buildConfig
  })
);
