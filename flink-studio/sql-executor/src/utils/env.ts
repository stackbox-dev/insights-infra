/**
 * Environment variable utilities
 */

import * as fs from 'fs';
import { EnvVars } from '../types.js';

/**
 * Load environment variables from a .env file
 */
export function loadEnvFile(envFilePath: string): EnvVars {
  const envVars: EnvVars = {};

  if (!fs.existsSync(envFilePath)) {
    console.warn(`⚠️  Environment file not found: ${envFilePath}`);
    return envVars;
  }

  try {
    const content = fs.readFileSync(envFilePath, 'utf-8');
    const lines = content.split('\n');

    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
      const line = lines[lineNum].trim();

      // Skip empty lines and comments
      if (!line || line.startsWith('#')) {
        continue;
      }

      // Parse KEY=VALUE format
      const equalIndex = line.indexOf('=');
      if (equalIndex === -1) {
        console.warn(`⚠️  Invalid format in ${envFilePath} line ${lineNum + 1}: ${line}`);
        continue;
      }

      const key = line.substring(0, equalIndex).trim();
      let value = line.substring(equalIndex + 1).trim();

      // Remove quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      envVars[key] = value;
      // Also set in process.env for compatibility
      process.env[key] = value;
    }

    console.log(`✅ Loaded ${Object.keys(envVars).length} environment variables from ${envFilePath}`);
    return envVars;
  } catch (error) {
    console.error(`❌ Error reading environment file ${envFilePath}:`, error);
    return envVars;
  }
}

/**
 * Substitute environment variables in SQL content
 */
export function substituteEnvVariables(
  sqlContent: string,
  envVars: EnvVars,
  strict: boolean = true
): string {
  const varPattern = /\$\{([A-Z_][A-Z0-9_]*)\}/g;
  const undefinedVars: string[] = [];

  const result = sqlContent.replace(varPattern, (match, varName) => {
    // Check env file first, then process.env
    const value = envVars[varName] ?? process.env[varName];

    if (value === undefined) {
      undefinedVars.push(varName);
      return match; // Keep original if not found
    }

    return value;
  });

  if (strict && undefinedVars.length > 0) {
    throw new Error(
      `Environment variable validation failed: Variables not found: ${undefinedVars.join(', ')}`
    );
  }

  return result;
}

/**
 * Load configuration from environment or file
 */
export function loadConfig(_configFile?: string): any {
  const config: any = {
    sql_gateway: {
      url: process.env.SQL_GATEWAY_URL || 'http://flink-sql-gateway.flink-studio.svc.cluster.local',
      session_timeout: parseInt(process.env.SQL_GATEWAY_SESSION_TIMEOUT || '300'),
      poll_interval: parseInt(process.env.SQL_GATEWAY_POLL_INTERVAL || '2'),
      max_wait_time: parseInt(process.env.SQL_GATEWAY_MAX_WAIT_TIME || '60'),
    },
    flink_cluster: {
      url: process.env.FLINK_REST_URL || 'http://flink-session-cluster.flink-studio.svc.cluster.local',
    },
    job_management: {
      enable_database: process.env.JOB_MANAGEMENT_ENABLE_DATABASE === 'true',
      database_path: process.env.JOB_MANAGEMENT_DATABASE_PATH || 'flink_jobs.db',
    },
    logging: {
      level: process.env.LOG_LEVEL || 'INFO',
      format: process.env.LOG_FORMAT || '%(asctime)s - %(levelname)s - %(message)s',
    },
    execution: {
      continue_on_error: process.env.CONTINUE_ON_ERROR !== 'false',
    },
    connection: {
      timeout: parseInt(process.env.CONNECTION_TIMEOUT || '30'),
      retry_count: parseInt(process.env.CONNECTION_RETRY_COUNT || '3'),
      retry_delay: parseInt(process.env.CONNECTION_RETRY_DELAY || '5'),
    },
  };

  return config;
}
