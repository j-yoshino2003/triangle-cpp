#!/usr/bin/env node
'use strict';
/**
 * PreToolUse Hook: Pre-shelve Quality Check
 *
 * Runs before `p4 shelve`:
 *   - lists the files opened in the target changelist (via P4_PROXY)
 *   - scans their local content for secrets and debug leftovers
 *   - checks the changelist description format (<type>: <description>)
 *
 * Secrets block the shelve (exit 2). Everything else is a warning.
 * If p4 is unavailable or the workspace cannot be read, the hook passes.
 *
 * Exit codes:
 *   0 = allow
 *   2 = block (secrets found)
 */

const fs = require('fs');
const { extractCommand, findP4Invocations, extractChangelist, hasFlag, readStdin } = require('../lib/p4-command');
const { p4Available, openedFiles, changeDescription } = require('../lib/p4-env');

const CHECKABLE_EXTENSIONS = ['.cpp', '.cc', '.c', '.h', '.hpp', '.inl', '.cs', '.py', '.rs', '.js', '.ts', '.ini', '.json'];
const MAX_FILE_BYTES = 2 * 1024 * 1024;

const SECRET_PATTERNS = [
  { pattern: /sk-ant-[a-zA-Z0-9_-]{20,}/, name: 'Anthropic API key' },
  { pattern: /ghp_[a-zA-Z0-9]{36}/, name: 'GitHub PAT' },
  { pattern: /github_pat_[A-Za-z0-9_]{20,}/, name: 'GitHub fine-grained token' },
  { pattern: /AKIA[A-Z0-9]{16}/, name: 'AWS Access Key' },
  { pattern: /(password|passwd|secret|api[_-]?key)\s*[=:]\s*['"][^'"]{8,}['"]/i, name: 'hardcoded credential' },
];

const DEBUG_PATTERNS = [
  { pattern: /\bUE_LOG\s*\(\s*LogTemp\b/, name: 'UE_LOG(LogTemp, ...)（一時ログ）' },
  { pattern: /\bDebug\.Log(Warning|Error)?\s*\(/, name: 'Debug.Log（一時ログ）' },
  { pattern: /\b(__debugbreak|DebugBreak)\s*\(/, name: 'デバッグブレーク' },
  { pattern: /\bconsole\.log\s*\(/, name: 'console.log' },
  { pattern: /^\s*(<<<<<<<|=======|>>>>>>>)/, name: 'コンフリクトマーカー' },
];

const DESCRIPTION_FORMAT = /^(feat|fix|refactor|docs|test|chore|perf|ci):\s+\S/;

function shouldCheck(localPath) {
  const lower = (localPath || '').toLowerCase();
  return CHECKABLE_EXTENSIONS.some(ext => lower.endsWith(ext));
}

function scanFile(localPath) {
  const issues = [];
  let content;
  try {
    const stat = fs.statSync(localPath);
    if (stat.size > MAX_FILE_BYTES) return issues;
    content = fs.readFileSync(localPath, 'utf8');
  } catch {
    return issues;
  }

  content.split(/\r?\n/).forEach((line, index) => {
    const lineNum = index + 1;
    for (const { pattern, name } of SECRET_PATTERNS) {
      if (pattern.test(line)) {
        issues.push({ severity: 'error', line: lineNum, message: `${name} の可能性があります` });
      }
    }
    for (const { pattern, name } of DEBUG_PATTERNS) {
      if (pattern.test(line)) {
        issues.push({ severity: 'warning', line: lineNum, message: `${name} が残っています` });
      }
    }
  });
  return issues;
}

function checkDescription(changelist) {
  const description = changeDescription(changelist);
  if (description === null) return [];
  const warnings = [];
  const firstLine = description.split('\n')[0] || '';

  if (!firstLine || /<enter description here>/i.test(firstLine)) {
    warnings.push('CL の説明文が空です。<type>: <description> の形式で書いてください');
    return warnings;
  }
  if (!DESCRIPTION_FORMAT.test(firstLine)) {
    warnings.push(`CL 説明文の 1 行目が <type>: <description> 形式ではありません: "${firstLine}"（type は feat / fix / refactor / docs / test / chore / perf / ci）`);
  }
  if (firstLine.length > 72) {
    warnings.push(`CL 説明文の 1 行目が長すぎます（${firstLine.length} 文字、上限 72）`);
  }
  if (firstLine.endsWith('.')) {
    warnings.push('CL 説明文の 1 行目は末尾にピリオドを付けません');
  }
  return warnings;
}

function evaluate(rawInput) {
  const command = extractCommand(rawInput);
  const shelves = findP4Invocations(command).filter(inv => inv.subcommand === 'shelve' && !hasFlag(inv.args, '-d'));
  if (shelves.length === 0) return { exitCode: 0 };
  if (!p4Available()) {
    console.error('[Hook] p4 が見つからないため、シェルブ前チェックを飛ばしました');
    return { exitCode: 0 };
  }

  let errorCount = 0;
  let warningCount = 0;

  for (const { args } of shelves) {
    const changelist = extractChangelist(args);
    const files = openedFiles(changelist === 'default' ? 'default' : changelist);
    const label = changelist === 'default' ? 'default' : `CL ${changelist}`;

    if (files.length === 0) {
      console.error(`[Hook] ${label} で開いているファイルが見つかりません（ワークスペース外か、既にシェルブ済み）`);
    } else {
      console.error(`[Hook] ${label}: ${files.length} ファイルを検査します`);
    }

    for (const file of files) {
      if (!file.local || !shouldCheck(file.local)) continue;
      const issues = scanFile(file.local);
      if (issues.length === 0) continue;
      console.error(`\n[FILE] ${file.depot}`);
      for (const issue of issues) {
        console.error(`  ${issue.severity === 'error' ? 'ERROR' : 'WARNING'} Line ${issue.line}: ${issue.message}`);
        if (issue.severity === 'error') errorCount++; else warningCount++;
      }
    }

    for (const warning of checkDescription(changelist)) {
      console.error(`  WARNING ${warning}`);
      warningCount++;
    }
  }

  if (errorCount > 0) {
    console.error(`\n[Hook] ERROR: 秘密情報の疑いが ${errorCount} 件あるため、シェルブを拒否しました。取り除いてから再実行してください。`);
    return { exitCode: 2 };
  }
  if (warningCount > 0) {
    console.error(`\n[Hook] WARNING: ${warningCount} 件の警告があります。シェルブは許可しますが、ユーザーに伝えてください。`);
  } else {
    console.error('[Hook] PASS: シェルブ前チェックに問題はありません');
  }
  return { exitCode: 0 };
}

function run(rawInput) {
  return evaluate(rawInput);
}

module.exports = { run, evaluate, scanFile, checkDescription };

if (require.main === module) {
  readStdin(raw => {
    let result;
    try {
      result = evaluate(raw);
    } catch (error) {
      console.error(`[Hook] Error: ${error.message}`);
      result = { exitCode: 0 };
    }
    process.stdout.write(raw);
    process.exit(result.exitCode);
  });
}
