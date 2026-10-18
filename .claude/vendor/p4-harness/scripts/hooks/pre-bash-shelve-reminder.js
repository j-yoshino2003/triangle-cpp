#!/usr/bin/env node
'use strict';
/**
 * PreToolUse Hook: Shelve reminder
 *
 * Before `p4 shelve`, remind the session that the changelist number, its
 * description, and the file list must have been shown to the user and
 * approved (the p4-workflow rule). Non-blocking: returns additionalContext.
 */

const { extractCommand, findP4Invocations, hasFlag, readStdin } = require('../lib/p4-command');

function run(rawInput) {
  const command = extractCommand(rawInput);
  const shelving = findP4Invocations(command).some(inv => inv.subcommand === 'shelve' && !hasFlag(inv.args, '-d'));
  if (!shelving) return null;

  return [
    '[Hook] シェルブはユーザーに見える操作です。CL 番号・説明文・対象ファイル一覧を提示して了承を得てから実行すること（p4-workflow）。',
    '[Hook] シェルブ後は新しいセッションで /review-cl <CL番号> を案内すること。',
  ].join('\n');
}

module.exports = { run };

if (require.main === module) {
  readStdin(raw => {
    const context = run(raw);
    if (context) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: { hookEventName: 'PreToolUse', additionalContext: context },
      }));
    } else {
      process.stdout.write(raw);
    }
  });
}
