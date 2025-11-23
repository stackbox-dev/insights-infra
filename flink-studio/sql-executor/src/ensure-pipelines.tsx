#!/usr/bin/env node

/**
 * Interactive Pipeline Manager
 * React-based interactive CLI UI for managing all Flink pipelines
 */

import React, { useState, useEffect } from 'react';
import { render, Box, Text, useInput, useApp } from 'ink';
import SelectInput from 'ink-select-input';
import { Command } from 'commander';
import * as fs from 'fs';
import * as path from 'path';
import { FlinkSQLExecutor } from './lib/flink-sql-executor.js';
import { createLogger } from './utils/logger.js';
import { ExecutorOptions } from './types.js';

const program = new Command();

program
  .name('pipeline-manager')
  .description('Interactive Pipeline Manager - Manage all Flink pipelines')
  .version('2.0.0');

program
  .requiredOption('-e, --env-file <path>', 'Environment file for variable substitution')
  .option('-d, --pipelines-dir <path>', 'Pipelines directory path', 'pipelines')
  .option('-v, --verbose', 'Enable verbose logging (DEBUG level)')
  .option('--log-level <level>', 'Logging level: DEBUG, INFO, WARNING, ERROR', 'INFO')
  .option('-l, --log-file <path>', 'Log file path (optional)')
  .option('--sql-gateway-url <url>', 'Flink SQL Gateway URL')
  .option('--flink-rest-url <url>', 'Flink REST API URL')
  .option('--enable-database', 'Enable operation database for pause/resume')
  .option('--db-path <path>', 'Path to SQLite database', 'flink_jobs.db');

program.parse();

const options = program.opts();

interface PipelineInfo {
  filePath: string;
  fileName: string;
  expectedJobName: string | null;
  jobId?: string;
  status?: string;
  startTime?: number;
  duration?: number;
}

type ViewMode = 'main' | 'pipeline-detail' | 'loading' | 'confirm';

interface AppState {
  mode: ViewMode;
  pipelines: PipelineInfo[];
  selectedPipeline: PipelineInfo | null;
  isRefreshing: boolean;
  message: string | null;
  messageType: 'info' | 'success' | 'error' | 'warning';
  confirmAction: (() => Promise<void>) | null;
  confirmMessage: string;
}

/**
 * Extract pipeline name from SQL file
 */
function extractPipelineName(filePath: string): string | null {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const match = content.match(/SET\s+'pipeline\.name'\s*=\s*'([^']+)'/i);
    return match ? match[1] : null;
  } catch (error) {
    return null;
  }
}

/**
 * Discover all pipeline SQL files
 */
function discoverPipelines(pipelinesDir: string): PipelineInfo[] {
  const pipelines: PipelineInfo[] = [];

  if (!fs.existsSync(pipelinesDir)) {
    throw new Error(`Pipelines directory not found: ${pipelinesDir}`);
  }

  const files = fs.readdirSync(pipelinesDir).sort();

  for (const file of files) {
    if (file.endsWith('.sql')) {
      const filePath = path.join(pipelinesDir, file);
      const expectedJobName = extractPipelineName(filePath);

      pipelines.push({
        filePath,
        fileName: file,
        expectedJobName,
      });
    }
  }

  return pipelines;
}

/**
 * Update pipeline status
 */
async function updatePipelineStatus(
  pipelines: PipelineInfo[],
  executor: FlinkSQLExecutor
): Promise<void> {
  const restClient = executor.getRestClient();
  const allJobs = await restClient.getAllJobs();

  if (!allJobs) {
    return;
  }

  const jobMap = new Map(allJobs.map(job => [job.name, job]));

  for (const pipeline of pipelines) {
    if (pipeline.expectedJobName) {
      const job = jobMap.get(pipeline.expectedJobName);
      if (job) {
        pipeline.jobId = job.jid || job.id;
        pipeline.status = job.state;
        pipeline.startTime = job['start-time'];
        pipeline.duration = job.duration;
      } else {
        pipeline.status = 'NOT_RUNNING';
        pipeline.jobId = undefined;
      }
    } else {
      pipeline.status = 'UNKNOWN';
    }
  }
}

/**
 * Format duration
 */
function formatDuration(ms: number | undefined): string {
  if (!ms) return '—';
  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days}d ${hours % 24}h`;
  if (hours > 0) return `${hours}h ${minutes % 60}m`;
  if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
  return `${seconds}s`;
}

/**
 * Status Badge Component
 */
const StatusBadge: React.FC<{ status?: string }> = ({ status }) => {
  switch (status?.toUpperCase()) {
    case 'RUNNING':
      return <Text color="green">● RUNNING</Text>;
    case 'FAILED':
      return <Text color="red">● FAILED</Text>;
    case 'CANCELED':
    case 'CANCELLED':
      return <Text color="yellow">● CANCELED</Text>;
    case 'FINISHED':
      return <Text color="blue">● FINISHED</Text>;
    case 'NOT_RUNNING':
      return <Text color="gray">○ NOT RUNNING</Text>;
    case 'UNKNOWN':
      return <Text color="red">? UNKNOWN</Text>;
    default:
      return <Text color="white">○ {status || 'UNKNOWN'}</Text>;
  }
};

/**
 * Pipeline Table Row Component
 */
const PipelineRow: React.FC<{ pipeline: PipelineInfo; index: number; isSelected: boolean }> = ({
  pipeline,
  index,
  isSelected,
}) => {
  const pipelineName = pipeline.expectedJobName || '(no name)';
  const startTime = pipeline.startTime
    ? new Date(pipeline.startTime).toLocaleString()
    : '—';
  const duration = pipeline.status === 'RUNNING' ? formatDuration(pipeline.duration) : '—';

  return (
    <Box>
      <Box width={2}>
        <Text color="cyan" bold>{isSelected ? '❯' : ' '}</Text>
      </Box>
      <Box width={4}>
        <Text color={isSelected ? 'cyan' : undefined} bold={isSelected}>{index + 1}.</Text>
      </Box>
      <Box width={43}>
        <Text color={isSelected ? 'cyan' : undefined} bold={isSelected}>
          {pipelineName.substring(0, 41)}
        </Text>
      </Box>
      <Box width={18}>
        <StatusBadge status={pipeline.status} />
      </Box>
      <Box width={22}>
        <Text dimColor={!isSelected} color={isSelected ? 'cyan' : undefined}>
          {startTime}
        </Text>
      </Box>
      <Box width={12}>
        <Text dimColor={!isSelected} color={isSelected ? 'cyan' : undefined}>
          {duration}
        </Text>
      </Box>
    </Box>
  );
};

/**
 * Main Dashboard View
 */
const MainDashboard: React.FC<{
  pipelines: PipelineInfo[];
  onSelectPipeline: (pipeline: PipelineInfo) => void;
  onKillAll: () => void;
  onRefresh: () => void;
  onQuit: () => void;
}> = ({ pipelines, onSelectPipeline, onKillAll, onRefresh, onQuit }) => {
  const [selectedIndex, setSelectedIndex] = useState(0);

  useInput((input, key) => {
    if (key.upArrow && selectedIndex > 0) {
      setSelectedIndex(selectedIndex - 1);
    } else if (key.downArrow && selectedIndex < pipelines.length - 1) {
      setSelectedIndex(selectedIndex + 1);
    } else if (key.return) {
      onSelectPipeline(pipelines[selectedIndex]);
    } else if (input === 'k') {
      onKillAll();
    } else if (input === 'r') {
      onRefresh();
    } else if (input === 'q') {
      onQuit();
    }
  });

  const runningCount = pipelines.filter(p => p.status === 'RUNNING').length;
  const notRunningCount = pipelines.filter(p => p.status === 'NOT_RUNNING').length;

  return (
    <Box flexDirection="column">
      <Box borderStyle="round" borderColor="cyan" paddingX={1}>
        <Text bold color="cyan">
          FLINK PIPELINE MANAGER
        </Text>
      </Box>

      <Box marginTop={1} marginBottom={1}>
        <Box marginRight={4}>
          <Text>
            Total: <Text bold>{pipelines.length}</Text>
          </Text>
        </Box>
        <Box marginRight={4}>
          <Text color="green">
            Running: <Text bold>{runningCount}</Text>
          </Text>
        </Box>
        <Box>
          <Text color="gray">
            Not Running: <Text bold>{notRunningCount}</Text>
          </Text>
        </Box>
      </Box>

      <Box marginBottom={1}>
        <Box width={2}>
          <Text bold color="cyan"> </Text>
        </Box>
        <Box width={4}>
          <Text bold color="cyan">
            #
          </Text>
        </Box>
        <Box width={43}>
          <Text bold color="cyan">
            Pipeline Name
          </Text>
        </Box>
        <Box width={18}>
          <Text bold color="cyan">
            Status
          </Text>
        </Box>
        <Box width={22}>
          <Text bold color="cyan">
            Running Since
          </Text>
        </Box>
        <Box width={12}>
          <Text bold color="cyan">
            Duration
          </Text>
        </Box>
      </Box>

      {pipelines.map((pipeline, index) => (
        <Box key={index}>
          <PipelineRow pipeline={pipeline} index={index} isSelected={index === selectedIndex} />
        </Box>
      ))}

      <Box marginTop={1} flexDirection="column">
        <Text bold>Actions:</Text>
        <Text>
          <Text color="cyan">↑↓</Text> Navigate | <Text color="cyan">Enter</Text> Select |{' '}
          <Text color="red">k</Text> Nuclear Kill All | <Text color="cyan">r</Text> Refresh |{' '}
          <Text color="cyan">q</Text> Quit
        </Text>
      </Box>
    </Box>
  );
};

/**
 * Pipeline Detail View
 */
const PipelineDetail: React.FC<{
  pipeline: PipelineInfo;
  executor: FlinkSQLExecutor;
  onBack: () => void;
  onAction: (action: string) => void;
}> = ({ pipeline, executor, onBack, onAction }) => {
  const isRunning = pipeline.status === 'RUNNING';
  const canStart = pipeline.status === 'NOT_RUNNING' ||
                   pipeline.status === 'CANCELED' ||
                   pipeline.status === 'CANCELLED' ||
                   pipeline.status === 'FAILED' ||
                   pipeline.status === 'FINISHED';

  const actions = [];

  if (isRunning) {
    actions.push({ label: '⏸️  Pause (with savepoint)', value: 'pause' });
    actions.push({ label: '⏹️  Kill (cancel)', value: 'kill' });
    actions.push({ label: '🔄 Restart', value: 'restart' });
    actions.push({ label: 'ℹ️  Show Job Info', value: 'info' });
  } else if (canStart) {
    actions.push({ label: '▶️  Start Pipeline', value: 'start' });
    if (pipeline.jobId) {
      actions.push({ label: 'ℹ️  Show Job Info', value: 'info' });
    }
  }

  actions.push({ label: '◀️  Back to Main Menu', value: 'back' });

  return (
    <Box flexDirection="column">
      <Box borderStyle="round" borderColor="cyan" paddingX={1} marginBottom={1}>
        <Text bold color="cyan">
          PIPELINE DETAILS
        </Text>
      </Box>

      <Box flexDirection="column" marginBottom={1}>
        <Box>
          <Text bold>Name: </Text>
          <Text color="green">{pipeline.expectedJobName || pipeline.fileName}</Text>
        </Box>
        <Box>
          <Text bold>File: </Text>
          <Text dimColor>{pipeline.fileName}</Text>
        </Box>
        <Box>
          <Text bold>Status: </Text>
          <StatusBadge status={pipeline.status} />
        </Box>
        {pipeline.jobId && (
          <Box>
            <Text bold>Job ID: </Text>
            <Text dimColor>{pipeline.jobId}</Text>
          </Box>
        )}
        {pipeline.startTime && (
          <Box>
            <Text bold>Started: </Text>
            <Text dimColor>{new Date(pipeline.startTime).toLocaleString()}</Text>
          </Box>
        )}
        {isRunning && (
          <Box>
            <Text bold>Duration: </Text>
            <Text dimColor>{formatDuration(pipeline.duration)}</Text>
          </Box>
        )}
      </Box>

      <Box marginBottom={1}>
        <Text bold>Select an action:</Text>
      </Box>

      <SelectInput
        items={actions}
        onSelect={(item) => {
          if (item.value === 'back') {
            onBack();
          } else {
            onAction(item.value);
          }
        }}
      />
    </Box>
  );
};

/**
 * Loading View
 */
const LoadingView: React.FC<{ message: string }> = ({ message }) => {
  return (
    <Box flexDirection="column">
      <Text color="blue">⏳ {message}</Text>
    </Box>
  );
};

/**
 * Message View
 */
const MessageView: React.FC<{
  message: string;
  type: 'info' | 'success' | 'error' | 'warning';
  onDismiss: () => void;
}> = ({ message, type, onDismiss }) => {
  useInput((input) => {
    if (input) {
      onDismiss();
    }
  });

  const color =
    type === 'success'
      ? 'green'
      : type === 'error'
      ? 'red'
      : type === 'warning'
      ? 'yellow'
      : 'blue';
  const icon =
    type === 'success' ? '✅' : type === 'error' ? '❌' : type === 'warning' ? '⚠️' : 'ℹ️';

  return (
    <Box flexDirection="column">
      <Box marginBottom={1}>
        <Text color={color}>
          {icon} {message}
        </Text>
      </Box>
      <Text dimColor>Press any key to continue...</Text>
    </Box>
  );
};

/**
 * Confirm Dialog
 */
const ConfirmDialog: React.FC<{
  message: string;
  onConfirm: () => void;
  onCancel: () => void;
}> = ({ message, onConfirm, onCancel }) => {
  const items = [
    { label: '✓ Yes', value: 'yes' },
    { label: '✗ No', value: 'no' },
  ];

  const isNuclear = message.includes('NUCLEAR');
  const color = isNuclear ? 'red' : 'yellow';

  return (
    <Box flexDirection="column">
      <Box marginBottom={1}>
        <Text color={color} bold={isNuclear}>{message}</Text>
      </Box>
      <SelectInput
        items={items}
        onSelect={(item) => {
          if (item.value === 'yes') {
            onConfirm();
          } else {
            onCancel();
          }
        }}
      />
    </Box>
  );
};

/**
 * Main App Component
 */
const App: React.FC<{ executor: FlinkSQLExecutor; pipelines: PipelineInfo[] }> = ({
  executor,
  pipelines: initialPipelines,
}) => {
  const { exit } = useApp();
  const [state, setState] = useState<AppState>({
    mode: 'main',
    pipelines: initialPipelines,
    selectedPipeline: null,
    isRefreshing: false,
    message: null,
    messageType: 'info',
    confirmAction: null,
    confirmMessage: '',
  });

  const refreshPipelines = async () => {
    setState((s) => ({ ...s, mode: 'loading', isRefreshing: true }));
    await updatePipelineStatus(state.pipelines, executor);
    setState((s) => ({ ...s, mode: 'main', isRefreshing: false }));
  };

  const showMessage = (message: string, type: 'info' | 'success' | 'error' | 'warning') => {
    setState((s) => ({ ...s, mode: 'loading', message, messageType: type }));
  };

  const startPipeline = async (pipeline: PipelineInfo) => {
    showMessage(`Starting pipeline: ${pipeline.expectedJobName}...`, 'info');
    try {
      const results = await executor.executeFromFile(pipeline.filePath, false, false);
      const success = results.every((r) => r.success);
      if (success) {
        await refreshPipelines();
        showMessage('Pipeline started successfully', 'success');
      } else {
        showMessage('Failed to start pipeline', 'error');
      }
    } catch (error: any) {
      showMessage(`Error: ${error.message}`, 'error');
    }
  };

  const killPipeline = async (pipeline: PipelineInfo) => {
    if (!pipeline.jobId) {
      showMessage('No job ID found', 'error');
      return;
    }
    showMessage(`Killing pipeline: ${pipeline.expectedJobName}...`, 'info');
    const restClient = executor.getRestClient();
    const success = await restClient.cancelJob(pipeline.jobId);
    if (success) {
      await refreshPipelines();
      showMessage('Pipeline killed successfully', 'success');
    } else {
      showMessage('Failed to kill pipeline', 'error');
    }
  };

  const pausePipeline = async (pipeline: PipelineInfo) => {
    if (!pipeline.jobId) {
      showMessage('No job ID found', 'error');
      return;
    }
    const jobManager = executor.getJobManager();
    if (!jobManager) {
      showMessage('Database not enabled. Use --enable-database', 'error');
      return;
    }
    showMessage(`Pausing pipeline: ${pipeline.expectedJobName}...`, 'info');
    const success = await jobManager.pauseJob(pipeline.jobId);
    if (success) {
      await refreshPipelines();
      showMessage('Pipeline paused successfully', 'success');
    } else {
      showMessage('Failed to pause pipeline', 'error');
    }
  };

  const restartPipeline = async (pipeline: PipelineInfo) => {
    showMessage(`Restarting pipeline: ${pipeline.expectedJobName}...`, 'info');
    await killPipeline(pipeline);
    await new Promise((resolve) => setTimeout(resolve, 2000));
    await startPipeline(pipeline);
  };

  const showJobInfo = async (pipeline: PipelineInfo) => {
    if (!pipeline.jobId) {
      showMessage('No job ID found', 'error');
      return;
    }
    const restClient = executor.getRestClient();
    const jobDetails = await restClient.getJobDetails(pipeline.jobId);
    if (jobDetails) {
      console.log('\n' + JSON.stringify(jobDetails, null, 2) + '\n');
      showMessage('Job details printed to console', 'info');
    } else {
      showMessage('Failed to get job details', 'error');
    }
  };

  const killAllRunning = async () => {
    const running = state.pipelines.filter(
      (p) => p.status === 'RUNNING' && p.jobId
    );
    if (running.length === 0) {
      showMessage('No running pipelines to kill', 'info');
      return;
    }
    showMessage(`Killing ${running.length} pipeline(s)...`, 'info');
    const restClient = executor.getRestClient();
    let successCount = 0;
    let failCount = 0;
    for (const pipeline of running) {
      if (pipeline.jobId) {
        const success = await restClient.cancelJob(pipeline.jobId);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
    }
    await refreshPipelines();
    if (failCount > 0) {
      showMessage(`Killed ${successCount} pipeline(s), ${failCount} failed`, 'warning');
    } else {
      showMessage(`Successfully killed all ${successCount} pipeline(s)`, 'success');
    }
  };

  const handlePipelineAction = (action: string) => {
    const pipeline = state.selectedPipeline!;

    switch (action) {
      case 'start':
        startPipeline(pipeline);
        break;
      case 'kill':
        setState((s) => ({
          ...s,
          mode: 'confirm',
          confirmMessage: 'Are you sure you want to kill this pipeline?',
          confirmAction: () => killPipeline(pipeline),
        }));
        break;
      case 'pause':
        pausePipeline(pipeline);
        break;
      case 'restart':
        setState((s) => ({
          ...s,
          mode: 'confirm',
          confirmMessage: 'Are you sure you want to restart this pipeline?',
          confirmAction: () => restartPipeline(pipeline),
        }));
        break;
      case 'info':
        showJobInfo(pipeline);
        break;
    }
  };

  useEffect(() => {
    refreshPipelines();
  }, []);

  if (state.mode === 'loading' && state.isRefreshing) {
    return <LoadingView message="Refreshing pipeline status..." />;
  }

  if (state.mode === 'loading' && state.message) {
    return (
      <MessageView
        message={state.message}
        type={state.messageType}
        onDismiss={() => {
          setState((s) => ({
            ...s,
            mode: state.selectedPipeline ? 'pipeline-detail' : 'main',
            message: null,
          }));
        }}
      />
    );
  }

  if (state.mode === 'confirm' && state.confirmAction) {
    return (
      <ConfirmDialog
        message={state.confirmMessage}
        onConfirm={() => {
          const action = state.confirmAction!;
          setState((s) => ({ ...s, mode: 'main', confirmAction: null }));
          action();
        }}
        onCancel={() => {
          setState((s) => ({
            ...s,
            mode: 'pipeline-detail',
            confirmAction: null,
          }));
        }}
      />
    );
  }

  if (state.mode === 'pipeline-detail' && state.selectedPipeline) {
    return (
      <PipelineDetail
        pipeline={state.selectedPipeline}
        executor={executor}
        onBack={() => {
          setState((s) => ({ ...s, mode: 'main', selectedPipeline: null }));
        }}
        onAction={handlePipelineAction}
      />
    );
  }

  return (
    <MainDashboard
      pipelines={state.pipelines}
      onSelectPipeline={(pipeline) => {
        setState((s) => ({ ...s, mode: 'pipeline-detail', selectedPipeline: pipeline }));
      }}
      onKillAll={() => {
        const running = state.pipelines.filter((p) => p.status === 'RUNNING');
        if (running.length === 0) {
          showMessage('No running pipelines to kill', 'info');
          return;
        }
        setState((s) => ({
          ...s,
          mode: 'confirm',
          confirmMessage: `⚠️  NUCLEAR OPTION: Kill ALL ${running.length} running pipeline(s)?`,
          confirmAction: killAllRunning,
        }));
      }}
      onRefresh={refreshPipelines}
      onQuit={() => exit()}
    />
  );
};

/**
 * Main entry point
 */
async function main() {
  try {
    // Setup logger
    const logLevel = options.verbose ? 'DEBUG' : options.logLevel || 'INFO';
    const logger = createLogger(logLevel, options.logFile);

    // Resolve pipelines directory
    const pipelinesDir = path.resolve(options.pipelinesDir);

    // Discover all pipeline files
    const pipelines = discoverPipelines(pipelinesDir);

    if (pipelines.length === 0) {
      console.log('No pipeline SQL files found');
      process.exit(0);
    }

    // Create executor
    const executor = new FlinkSQLExecutor(options as ExecutorOptions, logger);

    // Initialize database if needed
    if (options.enableDatabase) {
      executor.initializeDatabase(true, options.dbPath);
    }

    // Render the app
    const { waitUntilExit } = render(<App executor={executor} pipelines={pipelines} />);
    await waitUntilExit();

    // Cleanup
    await executor.cleanup();
  } catch (error: any) {
    console.error(`\n❌ Error: ${error.message}`);
    if (options.verbose) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();
