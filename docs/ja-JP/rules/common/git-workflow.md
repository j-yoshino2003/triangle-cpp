# Git ワークフロー

> 正本: `.claude/rules/common/git-workflow.md`（英語）。

## コミットメッセージの形式

```
<type>: <説明>

<本文（任意）>
```

type は次のいずれか。

| type | 用途 |
|------|------|
| `feat` | 機能の追加 |
| `fix` | 不具合の修正 |
| `refactor` | 挙動を変えない内部の整理 |
| `docs` | ドキュメント・コメントの変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルド環境や雑務 |
| `perf` | 性能の改善 |
| `ci` | CI 設定の変更 |

## ブランチ

通常の Git flow。長命なブランチ 2 本と、短命なブランチ 3 種類で運用する。

| ブランチ | 切る元 | マージ先 | 用途 |
|------|------|------|------|
| `main` | — | — | リリース済みのコードだけ。ここへのマージごとにバージョンタグを打つ |
| `develop` | — | — | 統合ブランチ。次のリリース分がここに溜まる |
| `feature/<name>` | `develop` | `develop` | 1 つの変更（修正・機能追加・リファクタリング） |
| `release/<version>` | `develop` | `main` **と** `develop` | リリース準備（バージョン更新、最終修正） |
| `hotfix/<version>` | `main` | `main` **と** `develop` | リリース済みのコードに対する緊急修正 |

- `feature/*` の PR は `develop` に向ける。`release/*` と `hotfix/*` の PR は `main` に向け、同じ変更を
  `develop` にもマージし戻す（しないと次のリリースで消える）。
- `main` と `develop` に直接コミットしない。
- `<name>` はチケット番号だけでなく変更の内容を表す（`feature/123` ではなく `feature/swapchain-resize`）。
  `<version>` は出すバージョン（`release/1.4.0`、`hotfix/1.3.2`）。
- 比較のベースはどこでも `develop` が既定（`git diff`、レビュースキルの `--base`、`gh pr create`）。
  `release/*` と `hotfix/*` では `--base main` を明示する。`develop` と比べると差分が別物になる。

## 作業の開始と終了

**すべて** の作業に適用する。`team-change`、`/speckit.implement`、素の「直して」依頼のいずれでも同じ。

- **開始**: 最初の編集の前に、checkout が短命なブランチにあることを確認する。`develop` か `main` にいるなら、
  先に `develop` から `feature/<name>` を作る。リリース済みコードへの修正なら `main` から
  `hotfix/<version>` を作る。
- **終了**: 編集がビルドを通り、この checkout の新しいセッションで実行する `/review-pr working`
  （未コミット分を含む `develop` との差分レビュー）を案内するまでが作業の完了。commit・push・PR はそのレビューの後で、
  それぞれユーザーの了承を得て行う。レビューの案内前で止めてよいのは、ユーザーがそう指示したときだけ。

## プルリクエストの手順

PR を作成するときは次の順で行う。

1. 最新のコミットだけでなく、コミット履歴全体を確認する
2. `git diff develop...HEAD` で変更全体を把握する
3. 変更内容をまとめた PR の説明文を書く
4. 確認手順（テストプラン）を TODO 形式で添える

## レビューの引き渡し

変更を書いたセッションではレビューしない。レビューは **新しいセッション** で `/review-pr`（`git-pr-cross-review` スキル）を使う。push 済みなら `/review-pr <PR 番号>`、commit や push の前なら同じ checkout で `/review-pr working`。レポートは `docs/reviews/` に保存される。指摘の修正は同じブランチに入れ、同じ方法で再レビューする。

### このプロジェクトでは push は許可、ただし事前に確認する

`scm-guard` は通常の `git push` を許可する。Claude がブランチを push し、続けて
`gh pr create` で PR を作成してよい。ただし **push する直前に対象ブランチを示して了承を得る**。
push は外向きの操作であり、毎回どこへ送るのかを確認したいため。

引き続き拒否されるのは、リモートの履歴を書き換える・消す操作。

| 拒否される操作 | 理由 |
|------|------|
| `git push --force` / `-f` / `--force-with-lease` | リモートにあるコミットを上書きする |
| `git push --delete` / `-d` / `origin :branch` | リモートブランチを削除する |
| `git push --mirror` | リモートの参照をまとめて消しうる |
| `git send-email` | リポジトリの外へパッチを送る |
| `gh pr merge` / `close` / `edit` | マージと PR の状態変更はユーザーの操作 |

これらがどうしても必要な場合は、ガードを迂回せずコマンドをユーザーへ渡す。
