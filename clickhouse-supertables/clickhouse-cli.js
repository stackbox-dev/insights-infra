#!/usr/bin/env node

import React, { useState, useEffect, createElement as h } from 'react';
import { render, Box, Text, useApp } from 'ink';
import SelectInput from 'ink-select-input';
import TextInput from 'ink-text-input';
import Spinner from 'ink-spinner';
import { readFile, readdir } from 'fs/promises';
import { basename, dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { existsSync, readFileSync, statSync } from 'fs';
import chalk from 'chalk';
import { glob } from 'glob';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables from file
function loadEnvFile(filePath) {
  if (!existsSync(filePath)) {
    throw new Error(`Environment file '${filePath}' not found`);
  }

  const content = readFileSync(filePath, 'utf-8');
  const env = {};

  content.split('\n').forEach(line => {
    line = line.trim();
    // Skip comments and empty lines
    if (line.startsWith('#') || line === '') return;

    const [key, ...valueParts] = line.split('=');
    if (key && valueParts.length > 0) {
      env[key.trim()] = valueParts.join('=').trim();
    }
  });

  return env;
}

// Build ClickHouse config from env file
function configFromEnv(env) {
  const required = ['CLICKHOUSE_HOSTNAME', 'CLICKHOUSE_HTTP_PORT', 'CLICKHOUSE_USER', 'CLICKHOUSE_DATABASE'];
  const missing = required.filter(key => !env[key]);

  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  // Support both CLICKHOUSE_PASSWORD and CLICKHOUSE_ADMIN_PASSWORD
  const password = env.CLICKHOUSE_PASSWORD || env.CLICKHOUSE_ADMIN_PASSWORD || '';

  if (!password) {
    throw new Error('Missing password: set either CLICKHOUSE_PASSWORD or CLICKHOUSE_ADMIN_PASSWORD');
  }

  return {
    protocol: 'https',
    hostname: env.CLICKHOUSE_HOSTNAME,
    port: env.CLICKHOUSE_HTTP_PORT,
    username: env.CLICKHOUSE_USER,
    password: password,
    database: env.CLICKHOUSE_DATABASE,
  };
}

// Parse ClickHouse URL
function parseClickHouseURL(url) {
  try {
    const urlObj = new URL(url);

    return {
      protocol: urlObj.protocol.replace(':', ''),
      hostname: urlObj.hostname,
      port: urlObj.port || (urlObj.protocol === 'https:' ? '8443' : '8123'),
      username: urlObj.username || 'default',
      password: urlObj.password || '',
      database: urlObj.pathname.replace('/', '') || 'default',
    };
  } catch (error) {
    throw new Error(`Invalid ClickHouse URL: ${error.message}`);
  }
}

// Execute ClickHouse query via HTTP using fetch
async function executeClickHouseQuery(config, query, settings = {}) {
  const url = `${config.protocol}://${config.hostname}:${config.port}`;
  const auth = Buffer.from(`${config.username}:${config.password}`).toString('base64');

  const settingsParam = Object.entries(settings)
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  const queryUrl = `${url}?database=${config.database}${settingsParam ? '&' + settingsParam : ''}`;

  try {
    const response = await fetch(queryUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'text/plain',
      },
      body: query,
    });

    const text = await response.text();

    if (!response.ok) {
      throw new Error(text || `HTTP ${response.status}: ${response.statusText}`);
    }

    return text;
  } catch (error) {
    throw new Error(`Query execution failed: ${error.message}`);
  }
}

// Get list of SQL folders
async function getSQLFolders() {
  const baseDir = __dirname;
  const entries = await readdir(baseDir, { withFileTypes: true });

  const folders = entries
    .filter(entry => entry.isDirectory())
    .filter(entry => !entry.name.startsWith('.'))
    .filter(entry => !['node_modules', 'manifests', 'scripts', 'maintain'].includes(entry.name))
    .filter(entry => {
      // Check if folder contains SQL files
      const folderPath = join(baseDir, entry.name);
      try {
        const files = readFileSync(folderPath, 'utf-8');
        return false;
      } catch {
        // It's a directory, check for SQL files
        const sqlFiles = glob.sync('*.sql', { cwd: folderPath });
        return sqlFiles.length > 0;
      }
    })
    .map(entry => entry.name)
    .sort();

  return folders;
}

// Get SQL files in a specific folder
async function getSQLFilesInFolder(folderName) {
  const folderPath = join(__dirname, folderName);
  const files = await glob('*.sql', { cwd: folderPath, absolute: false });

  return files
    .filter(f => !f.startsWith('XX-'))
    .sort()
    .map(f => ({
      name: f,
      path: join(folderPath, f),
    }));
}

// Get list of SQL files (all files recursively)
async function getSQLFiles(pattern = null) {
  const baseDir = __dirname;

  if (pattern) {
    // Use glob pattern
    const files = await glob(pattern, { cwd: baseDir, absolute: true });
    return files
      .filter(f => f.endsWith('.sql') && !basename(f).startsWith('XX-'))
      .sort();
  }

  // Get all SQL files recursively, excluding XX- files
  const files = await glob('**/*.sql', {
    cwd: baseDir,
    absolute: true,
    ignore: ['**/XX-*.sql', 'node_modules/**']
  });

  return files.sort();
}

// Get list of tables
async function getTables(config, filter = null) {
  const query = `
    SELECT name
    FROM system.tables
    WHERE database = '${config.database}'
      AND engine NOT LIKE '%View'
      AND engine != 'MaterializedView'
    ORDER BY name
  `;

  const result = await executeClickHouseQuery(config, query);
  const tables = result.trim().split('\n').filter(Boolean);

  if (filter) {
    const regex = new RegExp(filter);
    return tables.filter(t => regex.test(t));
  }

  return tables;
}

// Main App Component
function App({ clickhouseConfig, inputType }) {
  const { exit } = useApp();
  const [screen, setScreen] = useState('main');
  const [config, setConfig] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');
  const [sqlFiles, setSqlFiles] = useState([]);
  const [tables, setTables] = useState([]);
  const [folders, setFolders] = useState([]);
  const [selectedFolder, setSelectedFolder] = useState(null);
  const [folderFiles, setFolderFiles] = useState([]);
  const [selectedFiles, setSelectedFiles] = useState([]);
  const [inlineSQL, setInlineSQL] = useState('');
  const [inlineSQLMode, setInlineSQLMode] = useState(false);
  const [executionLog, setExecutionLog] = useState([]);
  const [queryResult, setQueryResult] = useState('');
  const [selectedFileIndices, setSelectedFileIndices] = useState(new Set());

  useEffect(() => {
    setConfig(clickhouseConfig);
  }, [clickhouseConfig]);

  const mainMenuItems = [
    { label: '📁 Browse & Execute SQL by Folder', value: 'browse_folder' },
    { label: '✏️  Execute Inline SQL', value: 'inline_sql' },
    { label: '⚡ Optimize Tables', value: 'optimize' },
    { label: '📊 Show Tables', value: 'tables' },
    { label: '❌ Exit', value: 'exit' },
  ];

  const handleMainMenu = async (item) => {
    if (item.value === 'exit') {
      exit();
      return;
    }

    setScreen(item.value);
    setLoading(true);
    setError(null);

    try {
      if (item.value === 'browse_folder') {
        const folderList = await getSQLFolders();
        setFolders(folderList);
      } else if (item.value === 'inline_sql') {
        setInlineSQLMode(true);
      } else if (item.value === 'optimize') {
        const tableList = await getTables(config);
        setTables(tableList);
      } else if (item.value === 'tables') {
        const tableList = await getTables(config);
        setTables(tableList);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleFolderSelect = async (item) => {
    setSelectedFolder(item.value);
    setLoading(true);
    try {
      const files = await getSQLFilesInFolder(item.value);
      setFolderFiles(files);
      setScreen('folder_files');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleFileSelection = (items) => {
    setSelectedFiles(items.map(item => item.value));
  };

  const handleExecuteSelectedFiles = async (filesToExecute) => {
    if (!filesToExecute || filesToExecute.length === 0) {
      setError('No files selected');
      return;
    }

    setLoading(true);
    setError(null);
    setExecutionLog([]);
    setStatus(`Executing ${filesToExecute.length} SQL file(s)...`);

    const logs = [];
    try {
      let successCount = 0;

      for (const filePath of filesToExecute) {
        const content = await readFile(filePath, 'utf-8');
        const fileName = basename(filePath);

        setStatus(`Executing ${fileName} (${successCount + 1}/${filesToExecute.length})...`);
        logs.push(`[${successCount + 1}/${filesToExecute.length}] Executing: ${fileName}`);
        setExecutionLog([...logs]);

        const result = await executeClickHouseQuery(config, content, {
          max_execution_time: 600,
        });

        logs.push(`✓ Success: ${fileName}`);
        if (result && result.trim()) {
          logs.push(`  Result: ${result.trim()}`);
        }
        setExecutionLog([...logs]);

        successCount++;
      }

      logs.push('');
      logs.push(`✅ Successfully executed ${successCount} SQL file(s)!`);
      setExecutionLog([...logs]);
      setStatus('Execution completed. Review logs below.');
      setLoading(false);
      setScreen('logs');
    } catch (err) {
      logs.push('');
      logs.push(`❌ Error: ${err.message}`);
      setExecutionLog([...logs]);
      setError(err.message);
      setLoading(false);
      setScreen('logs');
    }
  };

  const handleExecuteInlineSQL = async () => {
    if (!inlineSQL.trim()) {
      setError('SQL query is empty');
      return;
    }

    setLoading(true);
    setError(null);
    setExecutionLog([]);
    setQueryResult('');
    setStatus('Executing inline SQL...');
    setInlineSQLMode(false);

    try {
      const result = await executeClickHouseQuery(config, inlineSQL, {
        max_execution_time: 600,
      });

      setQueryResult(result);
      setExecutionLog([
        'Query executed successfully!',
        '',
        '='.repeat(60),
        'RESULTS:',
        '='.repeat(60),
        result,
        '='.repeat(60)
      ]);
      setStatus('Query completed. Review results below.');
      setLoading(false);
      setScreen('logs');
    } catch (err) {
      setExecutionLog([
        'Query execution failed!',
        '',
        `❌ Error: ${err.message}`
      ]);
      setError(err.message);
      setLoading(false);
      setScreen('logs');
    }
  };


  const handleOptimizeTables = async (tablesToOptimize) => {
    setLoading(true);
    setError(null);
    setExecutionLog([]);
    setStatus(`Optimizing ${tablesToOptimize.length} table(s)...`);

    const logs = [];
    try {
      let successCount = 0;

      for (const table of tablesToOptimize) {
        setStatus(`Optimizing ${table} (${successCount + 1}/${tablesToOptimize.length})...`);
        logs.push(`[${successCount + 1}/${tablesToOptimize.length}] Optimizing: ${table}`);
        setExecutionLog([...logs]);

        await executeClickHouseQuery(config, `OPTIMIZE TABLE \`${table}\` FINAL`, {
          max_execution_time: 600,
        });

        logs.push(`✓ Success: ${table}`);
        setExecutionLog([...logs]);

        successCount++;
      }

      logs.push('');
      logs.push(`✅ Successfully optimized ${successCount} table(s)!`);
      setExecutionLog([...logs]);
      setStatus('Optimization completed. Review logs below.');
      setLoading(false);
      setScreen('logs');
    } catch (err) {
      logs.push('');
      logs.push(`❌ Error: ${err.message}`);
      setExecutionLog([...logs]);
      setError(err.message);
      setLoading(false);
      setScreen('logs');
    }
  };

  // Error state
  if (error && !config) {
    return h(Box, { flexDirection: 'column', padding: 1 },
      h(Text, { color: 'red' }, `❌ Error: ${error}`),
      h(Text, { color: 'yellow' }, 'Usage: npm run clickhouse https://user:password@hostname:port/database')
    );
  }

  // Loading state
  if (!config) {
    return h(Box, { padding: 1 },
      h(Spinner, { type: 'dots' }),
      h(Text, null, ' Loading...')
    );
  }

  // Main UI
  const children = [];

  // Header
  const sourceInfo = inputType === 'env' ? '📄 From env file' : '🔗 From URL';
  children.push(
    h(Box, { key: 'header', borderStyle: 'round', borderColor: 'cyan', padding: 1, marginBottom: 1 },
      h(Box, { flexDirection: 'column' },
        h(Text, { bold: true, color: 'cyan' }, '🗄️  ClickHouse CLI'),
        h(Text, { dimColor: true }, `Host: ${config.hostname}:${config.port}`),
        h(Text, { dimColor: true }, `Database: ${config.database}`),
        h(Text, { dimColor: true }, `User: ${config.username}`),
        h(Text, { dimColor: true, color: 'green' }, sourceInfo)
      )
    )
  );

  // Error display
  if (error) {
    children.push(
      h(Box, { key: 'error', borderStyle: 'round', borderColor: 'red', padding: 1, marginBottom: 1 },
        h(Text, { color: 'red' }, `❌ ${error}`)
      )
    );
  }

  // Loading status
  if (loading && status) {
    children.push(
      h(Box, { key: 'loading', marginBottom: 1 },
        h(Spinner, { type: 'dots' }),
        h(Text, null, ` ${status}`)
      )
    );
  }

  // Main menu
  if (screen === 'main' && !loading) {
    children.push(
      h(Box, { key: 'main', flexDirection: 'column' },
        h(Text, { bold: true, marginBottom: 1 }, 'Select an action:'),
        h(SelectInput, { items: mainMenuItems, onSelect: handleMainMenu })
      )
    );
  }

  // Folder browse screen
  if (screen === 'browse_folder' && !loading && folders.length > 0) {
    const folderItems = folders.map(folder => ({
      label: `📁 ${folder}`,
      value: folder
    }));

    folderItems.push({ label: '⬅️  Back to Main Menu', value: '__back__' });

    children.push(
      h(Box, { key: 'folders', flexDirection: 'column' },
        h(Text, { bold: true, marginBottom: 1 }, `Found ${folders.length} SQL folders:`),
        h(SelectInput, {
          items: folderItems,
          onSelect: (item) => {
            if (item.value === '__back__') {
              setScreen('main');
            } else {
              handleFolderSelect(item);
            }
          }
        })
      )
    );
  }

  // Folder files screen
  if (screen === 'folder_files' && !loading && folderFiles.length > 0) {
    const fileItems = folderFiles.map((file, idx) => {
      const isSelected = selectedFileIndices.has(idx);
      return {
        label: `${isSelected ? '☑' : '☐'} ${file.name}`,
        value: idx
      };
    });

    const actionItems = [
      { label: `✅ Execute Selected (${selectedFileIndices.size} files)`, value: 'execute_selected' },
      { label: '⚡ Execute All Files', value: 'execute_all' },
      { label: '🔄 Clear Selection', value: 'clear' },
      { label: '⬅️  Back to Folders', value: 'back' },
    ];

    children.push(
      h(Box, { key: 'folder_files', flexDirection: 'column' },
        h(Text, { bold: true, marginBottom: 1 }, `Select files to execute from ${selectedFolder}:`),
        h(Text, { dimColor: true, marginBottom: 1 }, `Total files: ${folderFiles.length} | Selected: ${selectedFileIndices.size}`),
        h(SelectInput, {
          items: fileItems,
          onSelect: (item) => {
            const newSelection = new Set(selectedFileIndices);
            if (newSelection.has(item.value)) {
              newSelection.delete(item.value);
            } else {
              newSelection.add(item.value);
            }
            setSelectedFileIndices(newSelection);
          }
        }),
        h(Box, { marginTop: 1 },
          h(SelectInput, {
            items: actionItems,
            onSelect: (item) => {
              if (item.value === 'execute_selected') {
                if (selectedFileIndices.size === 0) {
                  setError('No files selected. Please select at least one file.');
                  return;
                }
                const filePaths = Array.from(selectedFileIndices).map(idx => folderFiles[idx].path);
                handleExecuteSelectedFiles(filePaths);
              } else if (item.value === 'execute_all') {
                const filePaths = folderFiles.map(f => f.path);
                handleExecuteSelectedFiles(filePaths);
              } else if (item.value === 'clear') {
                setSelectedFileIndices(new Set());
              } else {
                setScreen('browse_folder');
                setSelectedFolder(null);
                setFolderFiles([]);
                setSelectedFileIndices(new Set());
              }
            }
          })
        )
      )
    );
  }

  // Inline SQL screen
  if (screen === 'inline_sql' && !loading && inlineSQLMode) {
    children.push(
      h(Box, { key: 'inline_sql', flexDirection: 'column' },
        h(Text, { bold: true, marginBottom: 1 }, 'Enter SQL Query:'),
        h(TextInput, {
          value: inlineSQL,
          onChange: setInlineSQL,
          onSubmit: handleExecuteInlineSQL,
          placeholder: 'SELECT * FROM ...'
        }),
        h(Box, { marginTop: 1 },
          h(Text, { dimColor: true }, 'Press '),
          h(Text, { bold: true, color: 'green', dimColor: true }, 'Enter'),
          h(Text, { dimColor: true }, ' to execute, '),
          h(Text, { bold: true, color: 'red', dimColor: true }, 'Ctrl+C'),
          h(Text, { dimColor: true }, ' to cancel')
        )
      )
    );
  }


  // Optimize tables screen
  if (screen === 'optimize' && !loading && tables.length > 0) {
    const selectItems = [
      { label: '⚡ Optimize All Tables', value: '__all__' },
      ...tables.map(table => ({ label: `📊 ${table}`, value: table })),
      { label: '⬅️  Back to Main Menu', value: '__back__' },
    ];

    children.push(
      h(Box, { key: 'optimize', flexDirection: 'column' },
        h(Text, { bold: true, marginBottom: 1 }, `Select table(s) to optimize:`),
        h(Text, { color: 'yellow', marginBottom: 1 }, `⚠️  Warning: This operation can be resource intensive!`),
        h(Text, { dimColor: true, marginBottom: 1 }, `Total tables: ${tables.length}`),
        h(SelectInput, {
          items: selectItems,
          onSelect: (item) => {
            if (item.value === '__back__') {
              setScreen('main');
            } else if (item.value === '__all__') {
              handleOptimizeTables(tables);
            } else {
              handleOptimizeTables([item.value]);
            }
          }
        })
      )
    );
  }

  // Show tables screen
  if (screen === 'tables' && !loading && tables.length > 0) {
    const tableItems = tables.map((table, idx) =>
      h(Text, { key: idx }, `  ${idx + 1}. ${table}`)
    );

    children.push(
      h(Box, { key: 'tables', flexDirection: 'column' },
        h(Text, { bold: true, marginBottom: 1 }, `Tables in database '${config.database}': (${tables.length} total)`),
        ...tableItems,
        h(Box, { marginTop: 1 },
          h(SelectInput, {
            items: [{ label: '⬅️  Back to Main Menu', value: 'back' }],
            onSelect: () => {
              setScreen('main');
              setTables([]);
            }
          })
        )
      )
    );
  }

  // Logs/Results screen
  if (screen === 'logs' && !loading) {
    const logLines = executionLog.map((line, idx) =>
      h(Text, { key: `log-${idx}` }, line)
    );

    children.push(
      h(Box, { key: 'logs', flexDirection: 'column' },
        h(Box, { borderStyle: 'round', borderColor: error ? 'red' : 'green', padding: 1, marginBottom: 1, flexDirection: 'column' },
          h(Text, { bold: true, color: error ? 'red' : 'green' }, status)
        ),
        h(Box, { flexDirection: 'column', marginBottom: 1 },
          ...logLines
        ),
        h(Box, { marginTop: 1 },
          h(Text, { dimColor: true, italic: true }, 'Tip: Scroll up/down in your terminal to view all logs'),
          h(Box, { marginTop: 1 },
            h(SelectInput, {
              items: [{ label: '⬅️  Back to Main Menu', value: 'back' }],
              onSelect: () => {
                setScreen('main');
                setStatus('');
                setError(null);
                setInlineSQL('');
                setSelectedFiles([]);
                setSelectedFolder(null);
                setExecutionLog([]);
                setQueryResult('');
              }
            })
          )
        )
      )
    );
  }

  return h(Box, { flexDirection: 'column', padding: 1 }, ...children);
}

// Parse command line arguments
const args = process.argv.slice(2);

// Parse --env flag
let input = null;
let envFlag = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--env' && i + 1 < args.length) {
    input = args[i + 1];
    envFlag = true;
    break;
  } else if (!args[i].startsWith('--')) {
    input = args[i];
    break;
  }
}

if (!input) {
  console.log(chalk.red('❌ Error: ClickHouse URL or environment file is required'));
  console.log(chalk.yellow('\nUsage:'));
  console.log(chalk.yellow('  npm run clickhouse -- --env <env-file>'));
  console.log(chalk.yellow('  npm run clickhouse <clickhouse-url>'));
  console.log(chalk.yellow('  npm run clickhouse <env-file>'));
  console.log(chalk.yellow('\nExamples:'));
  console.log(chalk.yellow('  npm run clickhouse -- --env .sbx-uat.env'));
  console.log(chalk.yellow('  npm run clickhouse -- --env .samadhan-prod.env'));
  console.log(chalk.yellow('  npm run clickhouse https://user:password@hostname:8443/database'));
  console.log(chalk.yellow('  npm run clickhouse .sbx-uat.env'));
  process.exit(1);
}

// Check if we're in a TTY (but allow npm run to work)
// Only block if explicitly running in background with &
if (!process.stdin.isTTY && process.stdout.isTTY) {
  console.log(chalk.red('❌ Error: This CLI requires an interactive terminal'));
  console.log(chalk.yellow('Please run directly in your terminal, not in the background'));
  process.exit(1);
}

// Determine if input is a URL or env file
let clickhouseConfig;
let inputType;

try {
  // If --env flag was used, force env file parsing
  if (envFlag) {
    const envPath = input.startsWith('/') ? input : `${__dirname}/${input}`;
    const env = loadEnvFile(envPath);
    clickhouseConfig = configFromEnv(env);
    inputType = 'env';
  } else if (input.startsWith('http://') || input.startsWith('https://')) {
    // It's a URL
    clickhouseConfig = parseClickHouseURL(input);
    inputType = 'url';

    // Warn if no database specified
    if (clickhouseConfig.database === 'default') {
      console.log(chalk.yellow('⚠️  No database specified in URL, using "default" database'));
      console.log(chalk.yellow('   To specify database, add it to URL: https://user:pass@host:port/database_name\n'));
    }
  } else if (input.endsWith('.env') || existsSync(input)) {
    // It's an env file
    const envPath = input.startsWith('/') ? input : `${__dirname}/${input}`;
    const env = loadEnvFile(envPath);
    clickhouseConfig = configFromEnv(env);
    inputType = 'env';
  } else {
    // Try as URL
    clickhouseConfig = parseClickHouseURL(input);
    inputType = 'url';

    // Warn if no database specified
    if (clickhouseConfig.database === 'default') {
      console.log(chalk.yellow('⚠️  No database specified in URL, using "default" database'));
      console.log(chalk.yellow('   To specify database, add it to URL: https://user:pass@host:port/database_name\n'));
    }
  }
} catch (error) {
  console.log(chalk.red(`❌ Error: ${error.message}`));
  console.log(chalk.yellow('\nPlease provide either:'));
  console.log(chalk.yellow('  - A valid ClickHouse URL (https://user:password@hostname:port/database)'));
  console.log(chalk.yellow('  - An environment file path with --env flag'));
  console.log(chalk.yellow('  - An environment file path (.env file)'));
  process.exit(1);
}

// Render the app
render(h(App, { clickhouseConfig, inputType }));
