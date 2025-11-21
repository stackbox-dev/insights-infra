/**
 * SQL parsing utilities
 */

import { ParsedStatement } from '../types.js';

/**
 * Remove comments from SQL content
 */
export function removeComments(sql: string): string {
  // Remove single-line comments (-- comment)
  let result = sql.replace(/--[^\n]*/g, '');

  // Remove multi-line comments (/* comment */)
  result = result.replace(/\/\*[\s\S]*?\*\//g, '');

  return result;
}

/**
 * Split SQL content into individual statements
 * Respects string literals and doesn't split on semicolons inside quotes
 */
export function splitStatements(sql: string): ParsedStatement[] {
  // Remove comments first
  const cleanSql = removeComments(sql);

  const statements: ParsedStatement[] = [];
  let currentStatement = '';
  let inSingleQuote = false;
  let inDoubleQuote = false;
  let statementIndex = 0;

  for (let i = 0; i < cleanSql.length; i++) {
    const char = cleanSql[i];
    const prevChar = i > 0 ? cleanSql[i - 1] : '';

    // Track quote state (ignoring escaped quotes)
    if (char === "'" && prevChar !== '\\') {
      inSingleQuote = !inSingleQuote;
    } else if (char === '"' && prevChar !== '\\') {
      inDoubleQuote = !inDoubleQuote;
    }

    // Check for statement terminator (semicolon outside quotes)
    if (char === ';' && !inSingleQuote && !inDoubleQuote) {
      // End of statement
      const trimmed = currentStatement.trim();
      if (trimmed) {
        statements.push({
          sql: trimmed,
          index: statementIndex++,
        });
      }
      currentStatement = '';
    } else {
      currentStatement += char;
    }
  }

  // Add any remaining statement
  const trimmed = currentStatement.trim();
  if (trimmed) {
    statements.push({
      sql: trimmed,
      index: statementIndex,
    });
  }

  return statements;
}

/**
 * Format SQL for display (truncate if too long)
 */
export function formatSqlPreview(sql: string, maxLength: number = 100): string {
  const oneLine = sql.replace(/\s+/g, ' ').trim();
  if (oneLine.length <= maxLength) {
    return oneLine;
  }
  return oneLine.substring(0, maxLength - 3) + '...';
}
