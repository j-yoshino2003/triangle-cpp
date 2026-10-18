#!/usr/bin/env node
'use strict';
/**
 * Shared helpers for the p4-harness hooks: read the hook payload, find every
 * `p4` invocation in a shell command string, and pull out the subcommand,
 * its arguments, and the changelist it targets.
 */

const MAX_STDIN = 1024 * 1024;

// Global p4 options that consume the next token (p4 [global options] command [args]).
const GLOBAL_OPTIONS_WITH_VALUE = new Set([
  '-c', '-C', '-d', '-H', '-L', '-p', '-P', '-Q', '-u', '-x', '-z',
]);

// シェル経由で p4 を起動するラッパー. `bash -c "p4 submit"` のように、引用符の中身が
// 1 トークンになる形は、そのまま走査しても p4 呼び出しとして検出できない。
// ラッパーに渡されたスクリプト文字列を取り出して、再帰的に走査する。
const SHELL_WRAPPERS = new Set([
  'bash', 'sh', 'zsh', 'dash', 'ksh', 'ash', 'busybox',
  'cmd', 'command', 'powershell', 'pwsh',
  'env', 'nohup', 'sudo', 'doas', 'time', 'timeout', 'xargs', 'winpty', 'script',
]);

// ラッパーの「次のトークンがスクリプト本文」になるオプション.
const INLINE_SCRIPT_FLAGS = new Set([
  '-c', '--command', '/c', '/C', '/k', '/K',
  '-command', '-Command', '-encodedcommand', '-EncodedCommand',
]);

// 入れ子の展開はこの深さで打ち切る（`bash -c "bash -c ..."` の無限展開を避けるため）.
const MAX_WRAPPER_DEPTH = 4;

/**
 * Strip the shell punctuation that can cling to a token so that `(p4` and
 * `submit)` compare equal to `p4` and `submit`.
 */
function bareToken(token) {
  return String(token || '')
    .replace(/^[(){}`$;&|<>]+/, '')
    .replace(/[(){}`;&|<>]+$/, '');
}

/**
 * Extract the command string from the hook payload (JSON or plain text).
 */
function extractCommand(rawInput) {
  const trimmed = String(rawInput || '').trim();
  if (!trimmed.startsWith('{')) return trimmed;
  try {
    const parsed = JSON.parse(trimmed);
    const cmd = parsed && parsed.tool_input && parsed.tool_input.command;
    return typeof cmd === 'string' ? cmd : trimmed;
  } catch {
    return trimmed;
  }
}

/**
 * Extract the tool output string from a PostToolUse payload.
 */
function extractOutput(rawInput) {
  try {
    const parsed = JSON.parse(String(rawInput || ''));
    const out = parsed && parsed.tool_output;
    if (typeof out === 'string') return out;
    if (out && typeof out.output === 'string') return out.output;
    if (out && typeof out.stdout === 'string') return out.stdout;
  } catch {
    // fall through
  }
  return '';
}

/**
 * Split a command string into segments on ; | & and newlines (outside quotes).
 */
function splitSegments(input) {
  const segments = [];
  let current = '';
  let quote = null;
  let escaped = false;

  for (const char of input) {
    if (escaped) {
      current += char;
      escaped = false;
      continue;
    }
    if (quote) {
      if (char === quote) quote = null;
      else if (quote === '"' && char === '\\') escaped = true;
      current += char;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      current += char;
      continue;
    }
    if (char === '\\') {
      escaped = true;
      current += char;
      continue;
    }
    if (char === ';' || char === '|' || char === '&' || char === '\n') {
      if (current.trim()) segments.push(current.trim());
      current = '';
      continue;
    }
    current += char;
  }
  if (current.trim()) segments.push(current.trim());
  return segments;
}

/**
 * Tokenize one segment into shell words (quote and backslash aware).
 */
function tokenize(segment) {
  const tokens = [];
  let value = '';
  let inToken = false;
  let quote = null;
  let escaped = false;

  for (const char of segment) {
    if (escaped) {
      value += char;
      inToken = true;
      escaped = false;
      continue;
    }
    if (quote) {
      if (char === quote) {
        quote = null;
      } else if (quote === '"' && char === '\\') {
        escaped = true;
      } else {
        value += char;
      }
      inToken = true;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      inToken = true;
      continue;
    }
    if (char === '\\') {
      escaped = true;
      continue;
    }
    if (/\s/.test(char)) {
      if (inToken) tokens.push(value);
      value = '';
      inToken = false;
      continue;
    }
    value += char;
    inToken = true;
  }
  if (inToken) tokens.push(value);
  return tokens;
}

function isP4Token(token) {
  const base = bareToken(token).replace(/^.*[\\/]/, '').toLowerCase();
  return base === 'p4' || base === 'p4.exe';
}

function isShellWrapperToken(token) {
  const base = bareToken(token).replace(/^.*[\\/]/, '').toLowerCase();
  return SHELL_WRAPPERS.has(base) || SHELL_WRAPPERS.has(base.replace(/\.exe$/, ''));
}

/**
 * Collect the inline scripts handed to shell wrappers inside one segment,
 * e.g. the `p4 submit` in `bash -c "p4 submit"`.
 */
function collectInlineScripts(tokens) {
  const scripts = [];

  for (let i = 0; i < tokens.length; i += 1) {
    if (!isShellWrapperToken(tokens[i])) continue;

    for (let j = i + 1; j < tokens.length; j += 1) {
      if (!INLINE_SCRIPT_FLAGS.has(tokens[j])) continue;
      const script = tokens[j + 1];
      if (typeof script === 'string' && script.trim()) scripts.push(script);
    }
  }

  return scripts;
}

/**
 * Find every p4 invocation in a command string.
 * Returns [{ subcommand, args, globals: { port, client, user } }].
 */
function findP4Invocations(command, depth = 0) {
  const invocations = [];
  if (depth > MAX_WRAPPER_DEPTH) return invocations;

  for (const segment of splitSegments(command)) {
    if (segment.trim().startsWith('#')) continue;
    const tokens = tokenize(segment);

    // ラッパーに渡されたスクリプト本文を先に展開する.
    for (const script of collectInlineScripts(tokens)) {
      invocations.push(...findP4Invocations(script, depth + 1));
    }

    const index = tokens.findIndex(isP4Token);
    if (index === -1) continue;

    const globals = {};
    let i = index + 1;
    while (i < tokens.length && tokens[i].startsWith('-')) {
      const option = tokens[i];
      if (GLOBAL_OPTIONS_WITH_VALUE.has(option)) {
        const value = tokens[i + 1];
        if (option === '-p') globals.port = value;
        if (option === '-c') globals.client = value;
        if (option === '-u') globals.user = value;
        i += 2;
        continue;
      }
      i += 1;
    }
    if (i >= tokens.length) continue;

    invocations.push({
      subcommand: bareToken(tokens[i]).toLowerCase(),
      args: tokens.slice(i + 1),
      globals,
    });
  }

  return invocations;
}

/**
 * Changelist targeted by the arguments: `-c N`, or a bare positional number.
 * Returns the number as a string, 'default' when nothing is given, or null when
 * the value is not a changelist number.
 */
function extractChangelist(args) {
  const index = args.indexOf('-c');
  if (index !== -1) {
    const value = args[index + 1];
    if (value === 'default') return 'default';
    return /^\d+$/.test(value || '') ? value : null;
  }
  const positional = args.find(arg => /^\d+$/.test(arg));
  return positional || 'default';
}

function hasFlag(args, ...flags) {
  return args.some(arg => flags.includes(arg));
}

/**
 * Read all of stdin (capped) and hand it to the callback.
 */
function readStdin(callback) {
  let raw = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => {
    if (raw.length < MAX_STDIN) raw += chunk.substring(0, MAX_STDIN - raw.length);
  });
  process.stdin.on('end', () => callback(raw));
}

module.exports = {
  extractCommand,
  extractOutput,
  findP4Invocations,
  extractChangelist,
  hasFlag,
  readStdin,
  splitSegments,
  tokenize,
};
