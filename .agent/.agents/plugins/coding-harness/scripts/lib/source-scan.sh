#!/bin/bash
#---------------------------------------
# コミット前の内容検査（source して使う）.
#
# 秘密情報（error）とデバッグ残骸（warning）の行パターンと、それを 1 ファイル分の内容に当てる関数.
# git-commit-guard.sh が使う.
#
# 提供する関数:
#   scan_should_check PATH        内容を検査する対象なら 0 を返す（バイナリ以外すべて）
#   scan_content LABEL            標準入力の内容を検査し、指摘を stderr に出す.
#                                 error の件数を SCAN_ERRORS、warning の件数を SCAN_WARNINGS に加算する
#   scan_description FIRST_LINE   コミットメッセージ 1 行目の形式を検査し、警告を stderr に出す（SCAN_WARNINGS に加算）
#
# 秘密情報の検査は拡張子で絞らない。`.env` `.yaml` `.sh` `.md` などを対象外にすると、
# 鍵が最も置かれやすいファイルを無検査で通したうえ、ユーザーは「検査済み」と受け取る。
# デバッグ残骸の検査だけはソースに限る（それ以外に出ても意味が無いため）。
#---------------------------------------

# 内容を見ても意味が無いバイナリ. ここだけが検査の対象外になる.
SCAN_BINARY_EXTENSIONS='\.(png|jpe?g|gif|bmp|ico|webp|pdf|zip|gz|bz2|xz|7z|rar|tar|exe|dll|lib|pdb|obj|o|a|so|dylib|bin|spv|ttf|otf|woff2?|eot|mp3|mp4|wav|ogg|avi|mov|class|jar|pyc)$'

# デバッグ残骸の検査を当てるソース拡張子.
SCAN_SOURCE_EXTENSIONS='\.(cpp|cc|c|h|hpp|inl|cs|py|rs|js|ts|ini|json)$'

# scan_content が 1 ファイルで見る上限（バイト数ではなく文字数で比較している）.
SCAN_MAX_BYTES=$((2 * 1024 * 1024))
SCAN_ERRORS=${SCAN_ERRORS:-0}
SCAN_WARNINGS=${SCAN_WARNINGS:-0}

# 秘密情報（見つかったら error）. 「名前|正規表現」の形式.
SCAN_SECRET_PATTERNS=(
  'Anthropic API key|sk-ant-[a-zA-Z0-9_-]{20,}'
  'OpenAI API key|sk-[a-zA-Z0-9]{20,}'
  'GitHub PAT|ghp_[a-zA-Z0-9]{36}'
  'GitHub fine-grained token|github_pat_[A-Za-z0-9_]{20,}'
  'AWS Access Key|AKIA[A-Z0-9]{16}'
  'hardcoded credential|(password|passwd|secret|api[_-]?key)[[:space:]]*[=:][[:space:]]*['"'"'"][^'"'"'"]{8,}['"'"'"]'
)

# デバッグ残骸（見つかったら warning）.
SCAN_DEBUG_PATTERNS=(
  'UE_LOG(LogTemp, ...)（一時ログ）|\bUE_LOG[[:space:]]*\([[:space:]]*LogTemp\b'
  'Debug.Log（一時ログ）|\bDebug\.Log(Warning|Error)?[[:space:]]*\('
  'デバッグブレーク|\b(__debugbreak|DebugBreak)[[:space:]]*\('
  'console.log|\bconsole\.log[[:space:]]*\('
  'debugger 文|^[[:space:]]*debugger[[:space:]]*;?[[:space:]]*$'
  'コンフリクトマーカー|^(<<<<<<<|=======|>>>>>>>)'
)

SCAN_DESCRIPTION_FORMAT='^(feat|fix|refactor|docs|test|chore|perf|ci):[[:space:]]+[^[:space:]]'

scan_is_binary() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | grep -qE "$SCAN_BINARY_EXTENSIONS"
}

scan_is_source() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | grep -qE "$SCAN_SOURCE_EXTENSIONS"
}

# 内容を検査する対象かどうか. バイナリだけを除外する.
scan_should_check() {
  if scan_is_binary "$1"; then
    printf '  SKIP %s: バイナリとして検査対象外\n' "$1" >&2

    return 1
  fi

  return 0
}

# 標準入力の内容を検査する. $1 = 表示用ラベル（パス）.
scan_content() {
  local label="$1" content entry name pattern hits
  content=$(cat)

  # 上限超過は黙って打ち切らない。黙ると「検査済み」と誤認される.
  if [[ ${#content} -gt $SCAN_MAX_BYTES ]]; then
    printf '\n[FILE] %s\n' "$label" >&2
    printf '  WARNING %s 文字を超えるため内容検査を打ち切りました（上限 %s 文字）\n' "$SCAN_MAX_BYTES" "$SCAN_MAX_BYTES" >&2
    SCAN_WARNINGS=$((SCAN_WARNINGS + 1))

    return 0
  fi

  local header_printed=0
  for entry in "${SCAN_SECRET_PATTERNS[@]}"; do
    name=${entry%%|*}; pattern=${entry#*|}
    hits=$(printf '%s\n' "$content" | grep -nE "$pattern" | cut -d: -f1 | head -n 20)
    [[ -z "$hits" ]] && continue
    [[ $header_printed -eq 0 ]] && { printf '\n[FILE] %s\n' "$label" >&2; header_printed=1; }
    while IFS= read -r line; do
      printf '  ERROR Line %s: %s の可能性があります\n' "$line" "$name" >&2
      SCAN_ERRORS=$((SCAN_ERRORS + 1))
    done <<< "$hits"
  done

  # デバッグ残骸はソースにしか意味が無いので、ここだけ拡張子で絞る.
  if scan_is_source "$label"; then
    for entry in "${SCAN_DEBUG_PATTERNS[@]}"; do
      name=${entry%%|*}; pattern=${entry#*|}
      hits=$(printf '%s\n' "$content" | grep -nE "$pattern" | cut -d: -f1 | head -n 20)
      [[ -z "$hits" ]] && continue
      [[ $header_printed -eq 0 ]] && { printf '\n[FILE] %s\n' "$label" >&2; header_printed=1; }
      while IFS= read -r line; do
        printf '  WARNING Line %s: %s が残っています\n' "$line" "$name" >&2
        SCAN_WARNINGS=$((SCAN_WARNINGS + 1))
      done <<< "$hits"
    done
  fi

  return 0
}

# コミットメッセージの 1 行目を検査する.
scan_description() {
  local first="$1"
  if [[ -z "$first" ]] || printf '%s' "$first" | grep -qi '<enter description here>'; then
    printf '  WARNING コミットメッセージが空です。<type>: <description> の形式で書いてください\n' >&2
    SCAN_WARNINGS=$((SCAN_WARNINGS + 1))
    return 0
  fi
  if ! printf '%s' "$first" | grep -qE "$SCAN_DESCRIPTION_FORMAT"; then
    printf '  WARNING コミットメッセージの 1 行目が <type>: <description> 形式ではありません: "%s"（type は feat / fix / refactor / docs / test / chore / perf / ci）\n' "$first" >&2
    SCAN_WARNINGS=$((SCAN_WARNINGS + 1))
  fi
  if [[ ${#first} -gt 72 ]]; then
    printf '  WARNING コミットメッセージの 1 行目が長すぎます（%s 文字、上限 72）\n' "${#first}" >&2
    SCAN_WARNINGS=$((SCAN_WARNINGS + 1))
  fi
  if [[ "$first" == *. ]]; then
    printf '  WARNING コミットメッセージの 1 行目は末尾にピリオドを付けません\n' >&2
    SCAN_WARNINGS=$((SCAN_WARNINGS + 1))
  fi
  return 0
}
