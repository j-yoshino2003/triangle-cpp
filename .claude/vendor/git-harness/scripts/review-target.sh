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
#   4 = 差分の取得に失敗（gh pr diff が失敗し、ローカルからの取り直しもできない）
#   5 = PR のメタデータが取得できない / 6 = ブランチまたはベースが存在しない / 7 = 差分が無い
#
# 「差分が取れなかった」を「差分が無い」と混同しないこと. 混同すると、レビュワーが
# 気づかないまま指摘ゼロのレビューになる.
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
  # NOTE:
  # 整形は gh 同梱の jq に任せる. python は環境によって Microsoft Store のスタブが PATH に
  # 入り、コードを実行せず "Python" と出して終了コード 0 を返すため、無言で空振りする.
  PR_INFO=$(gh pr view "$TARGET" \
    --json number,title,headRefName,baseRefName,author,url,state,headRefOid \
    --jq '"base: \(.baseRefName)\nbranch: \(.headRefName)\ntitle: \(.title)\nauthor: \(.author.login)\nstate: \(.state)\nurl: \(.url)\nhead-oid: \(.headRefOid)"' 2>&1) || {
    echo "PR #$TARGET のメタデータを取得できません: $PR_INFO" >&2
    exit 5
  }
  printf 'target: PR #%s\n' "$TARGET"
  printf '%s\n' "$PR_INFO"

  pr_field() {
    printf '%s\n' "$PR_INFO" | sed -n "s/^$1: //p" | head -n 1
  }
  PR_BASE=$(pr_field base)
  PR_HEAD=$(pr_field branch)
  PR_HEAD_OID=$(pr_field head-oid)

  FILES=$(gh pr view "$TARGET" --json files \
    --jq '.files[] | "\(.additions)+ \(.deletions)- \(.path)"' 2>&1) || {
    echo "PR #$TARGET の変更ファイル一覧を取得できません: $FILES" >&2
    exit 5
  }
  printf '%s\n' "$FILES" | print_files

  # NOTE:
  # gh pr diff は差分が 20,000 行を超えると HTTP 406 で失敗する. 失敗を「差分なし」に
  # すり替えると、レビュワーは差分が取れなかったことに気づけず「指摘ゼロ」の結果になる.
  # 終了コードで切り分け、失敗したときはローカルの ref から同じ範囲を取り直す.
  DIFF_SOURCE="gh pr diff"
  GH_ERR_FILE=$(mktemp)
  DIFF=$(gh pr diff "$TARGET" 2>"$GH_ERR_FILE")
  GH_STATUS=$?
  GH_DIFF_ERROR=$(cat "$GH_ERR_FILE")
  rm -f "$GH_ERR_FILE"

  if [ "$GH_STATUS" -ne 0 ]; then
    echo "gh pr diff が失敗しました（終了コード $GH_STATUS）: ${GH_DIFF_ERROR:-エラー出力なし}" >&2

    BASE_REF=$(resolve_ref "$PR_BASE") || {
      echo "ローカルからの取り直しもできません: ベース $PR_BASE が見つかりません。git fetch origin を実行してください。" >&2
      exit 4
    }
    HEAD_REF=$(resolve_ref "$PR_HEAD") || {
      echo "ローカルからの取り直しもできません: head $PR_HEAD が見つかりません。git fetch origin を実行してください。" >&2
      exit 4
    }

    # ローカルの head が PR の head と違えば、取り直した差分は PR の内容ではない.
    LOCAL_OID=$(git rev-parse "$HEAD_REF")
    if [ "$LOCAL_OID" != "$PR_HEAD_OID" ]; then
      echo "ローカルの $PR_HEAD ($LOCAL_OID) が PR #$TARGET の head ($PR_HEAD_OID) と一致しません。git fetch origin を実行してから再試行してください。" >&2
      exit 4
    fi

    DIFF=$(git diff "$BASE_REF...$HEAD_REF") || {
      echo "git diff $BASE_REF...$HEAD_REF が失敗しました。" >&2
      exit 4
    }
    DIFF_SOURCE="git diff $PR_BASE...$PR_HEAD（gh pr diff が失敗したためローカルの ref から取得。head の一致は確認済み）"
  fi

  printf 'diff-source: %s\n' "$DIFF_SOURCE"

  if [ -z "$(printf '%s' "$DIFF" | tr -d '[:space:]')" ]; then
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
