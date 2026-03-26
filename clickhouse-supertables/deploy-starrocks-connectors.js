#!/usr/bin/env node
/**
 * Non-interactive StarRocks connector deployer
 * Usage: node deploy-starrocks-connectors.js --env <env-file> [--group <group>]
 *
 * Examples:
 *   node deploy-starrocks-connectors.js --env digitaldc-prod-starrocks.env
 *   node deploy-starrocks-connectors.js --env digitaldc-prod-starrocks.env --group encarta
 */

import fs from 'fs';

const args = process.argv.slice(2);
const envFlagIndex = args.indexOf('--env');
const groupFlagIndex = args.indexOf('--group');

if (envFlagIndex === -1 || envFlagIndex === args.length - 1) {
  console.error('Usage: node deploy-starrocks-connectors.js --env <env-file> [--group <group>]');
  process.exit(1);
}

const envFile = args[envFlagIndex + 1];
const targetGroup = groupFlagIndex !== -1 ? args[groupFlagIndex + 1] : null;

// Load env file
if (!fs.existsSync(envFile)) {
  console.error(`Error: env file '${envFile}' not found`);
  process.exit(1);
}

fs.readFileSync(envFile, 'utf-8').split('\n').forEach(line => {
  line = line.trim();
  if (line.startsWith('#') || line === '') return;
  const [key, ...valueParts] = line.split('=');
  if (key && valueParts.length > 0) {
    process.env[key.trim()] = valueParts.join('=').trim();
  }
});

// Validate required env vars
const required = [
  'TOPIC_PREFIX', 'CP_CONNECT_URL',
  'STARROCKS_FE_HOST', 'STARROCKS_HTTP_PORT', 'STARROCKS_USER',
  'STARROCKS_PASSWORD', 'STARROCKS_DATABASE',
  'STARROCKS_BE_HOST', 'STARROCKS_BE_PORT',
  'SCHEMA_REGISTRY_URL', 'SCHEMA_REGISTRY_AUTH',
  'CLUSTER_USER_NAME', 'CLUSTER_PASSWORD', 'AIVEN_TRUSTSTORE_PASSWORD'
];
const missing = required.filter(k => !process.env[k]);
if (missing.length > 0) {
  console.error('Missing env vars:', missing.join(', '));
  process.exit(1);
}

const { starrocksSinkConfigurations, buildStarRocksConfig } = await import('./starrocks-config.js');

// Deploy a single connector via Kafka Connect REST API
async function deployConnector(name, config) {
  const url = `${process.env.CP_CONNECT_URL}/connectors/${name}/config`;
  const res = await fetch(url, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(config)
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`HTTP ${res.status}: ${err}`);
  }
  return await res.json();
}

// Get connector status
async function getStatus(name) {
  const url = `${process.env.CP_CONNECT_URL}/connectors/${name}/status`;
  const res = await fetch(url);
  if (!res.ok) return null;
  return await res.json();
}

const groups = targetGroup
  ? { [targetGroup]: starrocksSinkConfigurations[targetGroup] }
  : starrocksSinkConfigurations;

if (targetGroup && !starrocksSinkConfigurations[targetGroup]) {
  console.error(`Group '${targetGroup}' not found. Available: ${Object.keys(starrocksSinkConfigurations).join(', ')}`);
  process.exit(1);
}

console.log(`\nDeploying StarRocks connectors for ${process.env.TOPIC_PREFIX}`);
console.log(`Kafka Connect: ${process.env.CP_CONNECT_URL}`);
console.log(`StarRocks: ${process.env.STARROCKS_FE_HOST}:${process.env.STARROCKS_HTTP_PORT}`);
console.log('─'.repeat(60));

for (const [groupName, sinkConfig] of Object.entries(groups)) {
  const connectorName = `starrocks-connect-${process.env.TOPIC_PREFIX}-${groupName}`;
  console.log(`\n▶ Deploying: ${connectorName}`);

  try {
    const config = buildStarRocksConfig(sinkConfig);
    await deployConnector(connectorName, config);
    console.log(`  ✓ Deployed`);

    // Wait briefly then check status
    await new Promise(r => setTimeout(r, 2000));
    const status = await getStatus(connectorName);
    if (status) {
      const state = status.connector?.state || 'UNKNOWN';
      const tasks = status.tasks || [];
      const taskStates = tasks.map(t => t.state).join(', ') || 'no tasks yet';
      console.log(`  Status: ${state} | Tasks: ${taskStates}`);
    }
  } catch (err) {
    console.error(`  ✗ Failed: ${err.message}`);
  }
}

console.log('\n─'.repeat(60));
console.log('Done. Verify with:');
console.log(`  curl -s ${process.env.CP_CONNECT_URL}/connectors | jq`);
