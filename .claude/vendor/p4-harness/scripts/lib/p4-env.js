#!/usr/bin/env node
'use strict';
/**
 * Run p4 for the hooks: always through the P4_PROXY address when it is set,
 * with short timeouts, and never throwing — a hook must not break the session
 * because Perforce is unreachable.
 */

const { spawnSync } = require('child_process');

const TIMEOUT_MS = 20000;

function proxyArgs() {
  const proxy = process.env.P4_PROXY;
  return proxy ? ['-p', proxy] : [];
}

/**
 * Run a p4 command. Returns { ok, status, stdout, stderr }. ok is false when p4
 * is missing, times out, or exits non-zero.
 */
function runP4(args) {
  const result = spawnSync('p4', [...proxyArgs(), ...args], {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    timeout: TIMEOUT_MS,
  });
  if (result.error) {
    return { ok: false, status: -1, stdout: '', stderr: result.error.message };
  }
  return {
    ok: result.status === 0,
    status: result.status,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
  };
}

function p4Available() {
  const result = spawnSync('p4', ['-V'], { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 5000 });
  return !result.error && result.status === 0;
}

/**
 * Files opened in a changelist ('default' or a number).
 * Returns [{ depot, action, change, local }]. local is null when `p4 where` fails.
 */
function openedFiles(changelist) {
  const args = ['-ztag', 'opened'];
  if (changelist) args.push('-c', changelist);
  const result = runP4(args);
  if (!result.ok) return [];

  const files = [];
  let current = {};
  for (const line of result.stdout.split(/\r?\n/)) {
    const match = line.match(/^\.\.\. (\w+) (.*)$/);
    if (!match) {
      if (current.depotFile) files.push(current);
      current = {};
      continue;
    }
    current[match[1]] = match[2];
  }
  if (current.depotFile) files.push(current);

  return files.map(file => ({
    depot: file.depotFile,
    action: file.action || '',
    change: file.change || '',
    local: localPath(file.depotFile),
  }));
}

/**
 * Local workspace path of a depot file via `p4 where` (last column).
 */
function localPath(depotFile) {
  const result = runP4(['where', depotFile]);
  if (!result.ok) return null;
  const line = result.stdout.split(/\r?\n/).find(l => l.trim() && !l.startsWith('-'));
  if (!line) return null;
  // "//depot/a.cpp //client/a.cpp C:\ws\a.cpp" — the local path may contain spaces, so
  // take everything after the second column.
  const parts = line.split(' ');
  if (parts.length < 3) return null;
  return parts.slice(2).join(' ').trim();
}

/**
 * Description of a pending changelist (the Description: block of `p4 change -o`).
 * Returns null for the default changelist or on failure.
 */
function changeDescription(changelist) {
  if (!changelist || changelist === 'default') return null;
  const result = runP4(['change', '-o', changelist]);
  if (!result.ok) return null;

  const lines = result.stdout.split(/\r?\n/);
  const start = lines.findIndex(line => /^Description:/.test(line));
  if (start === -1) return null;

  const body = [];
  for (const line of lines.slice(start + 1)) {
    if (/^\S/.test(line) && line.trim()) break; // next field
    if (line.trim() === '') { body.push(''); continue; }
    body.push(line.replace(/^\t/, ''));
  }
  return body.join('\n').trim();
}

module.exports = { runP4, p4Available, openedFiles, localPath, changeDescription, proxyArgs };
