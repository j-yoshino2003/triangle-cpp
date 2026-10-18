#!/bin/bash
#---------------------------------------
# PostToolUse: gh pr create の出力から PR 番号を拾い、レビューの引き渡しを案内する.
#
# git-harness（Claude Code 版）の post-bash-pr-created.js に相当する.
#---------------------------------------
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/hook-common.sh
source "$SCRIPT_DIR/lib/hook-common.sh"

hook_read_input

COMMAND=$(hook_command)
[[ -z "$COMMAND" ]] && exit 0
printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];&|(`$])gh(\.exe)?[[:space:]]+pr[[:space:]]+create([[:space:]]|$)' || exit 0

OUTPUT=$(hook_tool_output)
PR_URL=$(printf '%s' "$OUTPUT" | grep -oE 'https://github\.com/[^/[:space:]]+/[^/[:space:]]+/pull/[0-9]+' | head -n 1)
[[ -z "$PR_URL" ]] && exit 0

PR_NUM=${PR_URL##*/}
hook_warn "[Hook] PR を作成しました: ${PR_URL}"
hook_warn "[Hook] レビューは新しいセッションで ${HOOK_SLASH}git-pr-cross-review ${PR_NUM} を実行してください（このセッションではレビューしない）。"

exit 0
