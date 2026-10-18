# AGENTS.md（コーディングエージェント共通の作業ルール）

このファイルは、このプロジェクトで作業するすべてのコーディングエージェント共通のルールです。
特定のエージェントに依存する記述は置かず、ここを唯一の正とします。

| エージェント | このファイルの読み込み方 | ハーネスの置き場 |
|------|------|------|
| Claude Code | `CLAUDE.local.md` の `@AGENTS.md` で参照 | `.claude/`（rules / skills / vendor プラグイン） |
| OpenAI Codex CLI | リポジトリルートの `AGENTS.md` を自動読み込み（`.codex/config.toml` の `project_doc_max_bytes` 内） | `.codex/`（rules の複製 / skills / agents / hooks） |
| Google Antigravity CLI | 作業ディレクトリの `AGENTS.md` を読み込み | `.agent/`（rules の複製 / skills / agents / plugins） |

3 つは同じプロジェクトに同居します。どのエージェントで作業しても、作業範囲・回答方針・規約・SCM の手順は同じです。

## 言語

- ユーザーへの出力・コード内コメント・生成するドキュメントはすべて **日本語** で書く
- 専門用語とコード識別子は原語のまま

## コーディング規約の所在

プロジェクト共通のコーディング規約の **正本は `.claude/rules/`**（英語）です。日本語訳リファレンスは
`docs/ja-JP/rules/` にあります。

- **Claude Code** は `.claude/rules/common/` のうち frontmatter `paths:` を**持たない**ファイルを毎セッション
  自動読み込みします。`paths:` を持つファイル（`common/code-comments.md` / `common/code-layout.md`）と
  言語・エンジン別の規約は、`paths:` に一致するファイルを扱うときだけ読み込まれます。明示的な import は不要です
- **Codex / Antigravity** は `AGENTS.md`（このファイル）を自動で読みますが、そこから他のファイルを自動で
  読み込む仕組みがありません（Codex は `AGENTS.md` を連結するだけ、Antigravity の `@` 参照は rules ファイル用）。
  そのため、下記の複製は **エージェント自身が読んでください**

### 作業開始時に必ず読む（共通規約）

最初の応答を返す前に、次のファイルをすべて読みます。Claude Code が毎セッション自動で読み込むものと同じ内容です。

| Codex | Antigravity |
|------|------|
| `.codex/rules/common-answer-policy.md` | `.agent/rules/common-answer-policy.md` |
| `.codex/rules/common-coding-style.md` | `.agent/rules/common-coding-style.md` |
| `.codex/rules/common-git-workflow.md` | `.agent/rules/common-git-workflow.md` |
| `.codex/rules/common-p4-workflow.md` | `.agent/rules/common-p4-workflow.md` |

`common-code-comments.md` と `common-code-layout.md` は**ここには入れません**。コードの表記・
レイアウトの規約で、ソースファイルを触るときだけ必要なためです（下表の「ソースファイル全般」）。

### 該当する種類のファイルを編集する前に読む（言語・エンジン別）

| 編集するファイル | Codex | Antigravity |
|------|------|------|
| **ソースファイル全般**（`*.h` / `*.hpp` / `*.cpp` / `*.cc` / `*.hh` / `*.cxx` / `*.cs` / `*.csx` / `*.rs` / `CMakeLists.txt`） | `.codex/rules/common-code-comments.md` と `common-code-layout.md` | `.agent/rules/common-code-comments.md` と `common-code-layout.md` |
| `*.h` / `*.hpp` / `*.cpp` / `*.cc` | `.codex/rules/cpp-coding-style.md` | `.agent/rules/cpp-coding-style.md` |
| `*.cs` | `.codex/rules/csharp-coding-style.md` | `.agent/rules/csharp-coding-style.md` |
| `*.rs` | `.codex/rules/rust-coding-style.md` | `.agent/rules/rust-coding-style.md` |
| Unity プロジェクト（`Assets/**`、`Packages/**`） | `.codex/rules/unity-coding-style.md` | `.agent/rules/unity-coding-style.md` |
| Unreal Engine プロジェクト（`Source/**`、`*.uproject`） | `.codex/rules/unreal-coding-style.md` | `.agent/rules/unreal-coding-style.md` |

- 優先順位は **エンジン別 > 言語別 > 共通**
- 規約を変更するときは `.claude/rules/` の正本を先に直し、`.codex/rules/`・`.agent/rules/` の複製と
  `docs/ja-JP/rules/` の日本語訳を追随させる（同期の確認コマンドはリポジトリの `CLAUDE.md` を参照）

## 作業範囲ルール【最重要】

**ファイルの作成・変更・削除が許可されるのは、以下のディレクトリ以下および指定ファイルのみです:**

```
AGENTS.md
CLAUDE.local.md
CLAUDE.md
specs
.specify
.claude
.codex
.agent
.zed
docs
cpp
rust
```

> NOTE: この一覧を変更したら、次の 3 つの `ALLOW_PATTERNS` も同じ内容に揃える
> （編集範囲ガードはエージェントごとに別のフックで動く）.
>
> - `.claude/vendor/edit-scope-guard/scripts/edit-scope-guard.sh`
> - `.codex/scripts/edit-scope-guard.sh`
> - `.agent/.agents/plugins/coding-harness/scripts/edit-scope-guard.sh`

> NOTE: `CLAUDE.md` が一覧に在るのは、**`/speckit.plan` の手順 3 が `.specify/scripts/bash/update-agent-context.sh`
> 経由でルートの `CLAUDE.md` を作る**ためです（無ければ `.specify/templates/agent-file-template.md` から新規作成）.
> このハーネスの入口は `CLAUDE.local.md` → `@AGENTS.md` なので、できた `CLAUDE.md` は**作業ルールの正本ではありません**.
> Claude Code は両方を自動読み込みするため、`CLAUDE.md` には spec-kit が入れる技術スタックの要約だけを置き、
> 作業ルールは `AGENTS.md` 側に集約したままにします. `/speckit.plan` に手順 3 を実行させたくない場合はそう指示します.

1. **編集はこの範囲限定**: 上記のディレクトリ・ファイル以外は編集しない
2. **範囲外が必要なときは停止**: 範囲外のファイル変更が必要になった場合は、作業を進めず必ずユーザーに確認する

## 作業の開始と終了（SCM）

すべての作業（`team-change`、`/speckit.implement`、素の「直して」依頼）に共通の手順です。詳細は上記の共通規約
（`common-git-workflow.md` / `common-p4-workflow.md`）に書いてあります。

- **Git 管理下のファイル（このプロジェクトの既定）**: 最初の編集の前に、checkout が `develop` から切った
  `feature/<name>` にあることを確認する。`develop` や `main` にいるなら先に切る（リリース済みコードへの緊急修正なら
  `main` から `hotfix/<version>`）。編集がビルドを
  通ったら、**別セッション** で作業ツリー（`working`）のレビューを案内するまでが作業の完了。commit・push・PR は
  レビューの後、それぞれユーザーの了承を得て行う。強制 push・リモートブランチ削除・マージはどのエージェントでも
  拒否される
- **Perforce 管理下のファイル**: 最初の編集の前に `p4 change -i` で新しい保留チェンジリストを作り、対象ファイルを
  そこに開く（`p4 edit -c N` など。default CL には残さない）。編集がビルドを通ったら、CL 番号・説明文・ファイル一覧を
  提示して了承を得てからシェルブし、**別セッション** でのレビューを案内するまでが作業の完了。`p4 submit` / `revert` /
  `shelve -d` / `change -d` はどのエージェントでも拒否される（ユーザーが P4V で行う）
- `team-change` と `/speckit.implement` は Git 前提の手順で書いてある。Perforce のファイルを触るときは、上の
  Perforce 側の手順に読み替える
- 変更を書いたセッションではレビューしない。レビューのコマンドはエージェントごとに違う

| 操作 | Claude Code | Codex | Antigravity |
|------|------|------|------|
| 不具合修正・機能変更（仕様書先行） | `/team-change <内容>` | `/prompts:team-change <内容>` | `/team-change <内容>` |
| Git 変更のクロスレビュー | `/review-pr <PR番号 \| ブランチ \| working>` | `/prompts:git-pr-cross-review <同左>` | `/git-pr-cross-review <同左>` |
| 保留 CL のクロスレビュー | `/review-cl <CL>` | `/prompts:p4-cl-cross-review <CL>` | `/p4-cl-cross-review <CL>` |
| エージェント本体の仕様調査 | `/ask-claude-code <質問>` | `/prompts:ask-codex <質問>` | `/ask-antigravity <質問>` |

レビューのレポートは `docs/reviews/`、変更マニュアルは `docs/manuals/` に保存されます（どのエージェントでも同じ）。

