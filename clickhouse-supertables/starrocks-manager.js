#!/usr/bin/env node

/**
 * StarRocks Sink Connector Manager
 *
 * Interactive CLI tool for managing StarRocks sink connectors
 *
 * Usage:
 *   node starrocks-manager.js --env <env-file>
 *   npm run starrocks -- --env .sbx-uat.env
 *
 * Examples:
 *   node starrocks-manager.js --env .sbx-uat.env
 *   node starrocks-manager.js --env .huldc-prod.env
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
  console.error('StarRocks Sink Connector Manager');
  console.error('==================================\n');
  console.error('Usage: node starrocks-manager.js --env <env-file>');
  console.error('\nExamples:');
  console.error('  node starrocks-manager.js --env .sbx-uat.env');
  console.error('  node starrocks-manager.js --env .huldc-prod.env');
  console.error('  node starrocks-manager.js --env .samadhan-prod.env');
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

// Validate required environment variables for StarRocks
function validateEnv() {
  const required = [
    'TOPIC_PREFIX',
    'STARROCKS_FE_HOST',
    'STARROCKS_HTTP_PORT',
    'STARROCKS_QUERY_PORT',
    'STARROCKS_USER',
    'STARROCKS_PASSWORD',
    'STARROCKS_DATABASE',
    'SCHEMA_REGISTRY_URL',
    'CP_CONNECT_URL',
    'SCHEMA_REGISTRY_AUTH',
    'CLUSTER_USER_NAME',
    'CLUSTER_PASSWORD',
    'AIVEN_TRUSTSTORE_PASSWORD'
  ];

  const missing = required.filter(key => !process.env[key]);
  if (missing.length > 0) {
    console.error('Error: Missing required environment variables for StarRocks:');
    missing.forEach(key => console.error(`  - ${key}`));
    console.error('\nPlease check your environment file and ensure all credentials are set.');
    process.exit(1);
  }
}

// Load and validate environment
loadEnvFile(envFile);
validateEnv();

// Import StarRocks config after environment is loaded
const { starrocksSinkConfigurations, buildStarRocksConfig } = await import('./starrocks-config.js');

// Create Kafka Connect client with StarRocks filter
const client = new KafkaConnectClient(
  process.env.CP_CONNECT_URL,
  'com.starrocks.connector.kafka.StarRocksSinkConnector'
);

// Get connector name with StarRocks prefix
function getConnectorName(sinkKey) {
  const topicPrefix = process.env.TOPIC_PREFIX;
  return `${topicPrefix}-starrocks-${sinkKey}`;
}

// Render the UI with StarRocks-specific configuration
render(
  React.createElement(ConnectorManagerUI, {
    client,
    sinkConfigurations: starrocksSinkConfigurations,
    buildConfig: buildStarRocksConfig,
    getConnectorName,
    title: 'StarRocks Sink Connector Manager ⭐',
    description: 'Manage StarRocks sink connectors'
  })
);
