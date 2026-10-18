#!/usr/bin/env node
'use strict';
/**
 * PostToolUse Hook: After shelve / change creation
 *
 * Reads the output of `p4 shelve` and `p4 change`, picks up the changelist
 * number, and tells the session what comes next (review in a separate session).
 */

const { extractCommand, extractOutput, findP4Invocations, readStdin } = require('../lib/p4-command');

function run(rawInput) {
  const command = extractCommand(rawInput);
  const output = extractOutput(rawInput);
  const invocations = findP4Invocations(command);
  const messages = [];

  if (invocations.some(inv => inv.subcommand === 'shelve')) {
    const match = output.match(/Shelving files for change (\d+)/) || output.match(/Change (\d+) files shelved/);
    if (match) {
      messages.push(`[Hook] CL ${match[1]} をシェルブしました。`);
      messages.push(`[Hook] レビューは新しい Claude Code セッションで /review-cl ${match[1]} を実行してください（このセッションではレビューしない）。`);
    }
  }

  if (invocations.some(inv => inv.subcommand === 'change')) {
    const match = output.match(/Change (\d+) created/);
    if (match) {
      messages.push(`[Hook] 保留 CL ${match[1]} を作成しました。ファイルを開くときは p4 edit -c ${match[1]} <file> を使ってください。`);
    }
  }

  return messages.length > 0 ? messages.join('\n') : null;
}

module.exports = { run };

if (require.main === module) {
  readStdin(raw => {
    const message = run(raw);
    if (message) process.stderr.write(message + '\n');
    process.stdout.write(raw);
  });
}
