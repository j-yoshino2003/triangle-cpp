#!/usr/bin/env bash
#---------------------------------------
# レビュー対象の差分取得（読み取り専用）.
#
# 使い方:
#   review-target.sh <PR番号>        gh で PR のメタデータと差分を取得する
#   review-target.sh <ブランチ名>    ベースブランチとの差分（base...branch）を取得する
#   review-target.sh working         現在のブランチの未コミット分まで含めた、ベースブランチとの差分を取得する
#   いずれも [--base <branch>] でベースを指定できる（既定: develop）.
#
# 出力: 先頭にメタデータ（target / base / branch / title / files）、"=== DIFF ===" 以降に unified diff.
# 状態を変更する git / gh コマンドは実行しない（fetch も行わない）.
#
# 終了コード:
#   0 = 成功 / 2 = 引数不正・git リポジトリ外 / 3 = gh が無い・未ログイン
#   5 = PR が存在しない / 6 = ブランチまたはベースが存在しない / 7 = 差分が無い
#---------------------------------------
set -u

usage() {
  echo "使い方: review-target.sh <PR番号|ブランチ名|working> [--base <branch>]" >&2
}

TARGET="${1:-}"
[ $# -gt 0 ] && shift
BASE="develop"
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --base=*) BASE="${1#--base=}"; shift ;;
    *) shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  usage
  exit 2
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git リポジトリの中で実行してください。" >&2
  exit 2
fi

# 日本語のパスを \344... のように 8 進エスケープしない.
git() { command git -c core.quotepath=false "$@"; }

resolve_ref() {
  git rev-parse --verify -q "origin/$1" 2>/dev/null || git rev-parse --verify -q "$1" 2>/dev/null
}

print_files() {
  printf 'files:\n'
  while IFS= read -r line; do
    [ -n "$line" ] && printf '  %s\n' "$line"
  done
}

# --- PR 番号 -------------------------------------------------------------------
if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI が見つかりません。PR 番号でのレビューには gh が必要です。" >&2
    exit 3
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "gh にログインしていません。gh auth login を実行してから再試行してください。" >&2
    exit 3
  fi
  META=$(gh pr view "$TARGET" --json number,title,headRefName,baseRefName,author,url,state 2>/dev/null) || {
    echo "PR #$TARGET が見つかりません。" >&2
    exit 5
  }
  printf 'target: PR #%s\n' "$TARGET"
  printf '%s\n' "$META" | python -c "
import json,sys
m=json.load(sys.stdin)
print('base:', m.get('baseRefName',''))
print('branch:', m.get('headRefName',''))
print('title:', m.get('title',''))
print('author:', (m.get('author') or {}).get('login',''))
print('state:', m.get('state',''))
print('url:', m.get('url',''))
"
  gh pr view "$TARGET" --json files --jq '.files[] | "\(.additions)+ \(.deletions)- \(.path)"' | print_files
  DIFF=$(gh pr diff "$TARGET" 2>/dev/null)
  if [ -z "$DIFF" ]; then
    echo "PR #$TARGET に差分がありません。" >&2
    exit 7
  fi
  printf '=== DIFF ===\n%s\n' "$DIFF"
  exit 0
fi

# --- ブランチ / working ----------------------------------------------------------
BASE_REF=$(resolve_ref "$BASE") || {
  echo "ベースブランチ $BASE が見つかりません（origin/$BASE も無し）。--base で指定してください。" >&2
  exit 6
}

if [ "$TARGET" = "working" ]; then
  CURRENT=$(git rev-parse --abbrev-ref HEAD)
  printf 'target: working（%s の未コミット分を含む）\n' "$CURRENT"
  printf 'base: %s\n' "$BASE"
  printf 'branch: %s\n' "$CURRENT"
  printf 'title: %s\n' "$(git log -1 --format=%s 2>/dev/null)"
  {
    git diff --name-status "$BASE_REF"
    git ls-files --others --exclude-standard | sed 's/^/A(untracked)\t/'
  } | print_files
  DIFF=$(git diff "$BASE_REF")
  UNTRACKED=$(git ls-files --others --exclude-standard)
  if [ -n "$UNTRACKED" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && DIFF="$DIFF"$'\n'"$(git diff --no-index -- /dev/null "$f" 2>/dev/null)"
    done <<< "$UNTRACKED"
  fi
else
  HEAD_REF=$(resolve_ref "$TARGET") || {
    echo "ブランチ $TARGET が見つかりません（origin/$TARGET も無し）。" >&2
    exit 6
  }
  printf 'target: branch %s\n' "$TARGET"
  printf 'base: %s\n' "$BASE"
  printf 'branch: %s\n' "$TARGET"
  printf 'title: %s\n' "$(git log -1 --format=%s "$HEAD_REF" 2>/dev/null)"
  git diff --name-status "$BASE_REF...$HEAD_REF" | print_files
  DIFF=$(git diff "$BASE_REF...$HEAD_REF")
fi

if [ -z "$(printf '%s' "$DIFF" | tr -d '[:space:]')" ]; then
  echo "$TARGET と $BASE の間に差分がありません。" >&2
  exit 7
fi

printf '=== DIFF ===\n%s\n' "$DIFF"
exit 0
