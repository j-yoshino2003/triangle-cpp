# ask-codex

> 正本: `.codex/skills/ask-codex/SKILL.md`（英語）。

## このスキルの目的

Codex 自体の挙動・設定・拡張ポイントに関する質問を受け取り、**公式ドキュメント**を調査して、
根拠つきで日本語で回答します。

対象となる質問：

- 機能の有無と使い方（「フックで特定のコマンドだけブロックできる?」「サブエージェントの定義方法は?」）
- 設定の意味と書き方（`config.toml` / `AGENTS.md` / 承認方針 / サンドボックス / 環境変数）
- スラッシュコマンド・キーボードショートカット
- MCP サーバーの接続と管理
- スキル・プラグイン

> **Codex にはドキュメント調査専用の組み込みエージェントがありません。**
> そのため、本スキルは調査を委譲せず、自分で公式ドキュメントを調査します。

## ユーザー入力

調べたい質問を引数として受け取ります。

### 引数チェック

質問が空の場合は、以下を表示して **処理を中断** してください：

```
エラー: Codex について調べたい質問を記述してください。

使い方:
  /prompts:ask-codex <質問>

例:
  /prompts:ask-codex PreToolUse フックで特定のコマンドだけブロックできる?
  /prompts:ask-codex .codex/config.toml と ~/.codex/config.toml の優先順位は?
```

## ワークフロー

1. **公式ドキュメントを調査する**。以下を起点に、質問に該当するページへたどる：
   - 設定リファレンス: `https://developers.openai.com/codex/config-file/config-reference`
   - 設定の基本: `https://developers.openai.com/codex/config-file/config-basic`
   - AGENTS.md: `https://developers.openai.com/codex/agent-configuration/agents-md`
   - サブエージェント: `https://developers.openai.com/codex/agent-configuration/subagents`
   - フック: `https://developers.openai.com/codex/hooks`
   - スキル・プラグイン: `https://developers.openai.com/codex/skills-and-plugins`
   - スラッシュコマンド: `https://developers.openai.com/codex/reference/slash-commands`
   - サンドボックス: `https://developers.openai.com/codex/sandboxing`
   - MCP: `https://developers.openai.com/codex/extend/mcp`

   Web アクセスには `config.toml` の `web_search` が有効（`cached` / `indexed` / `live`）である
   必要があります。`disabled` またはオフライン環境の場合は、その旨を明示したうえで既存知識のみで
   回答します。

2. **日本語で整理して報告する**。
   - 設定例・コマンド例はコードブロックで示す。
   - 実際に読んだドキュメントの URL を併記する。

3. **不確実性の扱い**: 確認できなかった事項は断定せず「未確認」と明示する
   （`.codex/rules/common-answer-policy.md` 準拠）。それらしい設定キーを、ドキュメントで確認せずに
   事実として提示してはならない。

## 注意点

- 本スキルは **調査専用**。設定変更が必要と判明した場合も、回答を提示してユーザーの指示を待つ
  （自分でファイルを変更しない）。
- Codex のドキュメントは更新が速い。ページが 404 の場合は URL を推測せず、
  `https://developers.openai.com/codex/` から探し直す。
