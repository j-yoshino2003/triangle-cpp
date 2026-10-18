#!/bin/bash
#---------------------------------------
# PreToolUse: git push の直前に、確認の約束事を思い出させる（拒否はしない）.
#
# git-harness（Claude Code 版）の pre-bash-git-push-reminder.js に相当する.
# 通常の push は許可する. 強制 push とリモートブランチ削除は scm-guard.sh が拒否する.
#---------------------------------------
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/hook-common.sh
source "$SCRIPT_DIR/lib/hook-common.sh"

hook_read_input
hook_is_exec_tool || exit 0

COMMAND=$(hook_command)
[[ -z "$COMMAND" ]] && exit 0

BARE=$(hook_strip_quotes "$COMMAND")
printf '%s' "$BARE" | grep -qE '(^|[[:space:];&|(`$])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$)' || exit 0

hook_context "[Hook] push はユーザーに見える操作です。対象ブランチを提示して了承を得てから実行すること（git-workflow）。
[Hook] push 後に PR を作ったら、レビューは新しいセッションで ${HOOK_SLASH}git-pr-cross-review <PR番号> を案内すること。"

exit 0
