#!/usr/bin/env node

import { useState, useEffect, createElement as h } from 'react';
import { render, Box, Text, useApp, useInput } from 'ink';
import SelectInput from 'ink-select-input';
import TextInput from 'ink-text-input';
import Spinner from 'ink-spinner';
import { readFile, readdir } from 'fs/promises';
import { basename, dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { existsSync, readFileSync } from 'fs';
import chalk from 'chalk';
import { glob } from 'glob';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Searchable Select Component with jump-to-actions feature
// Press Tab to jump to action items at the bottom (Execute, Clear, Back, etc.)
// Press / to filter/search items
function SearchableSelect({ items, onSelect, searchPlaceholder = 'Type to filter...', showSearch = true }) {
  const [searchTerm, setSearchTerm] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [jumpToActions, setJumpToActions] = useState(false);

  // Separate action items from regular items
  const actionItems = items.filter(item =>
    item.value?.type === 'action' || item.value?.type === 'separator' ||
    item.value === '__back__' || item.value === '__all__'
  );
  const regularItems = items.filter(item =>
    item.value?.type !== 'action' && item.value?.type !== 'separator' &&
    item.value !== '__back__' && item.value !== '__all__'
  );

  // Filter regular items based on search term
  const filteredRegularItems = searchTerm
    ? regularItems.filter(item => {
        const label = item.label.toLowerCase();
        const search = searchTerm.toLowerCase();
        return label.includes(search);
      })
    : regularItems;

  // Build final item list based on mode
  let displayItems;
  if (jumpToActions) {
    // Show only action items when jumped to actions
    displayItems = actionItems;
  } else if (searchTerm) {
    // Show filtered items + actions when searching
    displayItems = [...filteredRegularItems, ...actionItems];
  } else {
    // Show all items normally
    displayItems = items;
  }

  // Handle keyboard input
  useInput((input, key) => {
    // Tab to toggle jump to actions
    if (key.tab) {
      setJumpToActions(!jumpToActions);
      setSearchTerm('');
      setIsSearching(false);
      return;
    }

    if (!showSearch) return;

    // '/' to start searching (only when not in jump mode)
    if (input === '/' && !isSearching && !jumpToActions) {
      setIsSearching(true);
      return;
    }

    // Escape to clear search and exit search mode
    if (key.escape && isSearching) {
      setSearchTerm('');
      setIsSearching(false);
      return;
    }

    // Escape to exit jump mode
    if (key.escape && jumpToActions) {
      setJumpToActions(false);
      return;
    }
  });

  if (!showSearch) {
    return h(SelectInput, { items, onSelect });
  }

  return h(Box, { flexDirection: 'column' },
    // Status row showing current mode
    h(Box, { marginBottom: 1 },
      jumpToActions
        ? h(Text, { color: 'cyan', bold: true }, '⚡ Actions (Tab to go back to list)')
        : isSearching
          ? h(Box, null,
              h(Text, { dimColor: true }, '🔍 '),
              h(TextInput, {
                value: searchTerm,
                onChange: setSearchTerm,
                placeholder: searchPlaceholder,
                focus: true
              })
            )
          : h(Text, { dimColor: true }, `Tab: jump to actions | /: search (${regularItems.length} items)`)
    ),
    // Show filtered count if searching
    searchTerm && h(Text, { dimColor: true, marginBottom: 1 },
      `Showing ${filteredRegularItems.length} matches`
    ),
    // Select input with appropriate items
    h(SelectInput, {
      items: displayItems.length > 0 ? displayItems : [{ label: 'No matches found', value: '__no_match__' }],
      onSelect: (item) => {
        if (item.value === '__no_match__') return;
        // Reset jump mode when an action is selected
        if (jumpToActions) {
          setJumpToActions(false);
        }
        onSelect(item);
      }
    })
  );
}

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
    // Normalize clickhouse:// and clickhouses:// to http:// and https://
    let normalizedUrl = url;
    if (url.startsWith('clickhouses://')) {
      normalizedUrl = url.replace('clickhouses://', 'https://');
    } else if (url.startsWith('clickhouse://')) {
      normalizedUrl = url.replace('clickhouse://', 'http://');
    }

    const urlObj = new URL(normalizedUrl);

    // Use the port from URL, no smart defaults - user knows their port
    if (!urlObj.port) {
      throw new Error('Port is required in the URL (e.g., https://user:pass@host:8443/database)');
    }

    return {
      protocol: urlObj.protocol.replace(':', ''),
      hostname: urlObj.hostname,
      port: urlObj.port,
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
    const bodyBuffer = Buffer.from(query, 'utf-8');
    const response = await fetch(queryUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'text/plain',
        'Content-Length': String(bodyBuffer.length),
      },
      body: bodyBuffer,
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
      const sqlFiles = glob.sync('*.sql', { cwd: folderPath });
      return sqlFiles.length > 0;
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
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }))
    .map(f => ({
      name: f,
      path: join(folderPath, f),
    }));
}

// Get list of databases
async function getDatabases(config) {
  const query = `SELECT name FROM system.databases WHERE name NOT IN ('system', 'INFORMATION_SCHEMA', 'information_schema') ORDER BY name`;
  const result = await executeClickHouseQuery({ ...config, database: 'system' }, query);
  return result.trim().split('\n').filter(Boolean);
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
  const needsDbSelection = clickhouseConfig.database === 'default' || !clickhouseConfig.database;
  const [screen, setScreen] = useState(needsDbSelection ? 'select_db' : 'main');
  const [config, setConfig] = useState(needsDbSelection ? null : clickhouseConfig);
  const [databases, setDatabases] = useState([]);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(needsDbSelection);
  const [status, setStatus] = useState(needsDbSelection ? 'Loading databases...' : '');
  const [tables, setTables] = useState([]);
  const [folders, setFolders] = useState([]);
  const [selectedFolder, setSelectedFolder] = useState(null);
  const [folderFiles, setFolderFiles] = useState([]);
  const [inlineSQL, setInlineSQL] = useState('');
  const [inlineSQLMode, setInlineSQLMode] = useState(false);
  const [executionLog, setExecutionLog] = useState([]);
  const [selectedFileIndices, setSelectedFileIndices] = useState(new Set());
  const [selectedTableIndices, setSelectedTableIndices] = useState(new Set());
  const [tablesToDelete, setTablesToDelete] = useState([]);

  // Keyboard shortcuts
  useInput((input, key) => {
    if (loading) return;

    // ESC to go back
    if (key.escape) {
      if (screen === 'main' || screen === 'select_db') {
        exit();
      } else if (screen === 'folder_files') {
        setScreen('browse_folder');
        setSelectedFolder(null);
        setFolderFiles([]);
        setSelectedFileIndices(new Set());
      } else if (screen === 'inline_sql') {
        setScreen('main');
        setInlineSQLMode(false);
        setInlineSQL('');
      } else if (screen === 'confirm_delete') {
        setScreen('delete_tables');
        setTablesToDelete([]);
      } else if (screen === 'delete_tables') {
        setScreen('main');
        setTables([]);
        setSelectedTableIndices(new Set());
      } else {
        setScreen('main');
        setTables([]);
        setFolders([]);
        setStatus('');
        setError(null);
        setExecutionLog([]);
      }
    }

    // Enter on logs screen to go back
    if (key.return && screen === 'logs') {
      setScreen('main');
      setStatus('');
      setError(null);
      setExecutionLog([]);
    }

    // 'q' to quit from main menu or db selection
    if (input === 'q' && (screen === 'main' || screen === 'select_db')) {
      exit();
    }
  });

  // Load databases if needed
  useEffect(() => {
    if (needsDbSelection) {
      getDatabases(clickhouseConfig)
        .then(dbs => {
          setDatabases(dbs);
          setLoading(false);
          setStatus('');
        })
        .catch(err => {
          setError(err.message);
          setLoading(false);
        });
    }
  }, [clickhouseConfig, needsDbSelection]);

  const handleDatabaseSelect = (db) => {
    const newConfig = { ...clickhouseConfig, database: db };
    setConfig(newConfig);
    setScreen('main');
  };

  const mainMenuItems = [
    { label: '📁 Browse & Execute SQL by Folder', value: 'browse_folder' },
    { label: '✏️  Execute Inline SQL', value: 'inline_sql' },
    { label: '⚡ Optimize Tables', value: 'optimize' },
    { label: '📊 Show Tables', value: 'tables' },
    { label: '🗑️  Delete Tables', value: 'delete_tables' },
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
      } else if (item.value === 'delete_tables') {
        const tableList = await getTables(config);
        setTables(tableList);
        setSelectedTableIndices(new Set());
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
    setStatus('Executing inline SQL...');
    setInlineSQLMode(false);

    try {
      const result = await executeClickHouseQuery(config, inlineSQL, {
        max_execution_time: 600,
      });

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

  const handleDeleteTables = async (tablesToDrop) => {
    setLoading(true);
    setError(null);
    setExecutionLog([]);
    setStatus(`Deleting ${tablesToDrop.length} table(s)...`);

    const logs = [];
    try {
      let successCount = 0;

      for (const table of tablesToDrop) {
        setStatus(`Deleting ${table} (${successCount + 1}/${tablesToDrop.length})...`);
        logs.push(`[${successCount + 1}/${tablesToDrop.length}] Dropping: ${table}`);
        setExecutionLog([...logs]);

        await executeClickHouseQuery(config, `DROP TABLE IF EXISTS \`${table}\``, {
          max_execution_time: 600,
        });

        logs.push(`✓ Dropped: ${table}`);
        setExecutionLog([...logs]);

        successCount++;
      }

      logs.push('');
      logs.push(`✅ Successfully deleted ${successCount} table(s)!`);
      setExecutionLog([...logs]);
      setStatus('Deletion completed. Review logs below.');
      setLoading(false);
      setTablesToDelete([]);
      setSelectedTableIndices(new Set());
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

  // Error state during database loading
  if (error && !config && screen === 'select_db') {
    return h(Box, { flexDirection: 'column', padding: 1 },
      h(Text, { color: 'red' }, `❌ Error: ${error}`),
      h(Text, { color: 'yellow' }, 'Could not load databases. Check your connection.')
    );
  }

  // Database selection screen
  if (screen === 'select_db') {
    if (loading) {
      return h(Box, { padding: 1 },
        h(Spinner, { type: 'dots' }),
        h(Text, null, ' Loading databases...')
      );
    }

    const dbItems = databases.map(db => ({
      key: `db-${db}`,
      label: `📁 ${db}`,
      value: db
    }));
    // Only add default if it's not already in the list
    if (!databases.includes('default')) {
      dbItems.push({ key: 'db-default-fallback', label: '📁 default', value: 'default' });
    }

    return h(Box, { flexDirection: 'column', padding: 1 },
      h(Box, { borderStyle: 'round', borderColor: 'cyan', padding: 1, marginBottom: 1 },
        h(Box, { flexDirection: 'column' },
          h(Text, { bold: true, color: 'cyan' }, '🗄️  ClickHouse CLI'),
          h(Text, { dimColor: true }, `Host: ${clickhouseConfig.hostname}:${clickhouseConfig.port}`),
          h(Text, { dimColor: true, color: 'yellow' }, 'No database specified')
        )
      ),
      h(Text, { bold: true }, 'Select a database:'),
      h(Text, { dimColor: true, marginBottom: 1 }, 'Press Esc to quit'),
      h(SelectInput, {
        items: dbItems,
        onSelect: (item) => handleDatabaseSelect(item.value)
      })
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
        h(Text, { bold: true }, 'Select an action:'),
        h(Text, { dimColor: true, marginBottom: 1 }, 'Press q or Esc to quit'),
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
        h(Text, { bold: true }, `Found ${folders.length} SQL folders:`),
        h(Text, { dimColor: true, marginBottom: 1 }, 'Press Esc to go back'),
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

  // Folder files screen - combined list with files and actions
  if (screen === 'folder_files' && !loading && folderFiles.length > 0) {
    // Combine files and actions into single list
    const allItems = [
      ...folderFiles.map((file, idx) => {
        const isSelected = selectedFileIndices.has(idx);
        return {
          key: `file-${idx}`,
          label: `${isSelected ? '☑' : '☐'} ${file.name}`,
          value: { type: 'file', idx }
        };
      }),
      { key: 'sep', label: '─'.repeat(30), value: { type: 'separator' } },
      { key: 'exec-sel', label: `✅ Execute Selected (${selectedFileIndices.size})`, value: { type: 'action', action: 'execute_selected' } },
      { key: 'exec-all', label: '⚡ Execute All Files', value: { type: 'action', action: 'execute_all' } },
      { key: 'clear', label: '🔄 Clear Selection', value: { type: 'action', action: 'clear' } },
      { key: 'back', label: '⬅️  Back to Folders', value: { type: 'action', action: 'back' } },
    ];

    children.push(
      h(Box, { key: 'folder_files', flexDirection: 'column' },
        h(Text, { bold: true }, `Files in ${selectedFolder}:`),
        h(Text, { dimColor: true, marginBottom: 1 }, `Enter: toggle | Tab: jump to actions | Esc: back | ${selectedFileIndices.size}/${folderFiles.length} selected`),
        h(SearchableSelect, {
          items: allItems,
          searchPlaceholder: 'Filter files...',
          onSelect: (item) => {
            if (item.value.type === 'file') {
              const idx = item.value.idx;
              const newSelection = new Set(selectedFileIndices);
              if (newSelection.has(idx)) {
                newSelection.delete(idx);
              } else {
                newSelection.add(idx);
              }
              setSelectedFileIndices(newSelection);
            } else if (item.value.type === 'action') {
              const action = item.value.action;
              if (action === 'execute_selected') {
                if (selectedFileIndices.size === 0) {
                  setError('No files selected');
                  return;
                }
                const filePaths = Array.from(selectedFileIndices).sort((a, b) => a - b).map(idx => folderFiles[idx].path);
                handleExecuteSelectedFiles(filePaths);
              } else if (action === 'execute_all') {
                const filePaths = folderFiles.map(f => f.path);
                handleExecuteSelectedFiles(filePaths);
              } else if (action === 'clear') {
                setSelectedFileIndices(new Set());
              } else if (action === 'back') {
                setScreen('browse_folder');
                setSelectedFolder(null);
                setFolderFiles([]);
                setSelectedFileIndices(new Set());
              }
            }
          }
        })
      )
    );
  }

  // Inline SQL screen
  if (screen === 'inline_sql' && !loading && inlineSQLMode) {
    children.push(
      h(Box, { key: 'inline_sql', flexDirection: 'column' },
        h(Text, { bold: true }, 'Enter SQL Query:'),
        h(Box, { marginTop: 1 },
          h(Text, null, '> '),
          h(TextInput, {
            value: inlineSQL,
            onChange: setInlineSQL,
            onSubmit: handleExecuteInlineSQL,
            placeholder: 'SELECT * FROM ...'
          })
        ),
        h(Text, { dimColor: true, marginTop: 1 }, 'Enter: execute | Esc: back')
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
        h(Text, { dimColor: true, marginBottom: 1 }, `Total tables: ${tables.length} | Tab: jump to actions`),
        h(SearchableSelect, {
          items: selectItems,
          searchPlaceholder: 'Filter tables...',
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
  if (screen === 'tables' && !loading) {
    if (tables.length > 0) {
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
    } else {
      children.push(
        h(Box, { key: 'tables', flexDirection: 'column' },
          h(Text, { color: 'yellow' }, `No tables found in database '${config.database}'`),
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
  }

  // Delete tables screen (multi-select)
  if (screen === 'delete_tables' && !loading && tables.length > 0) {
    const allItems = [
      ...tables.map((table, idx) => {
        const isSelected = selectedTableIndices.has(idx);
        return {
          key: `table-${idx}`,
          label: `${isSelected ? '☑' : '☐'} ${table}`,
          value: { type: 'table', idx, name: table }
        };
      }),
      { key: 'sep', label: '─'.repeat(40), value: { type: 'separator' } },
      { key: 'delete-sel', label: `🗑️  Delete Selected (${selectedTableIndices.size})`, value: { type: 'action', action: 'delete_selected' } },
      { key: 'clear', label: '🔄 Clear Selection', value: { type: 'action', action: 'clear' } },
      { key: 'back', label: '⬅️  Back to Main Menu', value: { type: 'action', action: 'back' } },
    ];

    children.push(
      h(Box, { key: 'delete_tables', flexDirection: 'column' },
        h(Text, { bold: true, color: 'red' }, '🗑️  Delete Tables'),
        h(Text, { color: 'yellow', marginBottom: 1 }, `⚠️  WARNING: This will permanently delete tables!`),
        h(Text, { dimColor: true, marginBottom: 1 }, `Enter: toggle | Tab: jump to actions | Esc: back | ${selectedTableIndices.size}/${tables.length} selected`),
        h(SearchableSelect, {
          items: allItems,
          searchPlaceholder: 'Filter tables...',
          onSelect: (item) => {
            if (item.value.type === 'table') {
              const idx = item.value.idx;
              const newSelection = new Set(selectedTableIndices);
              if (newSelection.has(idx)) {
                newSelection.delete(idx);
              } else {
                newSelection.add(idx);
              }
              setSelectedTableIndices(newSelection);
            } else if (item.value.type === 'action') {
              const action = item.value.action;
              if (action === 'delete_selected') {
                if (selectedTableIndices.size === 0) {
                  setError('No tables selected');
                  return;
                }
                const selectedTables = Array.from(selectedTableIndices).sort((a, b) => a - b).map(idx => tables[idx]);
                setTablesToDelete(selectedTables);
                setScreen('confirm_delete');
              } else if (action === 'clear') {
                setSelectedTableIndices(new Set());
              } else if (action === 'back') {
                setScreen('main');
                setTables([]);
                setSelectedTableIndices(new Set());
              }
            }
          }
        })
      )
    );
  }

  // Confirm delete screen
  if (screen === 'confirm_delete' && !loading && tablesToDelete.length > 0) {
    const tableList = tablesToDelete.map((table, idx) =>
      h(Text, { key: `del-${idx}`, color: 'red' }, `  • ${table}`)
    );

    const confirmItems = [
      { key: 'cancel', label: '❌ Cancel - Go Back', value: 'cancel' },
      { key: 'confirm', label: '✅ Yes, Delete These Tables', value: 'confirm' },
    ];

    children.push(
      h(Box, { key: 'confirm_delete', flexDirection: 'column' },
        h(Box, { borderStyle: 'round', borderColor: 'red', padding: 1, marginBottom: 1, flexDirection: 'column' },
          h(Text, { bold: true, color: 'red' }, '⚠️  CONFIRM DELETION'),
          h(Text, { color: 'yellow' }, `You are about to DELETE ${tablesToDelete.length} table(s):`)
        ),
        h(Box, { flexDirection: 'column', marginBottom: 1 },
          ...tableList
        ),
        h(Text, { color: 'red', bold: true, marginBottom: 1 }, 'This action CANNOT be undone!'),
        h(Text, { dimColor: true, marginBottom: 1 }, 'Esc: cancel'),
        h(SelectInput, {
          items: confirmItems,
          onSelect: (item) => {
            if (item.value === 'cancel') {
              setScreen('delete_tables');
              setTablesToDelete([]);
            } else if (item.value === 'confirm') {
              handleDeleteTables(tablesToDelete);
            }
          }
        })
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
        h(Text, { dimColor: true }, 'Press Esc or Enter to go back')
      )
    );
  }

  return h(Box, { flexDirection: 'column', padding: 1 }, ...children);
}

// Parse command line arguments
const args = process.argv.slice(2);

// Parse flags
let input = null;
let envFlag = false;
let queryFlag = null;
let fileFlag = null;
let folderFlag = null;
let tablesFlag = false;
let optimizeFlag = null;
let helpFlag = false;

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--env' && i + 1 < args.length) {
    input = args[++i];
    envFlag = true;
  } else if (arg === '--query' || arg === '-q') {
    queryFlag = args[++i];
  } else if (arg === '--file' || arg === '-f') {
    fileFlag = args[++i];
  } else if (arg === '--folder') {
    folderFlag = args[++i];
  } else if (arg === '--tables') {
    tablesFlag = true;
  } else if (arg === '--optimize') {
    optimizeFlag = args[++i] || '__all__';
  } else if (arg === '--help' || arg === '-h') {
    helpFlag = true;
  } else if (!arg.startsWith('--') && !arg.startsWith('-')) {
    if (!input) input = arg;
  }
}

const nonInteractiveMode = queryFlag || fileFlag || folderFlag || tablesFlag || optimizeFlag;

if (helpFlag) {
  console.log(chalk.cyan.bold('\n🗄️  ClickHouse CLI\n'));
  console.log(chalk.white('Interactive mode (requires TTY):'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url>'));
  console.log(chalk.yellow('  node clickhouse-cli.js --env <env-file>\n'));
  console.log(chalk.white('Non-interactive mode (scriptable):'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --query "SELECT 1"'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> -q "SELECT * FROM system.tables"'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --file <sql-file>'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> -f path/to/query.sql'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --folder <folder-name>'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --tables'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --optimize <table-name>'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --optimize __all__\n'));
  console.log(chalk.white('Flags:'));
  console.log(chalk.yellow('  --env <file>      Load config from env file'));
  console.log(chalk.yellow('  --query, -q       Execute inline SQL query'));
  console.log(chalk.yellow('  --file, -f        Execute SQL from file'));
  console.log(chalk.yellow('  --folder          Execute all SQL files in folder'));
  console.log(chalk.yellow('  --tables          List all tables'));
  console.log(chalk.yellow('  --optimize        Optimize table(s) (__all__ for all)'));
  console.log(chalk.yellow('  --help, -h        Show this help\n'));
  process.exit(0);
}

if (!input) {
  console.log(chalk.red('❌ Error: ClickHouse URL or environment file is required'));
  console.log(chalk.yellow('\nUsage: node clickhouse-cli.js <url> [flags]'));
  console.log(chalk.yellow('       node clickhouse-cli.js --help for more info'));
  process.exit(1);
}

// Check if we're in a TTY - ink requires raw mode support (only for interactive mode)
if (!nonInteractiveMode && !process.stdin.isTTY) {
  console.log(chalk.red('❌ Error: Interactive mode requires a TTY'));
  console.log(chalk.yellow('Use --query, --file, --folder, --tables, or --optimize for non-interactive mode'));
  console.log(chalk.yellow('\nExamples:'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --query "SELECT 1"'));
  console.log(chalk.yellow('  node clickhouse-cli.js <url> --tables'));
  console.log(chalk.yellow('  node clickhouse-cli.js --help'));
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

// Non-interactive mode handlers
async function runNonInteractive() {
  try {
    // --query: Execute inline SQL
    if (queryFlag) {
      console.log(chalk.cyan(`Executing query on ${clickhouseConfig.hostname}:${clickhouseConfig.port}/${clickhouseConfig.database}...\n`));
      const result = await executeClickHouseQuery(clickhouseConfig, queryFlag, { max_execution_time: 600 });
      console.log(result);
      process.exit(0);
    }

    // --file: Execute SQL from file
    if (fileFlag) {
      const filePath = fileFlag.startsWith('/') ? fileFlag : join(__dirname, fileFlag);
      if (!existsSync(filePath)) {
        console.log(chalk.red(`❌ Error: File not found: ${filePath}`));
        process.exit(1);
      }
      const content = await readFile(filePath, 'utf-8');
      console.log(chalk.cyan(`Executing ${basename(filePath)} on ${clickhouseConfig.hostname}...\n`));
      const result = await executeClickHouseQuery(clickhouseConfig, content, { max_execution_time: 600 });
      if (result.trim()) console.log(result);
      console.log(chalk.green(`\n✅ Successfully executed ${basename(filePath)}`));
      process.exit(0);
    }

    // --folder: Execute all SQL files in folder
    if (folderFlag) {
      const files = await getSQLFilesInFolder(folderFlag);
      if (files.length === 0) {
        console.log(chalk.red(`❌ Error: No SQL files found in folder: ${folderFlag}`));
        process.exit(1);
      }
      console.log(chalk.cyan(`Executing ${files.length} SQL files from ${folderFlag}...\n`));
      let successCount = 0;
      for (const file of files) {
        const content = await readFile(file.path, 'utf-8');
        console.log(chalk.yellow(`[${successCount + 1}/${files.length}] ${file.name}...`));
        try {
          await executeClickHouseQuery(clickhouseConfig, content, { max_execution_time: 600 });
          console.log(chalk.green(`  ✓ Success`));
          successCount++;
        } catch (err) {
          console.log(chalk.red(`  ✗ Failed: ${err.message}`));
          process.exit(1);
        }
      }
      console.log(chalk.green(`\n✅ Successfully executed ${successCount}/${files.length} files`));
      process.exit(0);
    }

    // --tables: List all tables
    if (tablesFlag) {
      console.log(chalk.cyan(`Tables in ${clickhouseConfig.database}:\n`));
      const tables = await getTables(clickhouseConfig);
      tables.forEach((t, i) => console.log(`  ${i + 1}. ${t}`));
      console.log(chalk.dim(`\nTotal: ${tables.length} tables`));
      process.exit(0);
    }

    // --optimize: Optimize table(s)
    if (optimizeFlag) {
      let tablesToOptimize;
      if (optimizeFlag === '__all__') {
        tablesToOptimize = await getTables(clickhouseConfig);
        console.log(chalk.cyan(`Optimizing all ${tablesToOptimize.length} tables...\n`));
      } else {
        tablesToOptimize = [optimizeFlag];
        console.log(chalk.cyan(`Optimizing table: ${optimizeFlag}...\n`));
      }

      let successCount = 0;
      for (const table of tablesToOptimize) {
        console.log(chalk.yellow(`[${successCount + 1}/${tablesToOptimize.length}] Optimizing ${table}...`));
        try {
          await executeClickHouseQuery(clickhouseConfig, `OPTIMIZE TABLE \`${table}\` FINAL`, { max_execution_time: 600 });
          console.log(chalk.green(`  ✓ Success`));
          successCount++;
        } catch (err) {
          console.log(chalk.red(`  ✗ Failed: ${err.message}`));
        }
      }
      console.log(chalk.green(`\n✅ Optimized ${successCount}/${tablesToOptimize.length} tables`));
      process.exit(0);
    }
  } catch (error) {
    console.log(chalk.red(`❌ Error: ${error.message}`));
    process.exit(1);
  }
}

// Run non-interactive mode or render interactive app
if (nonInteractiveMode) {
  runNonInteractive();
} else {
  render(h(App, { clickhouseConfig, inputType }));
}
