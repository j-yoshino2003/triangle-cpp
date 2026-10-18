#!/bin/bash
#---------------------------------------
# PostToolUse: p4 shelve / p4 change の出力から CL 番号を拾い、次の手順を案内する.
#
# p4-harness（Claude Code 版）の post-bash-shelved.js に相当する.
#---------------------------------------
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/hook-common.sh
source "$SCRIPT_DIR/lib/hook-common.sh"

hook_read_input

# hooks.json に matcher 相当の絞り込みが無く、すべてのツール呼び出しでこのフックが起動する.
# 実行系ツール以外はここで抜ける（ツール名が取れない場合は安全側で判定を続ける）.
hook_is_exec_tool || exit 0

COMMAND=$(hook_command)
[[ -z "$COMMAND" ]] && exit 0
printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];&|(`$])p4(\.exe)?[[:space:]]' || exit 0

OUTPUT=$(hook_tool_output)
[[ -z "$OUTPUT" ]] && exit 0

if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])shelve([[:space:]]|$)'; then
  CL=$(printf '%s' "$OUTPUT" | grep -oE 'Shelving files for change [0-9]+|Change [0-9]+ files shelved' | grep -oE '[0-9]+' | head -n 1)
  if [[ -n "$CL" ]]; then
    hook_warn "[Hook] CL ${CL} をシェルブしました。"
    hook_warn "[Hook] レビューは新しいセッションで ${HOOK_SLASH}p4-cl-cross-review ${CL} を実行してください（このセッションではレビューしない）。"
  fi
fi

if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])change([[:space:]]|$)'; then
  CL=$(printf '%s' "$OUTPUT" | grep -oE 'Change [0-9]+ created' | grep -oE '[0-9]+' | head -n 1)
  if [[ -n "$CL" ]]; then
    hook_warn "[Hook] 保留 CL ${CL} を作成しました。ファイルを開くときは p4 edit -c ${CL} <file> を使ってください。"
  fi
fi

exit 0
