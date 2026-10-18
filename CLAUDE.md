# CLAUDE.md（Claude Code 用の入口）

作業ルールは他のコーディングエージェントと共用するため、[AGENTS.md](AGENTS.md) に集約しています。

@AGENTS.md

このファイルには、Claude Code 固有かつ他のエージェントと共有しない設定だけを追記してください。
作業範囲ルール・規約の所在など、エージェント共通の内容は `AGENTS.md` 側に書きます。

> NOTE: `/speckit.plan` の手順 3 が `.specify/scripts/bash/update-agent-context.sh` 経由でこのファイルを
> 更新します。更新されるのは `## Active Technologies` と `## Recent Changes` の 2 節だけで（無ければ
> 末尾に追加されます）、それ以外の記述はそのまま残ります。上の `@AGENTS.md` を消さないでください。
