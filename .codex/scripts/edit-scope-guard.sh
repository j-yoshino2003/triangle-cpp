#!/bin/bash
#---------------------------------------
# PreToolUse: 編集を許可ディレクトリ内に限定するガード（厳格モード）.
#
# 許可リスト外へのファイル作成・編集を deny で拒否する.
# 対象を変えたいときは、下の「編集を許可するパス」ブロックだけを書き換える.
#
# ペイロードの解析と応答形式の切り替えは scripts/lib/hook-common.sh に集約している
# （Node.js を前提にできないため grep / sed 実装。ペイロードのフィールド名は公式に
#   公開されていないため、複数の候補キーを防御的に走査する）.
#---------------------------------------
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/hook-common.sh
source "$SCRIPT_DIR/lib/hook-common.sh"

# ============================================================
# ▼▼▼ ここだけ編集する: 編集を許可するパス（glob パターン） ▼▼▼
#   ・case 文の glob 形式で記述する（例: */dir/sub/*）.
#   ・1 パターン 1 行。末尾コメントで用途を書く.
#   ・行を増減するだけで許可範囲を変更できる.
#   ・区切り文字は「/」で書く（Windows の「\」区切りは判定前に「/」へ正規化される）.
#   ・AGENTS.md の「作業範囲ルール」の一覧と同じ内容に揃える（片方だけ変えない）.
#     Claude Code 用（.claude/vendor/edit-scope-guard）と Antigravity 用（.agent/.agents/plugins/coding-harness）も同じ一覧にする.
ALLOW_PATTERNS=(
  "*/AGENTS.md"                       # エージェント共通の作業ルール（AGENTS.md）.
  "*/CLAUDE.local.md"                 # Claude Code のローカル個人設定（CLAUDE.local.md）.
  "*/CLAUDE.md"                       # /speckit.plan の手順 3 が update-agent-context.sh 経由で作る（CLAUDE.md）.
  "*/specs/*"                         # 仕様書（specs/）. team-change が更新する.
  "*/.specify/*"                      # spec-kit のテンプレート・スクリプト（.specify/）.
  "*/.claude/*"                       # Claude Code のハーネス（.claude/）.
  "*/.codex/*"                        # Codex のハーネス（.codex/）.
  "*/.agent/*"                        # Antigravity のハーネス（.agent/）.
  "*/.zed/*"                          # Zed のプロジェクト設定（.zed/）.
  "*/docs/*"                          # 日本語訳リファレンス・レビュー結果・マニュアル（docs/）.
  "*/cpp/*"                           # C++ プロジェクト（cpp/）.
  "*/rust/*"                          # Rust プロジェクト（rust/）.
)
# ▲▲▲ 編集してよい範囲はここまで ▲▲▲
# ============================================================

hook_read_input

# 書き込み系ツールでなければ通す（ツール名が取れない場合は安全側で判定を続ける）.
hook_is_write_tool || exit 0

# 編集対象が取得できない場合は誤ブロックを避けて通す.
mapfile -t FILES < <(hook_target_paths)
[[ ${#FILES[@]} -eq 0 ]] && exit 0

WORKSPACE=$(pwd | tr '\\' '/')
DENIED=()

for file in "${FILES[@]}"; do
  # 区切り文字を正規化し、相対パスは絶対パスに直してから glob 照合する.
  normalized=$(printf '%s' "$file" | tr '\\' '/')
  normalized=${normalized#./}

  if [[ "$normalized" != /* && ! "$normalized" =~ ^[A-Za-z]: ]]; then
    normalized="$WORKSPACE/$normalized"
  fi

  allowed=1
  for pattern in "${ALLOW_PATTERNS[@]}"; do
    case "$normalized" in
      $pattern) allowed=0; break ;;
    esac
  done

  [[ $allowed -eq 1 ]] && DENIED+=("$normalized")
done

[[ ${#DENIED[@]} -eq 0 ]] && exit 0

# 範囲外: 編集を拒否（許可リストを理由文に含める）.
ALLOWED_TEXT=$(printf '%s / ' "${ALLOW_PATTERNS[@]}" | sed -E 's| / $||')
DENIED_TEXT=$(printf '%s, ' "${DENIED[@]}" | sed -E 's|, $||')
hook_deny "編集は許可ディレクトリに限定されています（${ALLOWED_TEXT}）。範囲外のため拒否しました: ${DENIED_TEXT}"
