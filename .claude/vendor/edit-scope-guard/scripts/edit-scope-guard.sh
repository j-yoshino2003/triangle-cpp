#!/bin/bash
#---------------------------------------
# PreToolUse(Edit|Write): 編集を許可ディレクトリ内に限定するガード（厳格モード）.
#
# 許可リスト外への Edit / Write / NotebookEdit を deny で拒否する.
# 対象を変えたいときは、下の「編集を許可するパス」ブロックだけを書き換える.
#---------------------------------------

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
#     Codex 用（.codex/scripts）と Antigravity 用（.agent/.agents/plugins/coding-harness）も同じ一覧にする.
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

INPUT=$(cat)

# 入力そのものが空なら判定対象が無い. これは「解析に失敗した」とは別なので通す.
[[ -z "$INPUT" ]] && exit 0

# 固定文のみを使う拒否（JSON のエスケープが要らない形）. node が使えない場合に使う.
deny_fixed() {
  printf '%s\n' "$1" >&2
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# node はペイロード解析の前提. 無いまま続けると編集対象が空になり、範囲外の編集が
# 無言で通る. 検査できないことを隠さずに拒否する.
if ! command -v node >/dev/null 2>&1; then
  deny_fixed 'node が見つからないため編集範囲ガードが対象を検査できません。Node.js を PATH に通してから再実行してください。'
fi

# JSON の解析は node で行う（Claude Code の npm 版は Node.js 前提のため確実に存在する）.
# 「解析できて対象が無い」と「解析そのものが失敗した」を区別する. 両者を同一視すると、
# ペイロードの形が変わった時点でガードが無言で無効になる.
PARSED=$(printf '%s' "$INPUT" | node -e "
let raw = '';
process.stdin.on('data', chunk => raw += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw).tool_input || {};
    process.stdout.write('ok:' + (input.file_path || input.notebook_path || ''));
  } catch (e) {
    process.stdout.write('error:' + ((e && e.message) || 'JSON parse failed'));
  }
});
")

case "$PARSED" in
  ok:*)
    FILE=${PARSED#ok:}
    ;;
  error:*)
    printf '[Hook] ペイロードを解析できませんでした: %s\n' "${PARSED#error:}" >&2
    deny_fixed 'ペイロードを解析できないため編集範囲ガードが対象を検査できません。入力の形式が変わった可能性があります。'
    ;;
  *)
    printf '[Hook] node の出力が想定外でした: %s\n' "$PARSED" >&2
    deny_fixed 'ペイロードの解析結果が想定外のため編集範囲ガードが対象を検査できません。'
    ;;
esac

# 解析はできたが編集対象が無い（編集系以外のツール等）. 判定対象が無いので通す.
[[ -z "$FILE" ]] && exit 0

# リポジトリのルートを求める. 判定をルート基準にしないと、チェックアウト先のディレクトリ名に
# 結果が左右される. スクリプトの位置からは導かない（このプラグインは ~/.claude/plugins/cache/
# へ複製されて実行されるため、スクリプトはリポジトリの外にある）.
REPO_ROOT=$(printf '%s' "${CLAUDE_PROJECT_DIR:-}" | tr '\\' '/')
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null | tr '\\' '/')
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT=$(pwd | tr '\\' '/')
  printf '[Hook] WARNING: リポジトリのルートを特定できないため、作業ディレクトリを使います: %s\n' "$REPO_ROOT" >&2
fi
REPO_ROOT=${REPO_ROOT%/}

# 編集対象をリポジトリルートからの相対パスに直す.
NORMALIZED=$(printf '%s' "$FILE" | tr '\\' '/')
NORMALIZED=${NORMALIZED#./}

# MSYS 形式（/c/...）を Windows 形式（c:/...）に揃える.
if [[ "$REPO_ROOT" =~ ^[A-Za-z]: && "$NORMALIZED" =~ ^/([A-Za-z])/(.*)$ ]]; then
  NORMALIZED="${BASH_REMATCH[1]}:/${BASH_REMATCH[2]}"
fi

LOWER_PATH=$(printf '%s' "$NORMALIZED" | tr 'A-Z' 'a-z')
LOWER_ROOT=$(printf '%s' "$REPO_ROOT" | tr 'A-Z' 'a-z')

# ルート配下なら相対化する. 配下でない絶対パスは相対化できないので、そのまま照合して
# 許可リストに一致させない（= 拒否）.
if [[ "$LOWER_PATH" == "$LOWER_ROOT"/* ]]; then
  RELATIVE="${NORMALIZED:$((${#REPO_ROOT} + 1))}"
else
  RELATIVE="$NORMALIZED"
fi

# 許可パターンのいずれかに一致すれば通す.
if [[ -n "$RELATIVE" ]]; then
  for pattern in "${ALLOW_PATTERNS[@]}"; do
    case "$RELATIVE" in
      $pattern) exit 0 ;;
    esac
  done
fi

# 範囲外: 編集を拒否（許可リストを理由文に含める）.
node -e "
const [file, ...patterns] = process.argv.slice(1);
const allowed = patterns.join(' / ');
console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'PreToolUse',
    permissionDecision: 'deny',
    permissionDecisionReason: '編集は許可ディレクトリに限定されています（' + allowed + '）。範囲外のため拒否しました: ' + file
  }
}));
" "$FILE" "${ALLOW_PATTERNS[@]}"
exit 0
