# AGENTS.md（コーディングエージェント共通の作業ルール）

このファイルは、このプロジェクトで作業するすべてのコーディングエージェント共通のルールです。
特定のエージェントに依存する記述は置かず、ここを唯一の正とします。

| エージェント | このファイルの読み込み方 | ハーネスの置き場 |
|------|------|------|
| Claude Code | `CLAUDE.md` の `@AGENTS.md` で参照 | `.claude/`（rules / skills / vendor プラグイン） |
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
  `docs/ja-JP/rules/` の日本語訳を追随させる

### 複製の同期を確認する

`.codex/rules/` と `.agent/rules/` は `.claude/rules/` の**バイト単位の複製**です
（`common/answer-policy.md` → `common-answer-policy.md` のように、ディレクトリ区切りを `-` にする）。
次のコマンドで差分と欠落を検出できます。出力が無ければ同期済みです。

```bash
for src in .claude/rules/*/*.md; do
  flat=$(echo "${src#.claude/rules/}" | tr '/' '-')
  for copy in ".codex/rules/$flat" ".agent/rules/$flat"; do
    [ -f "$copy" ] || { echo "欠落: $copy"; continue; }
    cmp -s "$src" "$copy" || echo "差分: $src <-> $copy"
  done
done
```

`docs/ja-JP/rules/` は日本語訳なので内容は一致しません。対応するファイルが在るかだけを見ます。

```bash
for src in .claude/rules/*/*.md; do
  [ -f "docs/ja-JP/rules/${src#.claude/rules/}" ] || echo "翻訳なし: ${src#.claude/rules/}"
done
```

## 作業範囲ルール【最重要】

**ファイルの作成・変更・削除が許可されるのは、以下のディレクトリ以下および指定ファイルのみです。**
パスはすべて **リポジトリのルートからの相対** です。

| 対象 | 内容 |
|------|------|
| `AGENTS.md` | エージェント共通の作業ルール（このファイル） |
| `CLAUDE.md` | Claude Code 用の入口。`@AGENTS.md` でこのファイルを読み込む |
| `CLAUDE.local.md` | 任意。Claude Code のローカル個人設定を置きたくなったとき用（コミットしない） |
| `README.md` | プロジェクトの概要 |
| `参考リンク.md` | 規約の一次情報の一覧 |
| `.gitignore` / `.gitattributes` | Git の無視設定と改行コードの固定 |
| `cpp.slnx` / `cpp.vcxproj` / `cpp.vcxproj.filters` | Visual Studio のソリューションとプロジェクト |
| `packages.config` | NuGet の参照 |
| `src/` | C++ ソース |
| `shaders/` | GLSL シェーダー |
| `scripts/` | spec-kit のランチャー等 |
| `specs/` | 仕様書. `team-change` が更新する |
| `docs/` | 日本語訳リファレンス・レビュー結果・マニュアル |
| `.specify/` | spec-kit のテンプレート・スクリプト |
| `.claude/` / `.codex/` / `.agent/` | 各エージェントのハーネス |
| `.zed/` | Zed のプロジェクト設定 |
| `cpp/` / `rust/` | 各プロジェクトをサブディレクトリに置く構成にしたとき用（現在は未使用） |

ビルド出力（`x64/`）、NuGet が展開したパッケージ（`packages/`）、Visual Studio のローカル状態
（`.vs/`、`*.vcxproj.user`）は**範囲外**です。編集する必要はなく、ガードが拒否します。

> NOTE: この一覧を変更したら、次の 3 つの `ALLOW_PATTERNS` も同じ内容に揃える
> （編集範囲ガードはエージェントごとに別のフックで動く）.
>
> - `.claude/vendor/edit-scope-guard/scripts/edit-scope-guard.sh`
> - `.codex/scripts/edit-scope-guard.sh`
> - `.agent/.agents/plugins/coding-harness/scripts/edit-scope-guard.sh`
>
> パターンは**リポジトリのルートからの相対パス**で書き、先頭に `*/` は付けない.
> `*/cpp/*` のような書き方にすると、`case` の `*` が `/` にも一致するため、
> 「チェックアウトしたディレクトリがたまたま `cpp` という名前であること」に判定が依存する.
> その状態では範囲外のパスまで通り、別の名前で clone すると逆に正しいパスが拒否される.
> ルート直下のファイルは 1 件ずつ名前で挙げる（`*` が `/` に一致するため、
> ディレクトリを 1 つ許可したつもりで配下の別ディレクトリまで通ってしまう）.

> NOTE: ガードは Claude Code のプラグインとして `~/.claude/plugins/cache/` へ複製されて実行される.
> リポジトリ側のスクリプトを直しても、プラグインを再読み込みするまで実際の判定は変わらない.
> 変更したら、強制されている内容が意図どおりかを範囲外のパスへの編集で 1 度試して確かめる.

> NOTE: このハーネスの入口は `CLAUDE.md` → `@AGENTS.md` です. `CLAUDE.md` 自体は**作業ルールの正本ではなく**、
> 正本はこの `AGENTS.md` です.
>
> `/speckit.plan` の手順 3 が `.specify/scripts/bash/update-agent-context.sh` 経由で同じ `CLAUDE.md` を更新します.
> 既にファイルが在る場合は**その場での更新**になり、書き換わるのは `## Active Technologies` と
> `## Recent Changes` の 2 節だけです（無ければ末尾に追加されます）. したがって `@AGENTS.md` の行は残り、
> spec-kit が入れる技術スタックの要約と共存します. `/speckit.plan` に手順 3 を実行させたくない場合はそう指示します.

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

