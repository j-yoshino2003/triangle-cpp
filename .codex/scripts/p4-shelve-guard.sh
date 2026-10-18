#!/bin/bash
#---------------------------------------
# PreToolUse: p4 shelve の前に、シェルブ対象の内容と CL 説明文を検査し、確認の約束事を思い出させる.
#
# p4-harness（Claude Code 版）の pre-bash-shelve-quality.js と pre-bash-shelve-reminder.js に相当する.
#   1. 対象 CL で開いているファイル（-ztag opened）をローカルパスに解決し、秘密情報（拒否）と
#      デバッグ残骸（警告）を検査する
#   2. CL 説明文の 1 行目の形式（<type>: <description>、72 文字以内）を検査する（警告）
#   3. 「CL 番号・説明文・ファイル一覧を提示して了承を得てから」を補足文脈として返す
#
# submit / revert / obliterate / shelve -d / change -d の拒否は scm-guard.sh が行う.
# p4 が無い・接続できない場合は検査を飛ばして通す.
#---------------------------------------
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/hook-common.sh
source "$SCRIPT_DIR/lib/hook-common.sh"
# shellcheck source=lib/source-scan.sh
source "$SCRIPT_DIR/lib/source-scan.sh"

hook_read_input
hook_is_exec_tool || exit 0

COMMAND=$(hook_command)
[[ -z "$COMMAND" ]] && exit 0

BARE=$(hook_strip_quotes "$COMMAND")

# p4 shelve（-d 以外）を含むセグメントだけを対象にする.
SHELVE_SEGMENT=$(printf '%s' "$BARE" | tr ';|&' '\n\n\n' | grep -E '(^|[[:space:](`$])p4(\.exe)?[[:space:]]+([^[:space:]]+[[:space:]]+)*shelve([[:space:]]|$)' | head -n 1)
[[ -z "$SHELVE_SEGMENT" ]] && exit 0
printf '%s' "$SHELVE_SEGMENT" | sed -E 's/^.*shelve//' | grep -qE '(^|[[:space:]])-d([[:space:]]|$)' && exit 0

SHELVE_ARGS=$(printf '%s' "$SHELVE_SEGMENT" | sed -E 's/^.*shelve//')
CHANGELIST=$(printf '%s' "$SHELVE_ARGS" | grep -oE '(^|[[:space:]])-c[[:space:]]+[^[:space:]]+' | head -n 1 | sed -E 's/^[[:space:]]*-c[[:space:]]+//')
if [[ -z "$CHANGELIST" ]]; then
  CHANGELIST=$(printf '%s' "$SHELVE_ARGS" | grep -oE '(^|[[:space:]])[0-9]+([[:space:]]|$)' | head -n 1 | tr -d ' ')
fi
[[ -z "$CHANGELIST" ]] && CHANGELIST="default"

REMINDER="[Hook] シェルブはユーザーに見える操作です。CL 番号・説明文・対象ファイル一覧を提示して了承を得てから実行すること（p4-workflow）。
[Hook] シェルブ後は新しいセッションで ${HOOK_SLASH}p4-cl-cross-review <CL番号> を案内すること。"

if ! command -v p4 >/dev/null 2>&1; then
  hook_warn '[Hook] p4 が見つからないため、シェルブ前チェックを飛ばしました'
  hook_context "$REMINDER"
  exit 0
fi

P4=(p4)
[[ -n "${P4_PROXY:-}" ]] && P4=(p4 -p "$P4_PROXY")

# 対象 CL で開いているファイルのデポパス.
if [[ "$CHANGELIST" == "default" ]]; then
  OPENED=$("${P4[@]}" -ztag opened -c default 2>/dev/null)
else
  OPENED=$("${P4[@]}" -ztag opened -c "$CHANGELIST" 2>/dev/null)
fi
mapfile -t DEPOT_FILES < <(printf '%s\n' "$OPENED" | grep -E '^\.\.\. depotFile ' | sed -E 's/^\.\.\. depotFile //')

LABEL="CL ${CHANGELIST}"
[[ "$CHANGELIST" == "default" ]] && LABEL="default"
if [[ ${#DEPOT_FILES[@]} -eq 0 ]]; then
  hook_warn "[Hook] ${LABEL} で開いているファイルが見つかりません（ワークスペース外か、既にシェルブ済み）"
else
  hook_warn "[Hook] ${LABEL}: ${#DEPOT_FILES[@]} ファイルを検査します"
fi

for depot in "${DEPOT_FILES[@]}"; do
  # p4 where の 3 列目以降がローカルパス（空白を含みうる）.
  local_path=$("${P4[@]}" where "$depot" 2>/dev/null | grep -vE '^-' | head -n 1 | cut -d' ' -f3-)
  [[ -z "$local_path" || ! -f "$local_path" ]] && continue
  scan_should_check "$local_path" || continue
  scan_content "$depot" < "$local_path"
done

# CL 説明文の 1 行目（default CL には説明文が無い）.
if [[ "$CHANGELIST" != "default" ]]; then
  FIRST_LINE=$("${P4[@]}" change -o "$CHANGELIST" 2>/dev/null \
    | sed -n '/^Description:/,/^[^[:space:]]/p' \
    | sed '1d; /^[^[:space:]]/d' \
    | sed -E 's/^\t//' \
    | sed '/^[[:space:]]*$/d' \
    | head -n 1)
  scan_description "$FIRST_LINE"
fi

if [[ $SCAN_ERRORS -gt 0 ]]; then
  hook_warn ""
  hook_warn "[Hook] ERROR: 秘密情報の疑いが ${SCAN_ERRORS} 件あるため、シェルブを拒否しました。取り除いてから再実行してください。"
  hook_deny "BLOCKED: シェルブ対象のファイルに秘密情報の疑いが ${SCAN_ERRORS} 件あります。取り除いてから再度シェルブしてください。"
fi
if [[ $SCAN_WARNINGS -gt 0 ]]; then
  hook_warn ""
  hook_warn "[Hook] WARNING: ${SCAN_WARNINGS} 件の警告があります。シェルブは許可しますが、ユーザーに伝えてください。"
else
  hook_warn '[Hook] PASS: シェルブ前チェックに問題はありません'
fi

hook_context "$REMINDER"
exit 0
