import React, { useState, useEffect, createElement as h } from 'react';
import { Box, Text, useInput, useApp } from 'ink';
import Spinner from 'ink-spinner';
import SelectInput from 'ink-select-input';
import chalk from 'chalk';
import { formatDistanceToNow } from 'date-fns';

const VIEWS = {
  CONNECTOR_LIST: 'connector_list',
  CONNECTOR_DETAIL: 'connector_detail',
  DEPLOY: 'deploy'
};

export function ConnectorManagerUI({ client, env, sinkConfigurations, buildConfig }) {
  const { exit } = useApp();
  const [view, setView] = useState(VIEWS.CONNECTOR_LIST);
  const [connectors, setConnectors] = useState([]);
  const [selectedConnector, setSelectedConnector] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [lastUpdate, setLastUpdate] = useState(new Date());
  const [drifts, setDrifts] = useState({});

  // Detect configuration drift and return details
  const detectDrift = (connector) => {
    // Extract sink name from connector name
    // Format: clickhouse-connect-{TOPIC_PREFIX}-{sink-name}
    const prefix = `clickhouse-connect-${process.env.TOPIC_PREFIX}-`;
    if (!connector.name.startsWith(prefix)) return null;

    const sinkName = connector.name.substring(prefix.length);
    const localConfig = sinkConfigurations[sinkName];

    if (!localConfig) return null;

    const expectedConfig = buildConfig(localConfig);
    const deployedConfig = connector.config;

    // Compare key configuration fields
    const keyFields = ['topics', 'topic2TableMap', 'tasks.max', 'hostname', 'port', 'database'];
    const driftDetails = [];

    for (const field of keyFields) {
      const expectedValue = String(expectedConfig[field] || '');
      const deployedValue = String(deployedConfig[field] || '');

      if (expectedValue !== deployedValue) {
        driftDetails.push({
          field,
          expected: expectedValue,
          deployed: deployedValue
        });
      }
    }

    return driftDetails.length > 0 ? driftDetails : null;
  };

  const fetchConnectors = async () => {
    setLoading(true);
    setError(null);
    try {
      const statuses = await client.getAllConnectorsStatus();

      // Detect drifts
      const driftMap = {};
      statuses.forEach(connector => {
        driftMap[connector.name] = detectDrift(connector);
      });
      setDrifts(driftMap);

      setConnectors(statuses);
      setLastUpdate(new Date());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConnectors();
    const interval = setInterval(fetchConnectors, 5000);
    return () => clearInterval(interval);
  }, []);

  useInput((input, key) => {
    if (input === 'q' || (key.ctrl && input === 'c')) {
      exit();
    }
    if (input === 'r') {
      fetchConnectors();
    }
    if (key.escape && view !== VIEWS.CONNECTOR_LIST) {
      setView(VIEWS.CONNECTOR_LIST);
      setSelectedConnector(null);
    }
  });

  const handleConnectorSelect = (item) => {
    const connector = connectors.find(c => c.name === item.value);
    setSelectedConnector(connector);
    setView(VIEWS.CONNECTOR_DETAIL);
  };

  const handleAction = async (action, connectorName) => {
    setLoading(true);
    setError(null);
    try {
      switch (action) {
        case 'restart':
          await client.restartConnector(connectorName);
          break;
        case 'pause':
          await client.pauseConnector(connectorName);
          break;
        case 'resume':
          await client.resumeConnector(connectorName);
          break;
        case 'delete':
          await client.deleteConnector(connectorName);
          setView(VIEWS.CONNECTOR_LIST);
          setSelectedConnector(null);
          break;
      }
      await fetchConnectors();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDeploy = async (sinkName) => {
    setLoading(true);
    setError(null);
    try {
      const sinkConfig = sinkConfigurations[sinkName];
      const connectorName = `clickhouse-connect-${process.env.TOPIC_PREFIX}-${sinkName}`;
      const config = buildConfig(sinkConfig);

      await client.createOrUpdateConnector(connectorName, config);
      await fetchConnectors();
      setView(VIEWS.CONNECTOR_LIST);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (view === VIEWS.CONNECTOR_LIST) {
    return h(ConnectorList, {
      connectors,
      loading,
      error,
      lastUpdate,
      drifts,
      onSelect: handleConnectorSelect,
      onDeploy: () => setView(VIEWS.DEPLOY),
      onRefresh: fetchConnectors
    });
  }

  if (view === VIEWS.CONNECTOR_DETAIL && selectedConnector) {
    const driftDetails = drifts[selectedConnector.name];
    return h(ConnectorDetail, {
      connector: selectedConnector,
      driftDetails,
      onBack: () => setView(VIEWS.CONNECTOR_LIST),
      onAction: handleAction,
      onRedeploy: async () => {
        // Extract sink name and re-deploy
        const prefix = `clickhouse-connect-${process.env.TOPIC_PREFIX}-`;
        const sinkName = selectedConnector.name.substring(prefix.length);
        await handleDeploy(sinkName);
      },
      loading,
      error
    });
  }

  if (view === VIEWS.DEPLOY) {
    return h(DeployView, {
      sinkConfigurations,
      connectors,
      onDeploy: handleDeploy,
      onBack: () => setView(VIEWS.CONNECTOR_LIST),
      loading,
      error
    });
  }

  return h(Text, null, 'Unknown view');
}

function Header({ title, lastUpdate }) {
  return h(Box, { flexDirection: 'column', marginBottom: 1 },
    h(Box, { borderStyle: 'double', borderColor: 'cyan', paddingX: 2, paddingY: 0 },
      h(Text, { bold: true, color: 'cyan' }, title)
    ),
    h(Box, null,
      h(Text, { dimColor: true },
        `Last updated: ${formatDistanceToNow(lastUpdate, { addSuffix: true })} | `,
        h(Text, { bold: true }, 'r'),
        ' to refresh, ',
        h(Text, { bold: true }, 'ESC'),
        ' to go back, ',
        h(Text, { bold: true }, 'q'),
        ' to quit'
      )
    )
  );
}

function ConnectorList({ connectors, loading, error, lastUpdate, drifts, onSelect, onDeploy }) {
  const items = [
    { label: chalk.green('➕ Deploy New Connector'), value: '__deploy__' },
    { label: chalk.gray('─'.repeat(50)), value: '__separator__', disabled: true },
    ...connectors.map(c => ({
      label: formatConnectorItem(c, drifts[c.name]),
      value: c.name
    }))
  ];

  const handleSelect = (item) => {
    if (item.value === '__deploy__') {
      onDeploy();
    } else if (item.value !== '__separator__') {
      onSelect(item);
    }
  };

  const running = connectors.filter(c => c.connector?.state === 'RUNNING').length;
  const paused = connectors.filter(c => c.connector?.state === 'PAUSED').length;
  const failed = connectors.filter(c => c.connector?.state === 'FAILED').length;

  return h(Box, { flexDirection: 'column' },
    h(Header, { title: `ClickHouse Sink Connectors (${process.env.TOPIC_PREFIX})`, lastUpdate }),
    error && h(Box, { marginBottom: 1 },
      h(Text, { color: 'red' }, `Error: ${error}`)
    ),
    loading && h(Box, null,
      h(Text, { color: 'green' }, h(Spinner, { type: 'dots' }), ' Loading connectors...')
    ),
    !loading && h(SelectInput, { items, onSelect: handleSelect }),
    h(Box, { marginTop: 1 },
      h(Text, { dimColor: true },
        `Total: ${connectors.length} connectors | Running: ${running} | Paused: ${paused} | Failed: ${failed}`
      )
    )
  );
}

function formatConnectorItem(connector, driftDetails) {
  const state = connector.connector?.state || 'UNKNOWN';
  const icon = getStateIcon(state);
  const color = getStateColor(state);
  const failedTasks = connector.tasks?.filter(t => t.state === 'FAILED').length || 0;
  const taskInfo = connector.tasks?.length > 0
    ? ` [${connector.tasks.length} tasks${failedTasks > 0 ? `, ${failedTasks} failed` : ''}]`
    : '';
  const driftIndicator = driftDetails && driftDetails.length > 0 ? chalk.yellow(' ⚠ DRIFT') : '';
  return `${icon} ${chalk[color](connector.name)} ${chalk.dim(state)}${chalk.yellow(taskInfo)}${driftIndicator}`;
}

function getStateIcon(state) {
  switch (state) {
    case 'RUNNING': return '●';
    case 'PAUSED': return '❚❚';
    case 'FAILED': return '✗';
    default: return '○';
  }
}

function getStateColor(state) {
  switch (state) {
    case 'RUNNING': return 'green';
    case 'PAUSED': return 'yellow';
    case 'FAILED': return 'red';
    default: return 'gray';
  }
}

function ConnectorDetail({ connector, driftDetails, onBack, onAction, onRedeploy, loading, error }) {
  const [selectedAction, setSelectedAction] = useState(null);
  const state = connector.connector?.state || 'UNKNOWN';
  const hasDrift = driftDetails && driftDetails.length > 0;

  const actions = [
    { label: '← Back to List', value: 'back' },
    { label: chalk.gray('─'.repeat(50)), value: '__separator__', disabled: true },
    ...(hasDrift ? [{ label: chalk.yellow('⚠️  Re-deploy (Config Drift Detected)'), value: 'redeploy' }] : []),
    { label: '🔄 Restart Connector', value: 'restart' },
    state === 'RUNNING'
      ? { label: '⏸  Pause Connector', value: 'pause' }
      : { label: '▶️  Resume Connector', value: 'resume' },
    { label: '🗑️  Delete Connector', value: 'delete' }
  ];

  const handleAction = (item) => {
    if (item.value === 'back') {
      onBack();
    } else if (item.value === 'redeploy') {
      setSelectedAction('redeploy');
      onRedeploy();
    } else if (item.value !== '__separator__') {
      setSelectedAction(item.value);
      onAction(item.value, connector.name);
    }
  };

  return h(Box, { flexDirection: 'column' },
    h(Box, { borderStyle: 'round', borderColor: 'cyan', paddingX: 2, paddingY: 1, marginBottom: 1 },
      h(Box, { flexDirection: 'column' },
        h(Text, { bold: true, color: 'cyan' }, connector.name),
        h(Text, null, 'Status: ', h(Text, { color: getStateColor(state) }, state)),
        h(Text, { dimColor: true }, `Worker: ${connector.connector?.worker_id || 'N/A'}`)
      )
    ),
    hasDrift && h(Box, { flexDirection: 'column', marginBottom: 1, borderStyle: 'single', borderColor: 'yellow', paddingX: 1 },
      h(Text, { bold: true, color: 'yellow' }, `⚠️  Configuration Drift Detected (${driftDetails.length} field${driftDetails.length > 1 ? 's' : ''})`),
      h(Text, { dimColor: true, marginBottom: 1 }, 'The deployed configuration differs from the local configuration:'),
      ...driftDetails.map((drift, i) => {
        const isLongValue = drift.expected.length > 50 || drift.deployed.length > 50;
        if (isLongValue) {
          return h(Box, { key: i, flexDirection: 'column', marginLeft: 2, marginBottom: 1 },
            h(Text, { bold: true }, drift.field + ':'),
            h(Text, { dimColor: true }, '  Expected: ' + (drift.expected.substring(0, 80) + (drift.expected.length > 80 ? '...' : ''))),
            h(Text, { dimColor: true }, '  Deployed: ' + (drift.deployed.substring(0, 80) + (drift.deployed.length > 80 ? '...' : '')))
          );
        } else {
          return h(Box, { key: i, flexDirection: 'column', marginLeft: 2 },
            h(Text, null,
              h(Text, { bold: true }, drift.field + ': '),
              h(Text, { color: 'green' }, drift.expected),
              h(Text, { dimColor: true }, ' → '),
              h(Text, { color: 'red' }, drift.deployed)
            )
          );
        }
      }),
      h(Text, { dimColor: true, marginTop: 1 }, 'Select "Re-deploy" below to sync with local config.')
    ),
    error && h(Box, { marginBottom: 1 },
      h(Text, { color: 'red' }, `Error: ${error}`)
    ),
    connector.tasks && connector.tasks.length > 0 && h(Box, { flexDirection: 'column', marginBottom: 1 },
      h(Text, { bold: true, underline: true }, 'Tasks:'),
      ...connector.tasks.map((task, i) =>
        h(Box, { key: i, marginLeft: 2 },
          h(Text, null,
            `Task ${task.id}: `,
            h(Text, { color: getStateColor(task.state) }, task.state),
            ' ',
            h(Text, { dimColor: true }, task.worker_id)
          )
        )
      )
    ),
    connector.connector?.trace && h(Box, { flexDirection: 'column', marginBottom: 1, borderStyle: 'single', borderColor: 'red', paddingX: 1 },
      h(Text, { bold: true, color: 'red' }, 'Error Trace:'),
      h(Text, null, connector.connector.trace.substring(0, 200) + '...')
    ),
    loading && selectedAction && h(Box, { marginBottom: 1 },
      h(Text, { color: 'green' }, h(Spinner, { type: 'dots' }), ` Executing ${selectedAction}...`)
    ),
    h(Box, { flexDirection: 'column' },
      h(Text, { bold: true }, 'Actions:'),
      h(SelectInput, { items: actions, onSelect: handleAction })
    )
  );
}

function DeployView({ sinkConfigurations, connectors, onDeploy, onBack, loading, error }) {
  const [selectedSinks, setSelectedSinks] = useState(new Set());
  const [mode, setMode] = useState('select'); // 'select' or 'confirm'

  // Get deployed sink names
  const deployedSinkNames = new Set(
    connectors.map(c => {
      const prefix = `clickhouse-connect-${process.env.TOPIC_PREFIX}-`;
      if (c.name.startsWith(prefix)) {
        return c.name.substring(prefix.length);
      }
      return null;
    }).filter(name => name !== null)
  );

  // Filter out already deployed sinks
  const availableSinkNames = Object.keys(sinkConfigurations).filter(
    name => !deployedSinkNames.has(name)
  );

  const sinkNames = availableSinkNames;

  const selectItems = [
    { label: '← Back to List', value: '__back__' },
    { label: chalk.gray('─'.repeat(50)), value: '__separator__', disabled: true },
    { label: chalk.green('✓ Deploy Selected Sinks'), value: '__deploy__' },
    { label: chalk.gray('─'.repeat(50)), value: '__separator2__', disabled: true },
    ...sinkNames.map(name => ({
      label: selectedSinks.has(name) ? `☑ ${name}` : `☐ ${name}`,
      value: name
    }))
  ];

  const handleSelect = (item) => {
    if (item.value === '__back__') {
      onBack();
    } else if (item.value === '__deploy__') {
      if (selectedSinks.size > 0) {
        setMode('confirm');
      }
    } else if (!item.value.startsWith('__')) {
      const newSelected = new Set(selectedSinks);
      if (newSelected.has(item.value)) {
        newSelected.delete(item.value);
      } else {
        newSelected.add(item.value);
      }
      setSelectedSinks(newSelected);
    }
  };

  const confirmItems = [
    { label: '← Back to Selection', value: '__back__' },
    { label: chalk.gray('─'.repeat(50)), value: '__separator__', disabled: true },
    { label: chalk.green.bold(`✓ Confirm Deploy (${selectedSinks.size} sinks)`), value: '__confirm__' },
    { label: chalk.gray('─'.repeat(50)), value: '__separator2__', disabled: true },
    ...Array.from(selectedSinks).map(name => ({
      label: `  → ${name}`,
      value: name,
      disabled: true
    }))
  ];

  const handleConfirm = (item) => {
    if (item.value === '__back__') {
      setMode('select');
    } else if (item.value === '__confirm__') {
      // Deploy all selected sinks
      Array.from(selectedSinks).forEach(name => onDeploy(name));
      setSelectedSinks(new Set());
      setMode('select');
    }
  };

  const title = mode === 'select' ? 'Deploy Connector - Select Sinks' : 'Deploy Connector - Confirm';
  const description = mode === 'select'
    ? 'Select one or more sinks to deploy (press Enter to toggle selection):'
    : `Review and confirm deployment of ${selectedSinks.size} sink(s):`;
  const items = mode === 'select' ? selectItems : confirmItems;
  const onSelect = mode === 'select' ? handleSelect : handleConfirm;

  // Show message when all sinks are deployed
  if (sinkNames.length === 0) {
    return h(Box, { flexDirection: 'column' },
      h(Box, { borderStyle: 'double', borderColor: 'green', paddingX: 2, paddingY: 0, marginBottom: 1 },
        h(Text, { bold: true, color: 'green' }, title)
      ),
      h(Box, { flexDirection: 'column', marginBottom: 1 },
        h(Text, { color: 'yellow' }, 'All configured sinks are already deployed!'),
        h(Text, { dimColor: true }, `Total configured: ${Object.keys(sinkConfigurations).length} | Already deployed: ${deployedSinkNames.size}`)
      ),
      h(Box, { flexDirection: 'column' },
        h(SelectInput, {
          items: [{ label: '← Back to List', value: '__back__' }],
          onSelect: () => onBack()
        })
      )
    );
  }

  return h(Box, { flexDirection: 'column' },
    h(Box, { borderStyle: 'double', borderColor: 'green', paddingX: 2, paddingY: 0, marginBottom: 1 },
      h(Text, { bold: true, color: 'green' }, title)
    ),
    error && h(Box, { marginBottom: 1 },
      h(Text, { color: 'red' }, `Error: ${error}`)
    ),
    loading && h(Box, { marginBottom: 1 },
      h(Text, { color: 'green' }, h(Spinner, { type: 'dots' }), ' Deploying connector...')
    ),
    h(Box, { flexDirection: 'column' },
      h(Text, { dimColor: true, marginBottom: 1 }, description),
      h(SelectInput, { items, onSelect })
    ),
    mode === 'select' && h(Box, { marginTop: 1 },
      h(Text, { dimColor: true },
        `Available: ${sinkNames.length} sinks | Already deployed: ${deployedSinkNames.size} | Selected: ${selectedSinks.size}`
      )
    )
  );
}
