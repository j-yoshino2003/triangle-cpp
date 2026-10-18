# ask-antigravity

> 正本: `.agent/skills/ask-antigravity/SKILL.md`（英語）。

## このスキルの目的

Antigravity 自体の挙動・設定・拡張ポイントに関する質問を受け取り、**公式ドキュメント**を調査して、
根拠つきで日本語で回答します。

対象となる質問：

- 機能の有無と使い方（「フックで特定のコマンドだけブロックできる?」「サブエージェントの定義方法は?」）
- 設定の意味と書き方（`settings.json` / 権限 / サンドボックス / 実行モード）
- スラッシュコマンド・キーボードショートカット
- MCP サーバーの接続と管理
- スキル・プラグイン・ルール・ワークフロー

> **Antigravity にはドキュメント調査専用の組み込みエージェントがありません。**
> そのため、本スキルは調査を委譲せず、自分で公式ドキュメントを調査します。

## ユーザー入力

調べたい質問を引数として受け取ります。

### 引数チェック

質問が空の場合は、以下を表示して **処理を中断** してください：

```
エラー: Antigravity について調べたい質問を記述してください。

使い方:
  /ask-antigravity <質問>

例:
  /ask-antigravity PreToolUse フックで特定のコマンドだけブロックできる?
  /ask-antigravity permissions の allow / deny / ask の優先順位は?
```

## ワークフロー

1. **公式ドキュメントを調査する**。以下を起点に、質問に該当するページへたどる：
   - CLI 概要: `https://antigravity.google/docs/cli/overview`
   - CLI 設定: `https://antigravity.google/docs/cli/settings`
   - CLI 権限: `https://antigravity.google/docs/cli/permissions`
   - CLI サンドボックス: `https://antigravity.google/docs/cli/sandbox`
   - CLI サブエージェント: `https://antigravity.google/docs/cli/subagents`
   - CLI プラグイン・スキル: `https://antigravity.google/docs/cli/plugins`
   - CLI リファレンス（スラッシュコマンド・ショートカット）: `https://antigravity.google/docs/cli/reference`
   - スキル: `https://antigravity.google/docs/skills`
   - ルール・ワークフロー: `https://antigravity.google/docs/rules-workflows`
   - フック: `https://antigravity.google/docs/hooks`
   - プラグイン: `https://antigravity.google/docs/plugins`
   - MCP: `https://antigravity.google/docs/mcp`

   ドキュメントは **Antigravity CLI** / **Antigravity IDE** / **Antigravity 2.0** に分かれています。
   IDE 向けに書かれている機能が CLI にも存在するとは限らないため、**読んだページがどの面のものか**
   を明示して回答します。

   オフライン環境の場合は、その旨を明示したうえで既存知識のみで回答します。

2. **日本語で整理して報告する**。
   - 設定例・コマンド例はコードブロックで示す。
   - 実際に読んだドキュメントの URL を併記する。

3. **不確実性の扱い**: 確認できなかった事項は断定せず「未確認」と明示する
   （`.agent/rules/common-answer-policy.md` 準拠）。それらしい設定キーを、ドキュメントで確認せずに
   事実として提示してはならない。

## 注意点

- 本スキルは **調査専用**。設定変更が必要と判明した場合も、回答を提示してユーザーの指示を待つ
  （自分でファイルを変更しない）。
- Antigravity のドキュメントは更新が速い。ページが 404 の場合は URL を推測せず、
  `https://antigravity.google/docs/getting-started` から探し直す。
