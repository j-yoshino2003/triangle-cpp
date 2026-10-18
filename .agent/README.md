# Antigravity CLI 用ハーネス

**Google Antigravity CLI** でこのハーネスを使うための一式です。Claude Code 版（`.claude/`）・
Codex 版（`.codex/`）と同じ規約・スキル・安全装置を、Antigravity の仕組みに載せ替えてあります。
3 つは同じプロジェクトに同居でき、作業ルールは共通の [`AGENTS.md`](../AGENTS.md) です。

## 使い方

プロジェクトルートに `AGENTS.md` と `.agent/` を置き、そのフォルダーで Antigravity CLI を起動します。
`.agent/skills/` はスラッシュコマンドに自動変換され、`.agent/agents/` のサブエージェントは
`invoke_subagent` で呼び出せます。

セットアップ手順・開発ループの回し方・制約は [`docs/ja-JP/harness-guide.html`](../docs/ja-JP/harness-guide.html)
の「Codex / Antigravity で使う」節を参照してください。

## 構成

| パス | 内容 |
|------|------|
| `../AGENTS.md` | 3 エージェント共通の作業ルール（作業範囲・回答方針・どの規約ファイルを読むかの指示・SCM の開始と終了）。Antigravity はこれを読み込む |
| `agents/` | サブエージェント定義（Markdown）: `investigator` / `implementer`（唯一の編集者）/ レビュアー 8 体（`code-reviewer` / `impact-scope-reviewer` / `silent-failure-hunter` / `coding-standards-reviewer` / `comment-analyzer` / `performance-reviewer` / `simplicity-reviewer` / `pr-test-analyzer`） |
| `skills/` | `team-change` / `p4-cl-cross-review` / `git-pr-cross-review` / `ask-antigravity`（`/<スキル名>` で起動） |
| `rules/` | 規約の複製（英語）: `common-*`（answer-policy / coding-style / code-comments / code-layout / git-workflow / p4-workflow）と `cpp-` / `csharp-` / `rust-` / `unity-` / `unreal-coding-style.md`。正本は `.claude/rules/` |
| `.agents/plugins/coding-harness/` | 同梱プラグイン。`hooks.json` + `scripts/`: 編集範囲ガード・SCM ガード・git コミットガード・push リマインド・p4 シェルブガード（PreToolUse）、PR 作成後・シェルブ後の案内（PostToolUse）、完了通知（Stop） |

日本語リファレンスは共有の `docs/ja-JP/` にあります（規約は `rules/`、Antigravity 版スキルは `skills/antigravity/`）。

## 導入前に揃える 3 箇所

`AGENTS.md` の「作業範囲ルール」の一覧と、次の 3 つの `ALLOW_PATTERNS` を同じ内容にします。

1. `.claude/vendor/edit-scope-guard/scripts/edit-scope-guard.sh`
2. `.codex/scripts/edit-scope-guard.sh`
3. `.agent/.agents/plugins/coding-harness/scripts/edit-scope-guard.sh`

Perforce を使う場合は環境変数 `P4_PROXY`（`ssl:<host>:<port>`）を設定します。サーバーアドレスは
ファイルに書きません。

## グローバルに使う場合

ワークスペースではなく全プロジェクトで使いたい場合の配置先：

| 種類 | グローバルの配置先 |
|------|------------------|
| スキル | `~/.gemini/antigravity-cli/skills/` |
| サブエージェント | `~/.gemini/config/agents/` |
| プラグイン | `~/.gemini/config/plugins/` |
| 共通ルール | `~/.gemini/GEMINI.md` |

## Claude Code 版との違い

| 項目 | Claude Code | Antigravity |
|------|-------------|-------------|
| 規約の読み込み | `.claude/rules/common/` のうち `paths:` を持たない 4 本を自動読み込み、`code-comments` / `code-layout` と言語別は `paths:` で条件読み込み | `AGENTS.md` の指示に従い、共通規約は「作業開始時に `common-answer-policy` / `common-coding-style` / `common-git-workflow` / `common-p4-workflow` を読む」、`common-code-comments` / `common-code-layout` と言語別は「編集前に `.agent/rules/` の該当ファイルを読む」 |
| `team-change` | Agent Teams（共有タスクリスト） | `invoke_subagent` を順に呼ぶオーケストレーション。文脈はすべてプロンプトに書く |
| 読み取り専用のサブエージェント | `tools` で制限 | 公式の読み取り専用モードが無いため、プロンプトで「編集しない」を明示し、`commandExecutionPolicy: off` にする |
| レビュー取得 | `git-harness` / `p4-harness` のスクリプト | 同じスクリプト（`.claude/vendor/*/scripts/`、bash）を共用 |
| フック | Node.js 実装のプラグイン | grep / sed 実装の bash（Node 不要）。応答は `decision` / `reason` 形式。ペイロードの形式は公式に未公開のため防御的に走査 |
