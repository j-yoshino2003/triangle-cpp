#!/usr/bin/env node
'use strict';

const MAX_STDIN = 1024 * 1024;
const { buildPreToolUseAdditionalContext } = require('./pretooluse-visible-output');

// Matches `git push`, `git.exe push` and `git -C <dir> push`, but does not cross ; & |.
const GIT_PUSH_PATTERN = /(^|[\s;&|(`$])git(\.exe)?\s+([^;&|]*\s)?push(\s|$)/;

let raw = '';

function run(rawInput) {
  try {
    const input = typeof rawInput === 'string' ? JSON.parse(rawInput) : rawInput;
    const cmd = String(input.tool_input?.command || '');
    if (GIT_PUSH_PATTERN.test(cmd)) {
      return {
        additionalContext: [
          '[Hook] push はユーザーに見える操作です。対象ブランチを提示して了承を得てから実行すること（git-workflow）。',
          '[Hook] push 後に PR を作ったら、レビューは新しいセッションで /review-pr <PR番号> を案内すること。',
        ],
        exitCode: 0,
      };
    }
  } catch {
    // ignore parse errors and pass through
  }

  return typeof rawInput === 'string' ? rawInput : JSON.stringify(rawInput);
}

if (require.main === module) {
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => {
    if (raw.length < MAX_STDIN) {
      const remaining = MAX_STDIN - raw.length;
      raw += chunk.substring(0, remaining);
    }
  });

  process.stdin.on('end', () => {
    const result = run(raw);
    if (result && typeof result === 'object') {
      if (result.stderr) {
        process.stderr.write(`${result.stderr}\n`);
      }
      if (Object.prototype.hasOwnProperty.call(result, 'additionalContext')) {
        process.stdout.write(buildPreToolUseAdditionalContext(result.additionalContext));
      } else {
        process.stdout.write(String(result.stdout || ''));
      }
      process.exitCode = Number.isInteger(result.exitCode) ? result.exitCode : 0;
      return;
    }

    process.stdout.write(String(result));
  });
}

module.exports = { run };
