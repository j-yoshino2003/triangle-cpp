#!/usr/bin/env node
'use strict';
/**
 * PreToolUse Hook: Block destructive Perforce commands
 *
 * Blocks p4 operations that publish to the depot or throw work away:
 *   - p4 submit            (publishes; the user submits from P4V after review)
 *   - p4 revert            (discards local edits)
 *   - p4 obliterate        (destroys depot history)
 *   - p4 shelve -d         (deletes shelved files)
 *   - p4 change -d         (deletes a pending changelist)
 *
 * Everything else (edit / add / delete / change / shelve / reopen / describe ...)
 * passes through. The shelve quality hook and the reminder hook handle those.
 *
 * Exit codes:
 *   0 = allow
 *   2 = block (reason on stderr)
 */

const { extractCommand, findP4Invocations, hasFlag, readStdin } = require('../lib/p4-command');

const ALWAYS_BLOCKED = {
  submit: 'p4 submit はハーネスで禁止されています。レビュー後にユーザー自身が P4V から submit してください。',
  revert: 'p4 revert はハーネスで禁止されています。作業を捨てる判断はユーザー自身が P4V で行ってください。',
  obliterate: 'p4 obliterate はデポの履歴を破壊するため禁止されています。',
};

function checkCommand(command) {
  for (const { subcommand, args } of findP4Invocations(command)) {
    if (ALWAYS_BLOCKED[subcommand]) {
      return { blocked: true, reason: `BLOCKED: ${ALWAYS_BLOCKED[subcommand]}` };
    }
    if (subcommand === 'shelve' && hasFlag(args, '-d')) {
      return { blocked: true, reason: 'BLOCKED: p4 shelve -d（シェルブ済みファイルの削除）は禁止されています。差し替えは -r / -f を使い、削除はユーザーが P4V で行ってください。' };
    }
    if (subcommand === 'change' && hasFlag(args, '-d')) {
      return { blocked: true, reason: 'BLOCKED: p4 change -d（保留チェンジリストの削除）は禁止されています。ユーザーが P4V で行ってください。' };
    }
  }
  return { blocked: false };
}

function run(rawInput) {
  const result = checkCommand(extractCommand(rawInput));
  return result.blocked ? { exitCode: 2, stderr: result.reason } : { exitCode: 0 };
}

module.exports = { run, checkCommand };

if (require.main === module) {
  readStdin(raw => {
    const result = run(raw);
    if (result.exitCode === 2) {
      process.stderr.write(result.stderr + '\n');
      process.exit(2);
    }
    process.stdout.write(raw);
  });
}
