#!/bin/bash
#---------------------------------------
# PreToolUse(Edit|Write): 編集を許可ディレクトリ内に限定するガード（厳格モード）.
#
# 許可リスト外への Edit / Write / NotebookEdit を deny で拒否する.
# 対象を変えたいときは、下の「編集を許可するパス」ブロックだけを書き換える.
#---------------------------------------

# ============================================================
# ▼▼▼ ここだけ編集する: 編集を許可するパス（glob パターン） ▼▼▼
#   ・case 文の glob 形式で記述する（例: */dir/sub/*）.
#   ・1 パターン 1 行。末尾コメントで用途を書く.
#   ・行を増減するだけで許可範囲を変更できる.
#   ・区切り文字は「/」で書く（Windows の「\」区切りは判定前に「/」へ正規化される）.
#   ・AGENTS.md の「作業範囲ルール」の一覧と同じ内容に揃える（片方だけ変えない）.
#     Codex 用（.codex/scripts）と Antigravity 用（.agent/.agents/plugins/coding-harness）も同じ一覧にする.
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

INPUT=$(cat)

# JSON の解析は node で行う（Claude Code の npm 版は Node.js 前提のため確実に存在する）.
FILE=$(printf '%s' "$INPUT" | node -e "
let raw = '';
process.stdin.on('data', chunk => raw += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw).tool_input || {};
    process.stdout.write(input.file_path || input.notebook_path || '');
  } catch {
    process.stdout.write('');
  }
});
" 2>/dev/null)

# file_path が取得できない場合は誤ブロックを避けて通す.
[[ -z "$FILE" ]] && exit 0

# Windows のパス区切り「\」を「/」へ正規化する（許可パターンを「/」だけで書けるようにするため）.
FILE="${FILE//\\//}"

# 許可パターンのいずれかに一致すれば通す.
for pattern in "${ALLOW_PATTERNS[@]}"; do
  case "$FILE" in
    $pattern) exit 0 ;;
  esac
done

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
