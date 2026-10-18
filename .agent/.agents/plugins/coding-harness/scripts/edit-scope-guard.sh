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
#   ・リポジトリのルートからの相対パスで、case 文の glob 形式で書く（例: docs/*）.
#     先頭に */ は付けない. 付けると「ルートからの相対」でなくなり、チェックアウト先の
#     ディレクトリ名に判定が左右される.
#   ・1 パターン 1 行。末尾コメントで用途を書く.
#   ・行を増減するだけで許可範囲を変更できる.
#   ・区切り文字は「/」で書く（Windows の「\」区切りは判定前に「/」へ正規化される）.
#   ・ルート直下のファイルは 1 件ずつ名前で挙げる. case の * は「/」にも一致するため、
#     ディレクトリを 1 つ許可したつもりで配下の別ディレクトリまで通ってしまう.
#   ・AGENTS.md の「作業範囲ルール」の一覧と同じ内容に揃える（片方だけ変えない）.
#     Claude Code 用（.claude/vendor/edit-scope-guard）と Codex 用（.codex/scripts）も同じ一覧にする.
ALLOW_PATTERNS=(
  "AGENTS.md"                         # エージェント共通の作業ルール（AGENTS.md）.
  "CLAUDE.md"                         # Claude Code 用の入口. @AGENTS.md で読み込む（CLAUDE.md）.
  "CLAUDE.local.md"                   # 任意のローカル個人設定. コミットしない（CLAUDE.local.md）.
  "README.md"                         # プロジェクトの概要（README.md）.
  "参考リンク.md"                     # 規約の一次情報の一覧（参考リンク.md）.
  ".gitignore"                        # Git の無視設定（.gitignore）.
  ".gitattributes"                    # 改行コードの固定（.gitattributes）.
  "cpp.slnx"                          # Visual Studio のソリューション（cpp.slnx）.
  "cpp.vcxproj"                       # Visual Studio のプロジェクト（cpp.vcxproj）.
  "cpp.vcxproj.filters"               # Solution Explorer の分類（cpp.vcxproj.filters）.
  "packages.config"                   # NuGet の参照（packages.config）.
  "src/*"                             # C++ ソース（src/）.
  "shaders/*"                         # GLSL シェーダー（shaders/）.
  "scripts/*"                         # spec-kit のランチャー等（scripts/）.
  "specs/*"                           # 仕様書（specs/）. team-change が更新する.
  "docs/*"                            # 日本語訳リファレンス・レビュー結果・マニュアル（docs/）.
  ".specify/*"                        # spec-kit のテンプレート・スクリプト（.specify/）.
  ".claude/*"                         # Claude Code のハーネス（.claude/）.
  ".codex/*"                          # Codex のハーネス（.codex/）.
  ".agent/*"                          # Antigravity のハーネス（.agent/）.
  ".zed/*"                            # Zed のプロジェクト設定（.zed/）.
  "cpp/*"                             # C++ プロジェクトをサブディレクトリに置く構成にしたとき用（cpp/）.
  "rust/*"                            # Rust プロジェクトをサブディレクトリに置く構成にしたとき用（rust/）.
)
# ▲▲▲ 編集してよい範囲はここまで ▲▲▲
# ============================================================

hook_read_input

# 書き込み系ツールでなければ通す（ツール名が取れない場合は安全側で判定を続ける）.
hook_is_write_tool || exit 0

# 編集対象が取得できない場合は誤ブロックを避けて通す.
# ただし黙って通さない。ペイロードのキー名が変わるとここに落ちて、ガードが無効になるため
# （この実装は公開仕様の無いペイロードを grep で読んでいて、node のような解析器を持たない）.
mapfile -t FILES < <(hook_target_paths)
if [[ ${#FILES[@]} -eq 0 ]]; then
  hook_warn "[Hook] WARNING: 書き込み系ツールですが編集対象を読み取れず、編集範囲ガードの検査をスキップしました。ペイロードの形式が変わった可能性があります。"

  exit 0
fi

# リポジトリのルートを求める. 判定をルート基準にしないと、チェックアウト先のディレクトリ名に
# 結果が左右される. スクリプトの位置からは導かない（Claude Code 版はプラグインのキャッシュから
# 実行されるため、スクリプトがリポジトリの外にあることがある）.
REPO_ROOT=$(printf '%s' "${CLAUDE_PROJECT_DIR:-}" | tr '\\' '/')
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null | tr '\\' '/')
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT=$(pwd | tr '\\' '/')
  hook_warn "[Hook] WARNING: リポジトリのルートを特定できないため、作業ディレクトリを使います: $REPO_ROOT"
fi
REPO_ROOT=${REPO_ROOT%/}

# 編集対象をリポジトリルートからの相対パスに直す.
to_relative() {
  local path="$1" lower_path lower_root
  path=$(printf '%s' "$path" | tr '\\' '/')
  path=${path#./}

  # MSYS 形式（/c/...）を Windows 形式（c:/...）に揃える.
  if [[ "$REPO_ROOT" =~ ^[A-Za-z]: && "$path" =~ ^/([A-Za-z])/(.*)$ ]]; then
    path="${BASH_REMATCH[1]}:/${BASH_REMATCH[2]}"
  fi

  lower_path=$(printf '%s' "$path" | tr 'A-Z' 'a-z')
  lower_root=$(printf '%s' "$REPO_ROOT" | tr 'A-Z' 'a-z')

  # ルート配下なら相対化する. 配下でない絶対パスは相対化できないので、そのまま返して
  # 許可リストに一致させない（= 拒否）.
  if [[ "$lower_path" == "$lower_root"/* ]]; then
    printf '%s' "${path:$((${#REPO_ROOT} + 1))}"
  else
    printf '%s' "$path"
  fi
}

DENIED=()

for file in "${FILES[@]}"; do
  relative=$(to_relative "$file")

  allowed=1
  if [[ -n "$relative" ]]; then
    for pattern in "${ALLOW_PATTERNS[@]}"; do
      case "$relative" in
        $pattern) allowed=0; break ;;
      esac
    done
  fi

  [[ $allowed -eq 1 ]] && DENIED+=("$file")
done

[[ ${#DENIED[@]} -eq 0 ]] && exit 0

# 範囲外: 編集を拒否（許可リストを理由文に含める）.
ALLOWED_TEXT=$(printf '%s / ' "${ALLOW_PATTERNS[@]}" | sed -E 's| / $||')
DENIED_TEXT=$(printf '%s, ' "${DENIED[@]}" | sed -E 's|, $||')
hook_deny "編集は許可ディレクトリに限定されています（${ALLOWED_TEXT}）。範囲外のため拒否しました: ${DENIED_TEXT}"
