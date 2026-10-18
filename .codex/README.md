# Codex CLI 用ハーネス

**OpenAI Codex CLI** でこのハーネスを使うための一式です。Claude Code 版（`.claude/`）・
Antigravity CLI 版（`.agent/`）と同じ規約・スキル・安全装置を、Codex の仕組みに載せ替えてあります。
3 つは同じプロジェクトに同居でき、作業ルールは共通の [`AGENTS.md`](../AGENTS.md) です。

## 使い方

プロジェクトルートに `AGENTS.md` と `.codex/` を置き、そのフォルダーで `codex` を起動して
プロジェクトの信頼確認を承認します（`.codex/` の設定・フック・サブエージェントは信頼済み
プロジェクトでしか読み込まれません）。

セットアップ手順・開発ループの回し方・制約は [`docs/ja-JP/harness-guide.html`](../docs/ja-JP/harness-guide.html)
の「Codex / Antigravity で使う」節を参照してください。

## 構成

| パス | 内容 |
|------|------|
| `../AGENTS.md` | 3 エージェント共通の作業ルール（作業範囲・回答方針・どの規約ファイルを読むかの指示・SCM の開始と終了）。Codex はこれを自動読み込みする |
| `config.toml` | モデル・推論強度・承認方針・サンドボックス・通知・`project_doc_max_bytes` |
| `hooks.json` + `scripts/` | PreToolUse: 編集範囲ガード・SCM ガード・git コミットガード・push リマインド・p4 シェルブガード。PostToolUse: PR 作成後・シェルブ後の案内。Stop: 完了通知 |
| `rules/` | 規約の複製（英語）: `common-*`（answer-policy / coding-style / code-comments / code-layout / git-workflow / p4-workflow）と `cpp-` / `csharp-` / `rust-` / `unity-` / `unreal-coding-style.md`。正本は `.claude/rules/` |
| `agents/` | サブエージェント定義（TOML）: `investigator` / `implementer`（唯一の編集者）/ レビュアー 8 体（`code-reviewer` / `impact-scope-reviewer` / `silent-failure-hunter` / `coding-standards-reviewer` / `comment-analyzer` / `performance-reviewer` / `simplicity-reviewer` / `pr-test-analyzer`） |
| `skills/` | `team-change` / `p4-cl-cross-review` / `git-pr-cross-review` / `ask-codex`（`/prompts:<スキル名>` で起動） |

日本語リファレンスは共有の `docs/ja-JP/` にあります（規約は `rules/`、Codex 版スキルは `skills/codex/`）。

## 導入前に揃える 3 箇所

`AGENTS.md` の「作業範囲ルール」の一覧と、次の 3 つの `ALLOW_PATTERNS` を同じ内容にします。

1. `.claude/vendor/edit-scope-guard/scripts/edit-scope-guard.sh`
2. `.codex/scripts/edit-scope-guard.sh`
3. `.agent/.agents/plugins/coding-harness/scripts/edit-scope-guard.sh`

Perforce を使う場合は環境変数 `P4_PROXY`（`ssl:<host>:<port>`）を設定します。サーバーアドレスは
ファイルに書きません。

## Claude Code 版との違い

| 項目 | Claude Code | Codex |
|------|-------------|-------|
| 規約の読み込み | `.claude/rules/common/` のうち `paths:` を持たない 4 本を自動読み込み、`code-comments` / `code-layout` と言語別は `paths:` で条件読み込み | `AGENTS.md` の指示に従い、共通規約は「作業開始時に `common-answer-policy` / `common-coding-style` / `common-git-workflow` / `common-p4-workflow` を読む」、`common-code-comments` / `common-code-layout` と言語別は「編集前に `.codex/rules/` の該当ファイルを読む」 |
| `team-change` | Agent Teams（共有タスクリスト） | サブエージェントを順に呼ぶオーケストレーション。文脈はすべてプロンプトに書く |
| レビュー取得 | `git-harness` / `p4-harness` のスクリプト | 同じスクリプト（`.claude/vendor/*/scripts/`、bash）を共用 |
| フック | Node.js 実装のプラグイン | grep / sed 実装の bash（Node 不要）。ペイロードの形式は公式に未公開のため防御的に走査 |
| 許可リスト | `permissions.allow / deny` | 無し（`approval_policy` と `sandbox_mode` で代替し、フックが唯一の防御線） |
