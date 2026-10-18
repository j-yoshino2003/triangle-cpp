#!/bin/bash
#---------------------------------------
# PreToolUse: git のフック迂回を拒否し、コミット前に内容と説明文を検査する.
#
# git-harness（Claude Code 版）の block-no-verify.js と pre-bash-commit-quality.js に相当する.
#   1. --no-verify / -n（commit）/ -c core.hooksPath= を含む git コマンドを拒否する
#   2. git commit の前に、ステージ済みファイルの秘密情報（拒否）とデバッグ残骸（警告）、
#      コミットメッセージの形式（<type>: <description>、72 文字以内、末尾ピリオド無し）を検査する
#
# git が無い・リポジトリ外・ペイロードが読めない場合は通す（フックでセッションを壊さない）.
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

# git を呼んでいなければ対象外.
printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];&|(`$])git(\.exe)?[[:space:]]' || exit 0

# 引用符の中身（メッセージ本文など）を除いた形で、オプションだけを見る.
BARE=$(hook_strip_quotes "$COMMAND")

# ---- 1. フック迂回の拒否 -------------------------------------------------

# -c core.hooksPath=（大文字小文字は区別しない）.
if printf '%s' "$BARE" | grep -qiE '(^|[[:space:];&|(`$])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?-c[[:space:]]*core\.hookspath='; then
  hook_deny 'BLOCKED: core.hooksPath の上書きは禁止されています。git のフックを迂回しないでください。'
fi

# --no-verify（commit / push / merge / cherry-pick / rebase / am）.
if printf '%s' "$BARE" | grep -qE '(^|[[:space:];&|(`$])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?(commit|push|merge|cherry-pick|rebase|am)[[:space:]]+([^;&|]*[[:space:]])?--no-verify([[:space:]]|$)'; then
  hook_deny 'BLOCKED: --no-verify は禁止されています。git のフックを迂回しないでください。'
fi

# commit の短縮オプション群に n が含まれる形（-n / -an / -sn ...）.
# 値を取るオプション（m / F / C / c / t）より後ろの文字は値なので見ない.
COMMIT_SEGMENT=$(printf '%s' "$BARE" | grep -oE '(^|[[:space:];&|(`$])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?commit[[:space:]]+[^;&|]*' | head -n 1 | sed -E 's/^.*commit[[:space:]]+//')
if [[ -n "$COMMIT_SEGMENT" ]]; then
  for token in $COMMIT_SEGMENT; do
    [[ "$token" == "--" ]] && break
    [[ "$token" == -* && "$token" != --* && "$token" != "-" ]] || continue
    opts=${token#-}
    i=0
    while [[ $i -lt ${#opts} ]]; do
      ch=${opts:$i:1}
      case "$ch" in
        n) hook_deny 'BLOCKED: git commit -n（--no-verify の短縮形）は禁止されています。git のフックを迂回しないでください。' ;;
        m|F|C|c|t) break ;;
      esac
      i=$((i + 1))
    done
  done
fi

# ---- 2. コミット前の品質検査 ---------------------------------------------

printf '%s' "$BARE" | grep -qE '(^|[[:space:];&|(`$])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?commit([[:space:]]|$)' || exit 0
printf '%s' "$BARE" | grep -qE -- '--amend' && exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

mapfile -t STAGED < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
if [[ ${#STAGED[@]} -eq 0 ]]; then
  hook_warn '[Hook] ステージ済みのファイルがありません。先に git add してください。'
  exit 0
fi

hook_warn "[Hook] ステージ済み ${#STAGED[@]} ファイルを検査します"

for file in "${STAGED[@]}"; do
  scan_should_check "$file" || continue
  git show ":$file" 2>/dev/null | scan_content "$file"
done

# コミットメッセージ（-m / --message の 1 つ目）の 1 行目.
MESSAGE=$(printf '%s' "$COMMAND" \
  | grep -oE '(-m|--message)([[:space:]]+|=)("([^"\\]|\\.)*"|'"'"'[^'"'"']*'"'"')' \
  | head -n 1 \
  | sed -E 's/^(-m|--message)([[:space:]]+|=)//; s/^["'"'"']//; s/["'"'"']$//')
if [[ -n "$MESSAGE" ]]; then
  FIRST_LINE=$(printf '%s\n' "$MESSAGE" | head -n 1)
  scan_description "$FIRST_LINE"
fi

if [[ $SCAN_ERRORS -gt 0 ]]; then
  hook_warn ""
  hook_warn "[Hook] ERROR: 秘密情報の疑いが ${SCAN_ERRORS} 件あるため、コミットを拒否しました。取り除いてから再実行してください。"
  hook_deny "BLOCKED: ステージ済みファイルに秘密情報の疑いが ${SCAN_ERRORS} 件あります。取り除いてから再度コミットしてください。"
fi
if [[ $SCAN_WARNINGS -gt 0 ]]; then
  hook_warn ""
  hook_warn "[Hook] WARNING: ${SCAN_WARNINGS} 件の警告があります。コミットは許可しますが、ユーザーに伝えてください。"
else
  hook_warn '[Hook] PASS: コミット前チェックに問題はありません'
fi

exit 0
