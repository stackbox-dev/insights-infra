/**
 * Logger utilities using winston
 */

import winston from 'winston';
import chalk from 'chalk';

const { combine, timestamp, printf, colorize } = winston.format;

// Custom format for console output
const consoleFormat = printf(({ level, message, timestamp }) => {
  return `${timestamp} - ${level}: ${message}`;
});

export function createLogger(
  logLevel: string = 'INFO',
  logFile?: string
): winston.Logger {
  const transports: winston.transport[] = [
    new winston.transports.Console({
      format: combine(
        colorize(),
        timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        consoleFormat
      ),
    }),
  ];

  if (logFile) {
    transports.push(
      new winston.transports.File({
        filename: logFile,
        format: combine(
          timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
          printf(({ level, message, timestamp }) => {
            return `${timestamp} - ${level.toUpperCase()}: ${message}`;
          })
        ),
      })
    );
  }

  return winston.createLogger({
    level: logLevel.toLowerCase(),
    transports,
  });
}

/**
 * Format error messages for user-friendly display
 */
export function formatSqlError(errorMessage: string, debugMode: boolean = false): string {
  const lines: string[] = [];
  const width = 80;

  // Determine error type
  let errorType = 'SQL Error';
  if (errorMessage.toLowerCase().includes('validation')) {
    errorType = 'SQL Validation Error';
  } else if (errorMessage.toLowerCase().includes('parse')) {
    errorType = 'SQL Parse Error';
  } else if (errorMessage.toLowerCase().includes('table') && errorMessage.toLowerCase().includes('not found')) {
    errorType = 'Table Not Found';
  } else if (errorMessage.toLowerCase().includes('connection')) {
    errorType = 'Connection Error';
  }

  // Top border
  lines.push(chalk.red('╭─ ' + errorType + ' ' + '─'.repeat(width - errorType.length - 4) + '╮'));

  // Error message
  const errorLines = errorMessage.split('\n');
  for (const line of errorLines) {
    const wrapped = wrapText(line, width - 4);
    for (const wrappedLine of wrapped) {
      lines.push(chalk.red('│ ') + wrappedLine.padEnd(width - 4) + chalk.red(' │'));
    }
  }

  // Helpful tips for common errors
  if (!debugMode) {
    lines.push(chalk.red('│ ' + ' '.repeat(width - 4) + ' │'));
    lines.push(chalk.red('│ ') + chalk.yellow('This usually means:').padEnd(width - 4) + chalk.red(' │'));
    lines.push(chalk.red('│ ') + '• Table or column doesn\'t exist'.padEnd(width - 4) + chalk.red(' │'));
    lines.push(chalk.red('│ ') + '• Data type mismatch'.padEnd(width - 4) + chalk.red(' │'));
    lines.push(chalk.red('│ ') + '• Invalid SQL operation for the context'.padEnd(width - 4) + chalk.red(' │'));
    lines.push(chalk.red('│ ' + ' '.repeat(width - 4) + ' │'));
    lines.push(chalk.red('│ ') + chalk.blue('💡 Use --debug for more detailed error information').padEnd(width + 10 - 4) + chalk.red(' │'));
  }

  // Bottom border
  lines.push(chalk.red('╰' + '─'.repeat(width - 2) + '╯'));

  return lines.join('\n');
}

/**
 * Wrap text to specified width
 */
function wrapText(text: string, width: number): string[] {
  const words = text.split(' ');
  const lines: string[] = [];
  let currentLine = '';

  for (const word of words) {
    if ((currentLine + ' ' + word).length <= width) {
      currentLine = currentLine ? currentLine + ' ' + word : word;
    } else {
      if (currentLine) {
        lines.push(currentLine);
      }
      currentLine = word;
    }
  }

  if (currentLine) {
    lines.push(currentLine);
  }

  return lines.length > 0 ? lines : [''];
}
