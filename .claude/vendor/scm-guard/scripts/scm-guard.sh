#!/bin/bash
#---------------------------------------
# PreToolUse(Bash): SCM への不可逆・外向き操作をブロックするガード（厳格モード）.
#
# git の強制 push・リモートブランチ削除・外部への公開・デプロイを deny で拒否する.
# 通常の git push は許可する（追記だけなので取り返しがつくため）.
# コマンドの前方一致ではなく全文を正規表現で見るため、
# `git -C <path> push --force` のようなオプション付きも捕捉する.
# 対象を変えたいときは、下の「ブロックするコマンド」ブロックだけを書き換える.
#---------------------------------------

# ============================================================
# ▼▼▼ ここだけ編集する: ブロックするコマンド（拡張正規表現） ▼▼▼
#   ・「コマンド名 + 任意のオプション + サブコマンド」に一致する形で書く.
#   ・1 パターン 1 行。末尾コメントで用途を書く.
#   ・行を増減するだけで禁止範囲を変更できる.
#   ・grep -E -i で判定するため大文字小文字は区別しない.
BLOCK_PATTERNS=(
  # --- Git: 通常の push は許可し、履歴やブランチを壊す形だけをブロックする ---
  #     （追記だけの push は取り返しがつくが、force と削除はリモートの履歴を消すため）.
  '(^|[[:space:];&|(])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?send-email([[:space:]]|$)'                                                      # パッチのメール送信.
  '(^|[[:space:];&|(])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?push[[:space:]]+([^;&|]*[[:space:]])?(--force|--force-with-lease|--force-if-includes|-f)([[:space:]=]|$)'  # 強制 push.
  '(^|[[:space:];&|(])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?push[[:space:]]+([^;&|]*[[:space:]])?(--delete|--mirror|-d)([[:space:]=]|$)'    # リモートブランチの削除.
  '(^|[[:space:];&|(])git(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?push[[:space:]]+([^;&|]*[[:space:]])?:[^[:space:];&|]'                          # 「:branch」形式の削除 refspec.

  # --- GitHub CLI: PR / Issue の「作成・コメント」は許可し、既存物の状態変更と公開をブロックする ---
  #     （変更の提案はできるが、マージ・公開・破棄はできない、という切り分け）.
  '(^|[[:space:];&|(])gh(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?(pr|issue)[[:space:]]+(merge|close|edit|reopen|ready|review|lock|unlock)([[:space:]]|$)'  # PR / Issue の状態変更・自己承認.
  '(^|[[:space:];&|(])gh(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?(issue|repo|release|run|cache)[[:space:]]+(delete|archive|transfer|rename|edit)([[:space:]]|$)' # 既存リソースの破棄・移管・設定変更.
  '(^|[[:space:];&|(])gh(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?release[[:space:]]+(create|edit|upload)([[:space:]]|$)'                                    # リリースの公開.
  '(^|[[:space:];&|(])gh(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?(workflow[[:space:]]+run|secret[[:space:]]+set|variable[[:space:]]+set)([[:space:]]|$)'
  '(^|[[:space:];&|(])gh(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?api[[:space:]]+([^;&|]*[[:space:]])?(-X|--method)[[:space:]=]+(post|put|patch|delete)'  # gh api の書き込みメソッド.
  '(^|[[:space:];&|(])gh(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?api[[:space:]]+([^;&|]*[[:space:]])?graphql([[:space:]]|$)'                            # graphql は既定で POST.

  # --- パッケージ公開・本番デプロイ ---
  '(^|[[:space:];&|(])func(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?publish([[:space:]]|$)'                # Azure Functions のデプロイ.
  '(^|[[:space:];&|(])nuget[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$)'                          # dotnet nuget push / nuget push.
  '(^|[[:space:];&|(])(npm|pnpm|yarn|bun)(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?publish([[:space:]]|$)' # npm レジストリへの公開.
  '(^|[[:space:];&|(])docker(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$)'                 # コンテナレジストリへの push.
)

# 拒否時にモデルへ返す理由文.
DENY_REASON='このコマンドはハーネスで禁止されています（リモート履歴の破壊 / 外部への公開・デプロイ）。通常の git push は許可されています。強制 push・リモートブランチ削除・マージはユーザー自身の操作です。'
# ▲▲▲ 編集してよい範囲はここまで ▲▲▲
# ============================================================

INPUT=$(cat)

# JSON の解析は node で行う（Claude Code の npm 版は Node.js 前提のため確実に存在する）.
COMMAND=$(printf '%s' "$INPUT" | node -e "
let raw = '';
process.stdin.on('data', chunk => raw += chunk);
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw).tool_input || {};
    process.stdout.write(input.command || '');
  } catch {
    process.stdout.write('');
  }
});
" 2>/dev/null)

# command が取得できない場合は誤ブロックを避けて通す.
[[ -z "$COMMAND" ]] && exit 0

# ブロックパターンのいずれかに一致すれば拒否する.
for pattern in "${BLOCK_PATTERNS[@]}"; do
  if printf '%s' "$COMMAND" | grep -Eqi "$pattern"; then
    node -e "
const [reason, command] = process.argv.slice(1);
console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'PreToolUse',
    permissionDecision: 'deny',
    permissionDecisionReason: reason + ' 拒否したコマンド: ' + command
  }
}));
" "$DENY_REASON" "$COMMAND"
    exit 0
  fi
done

exit 0
