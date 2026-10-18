# Perforce ワークフロー

> 正本: `.claude/rules/common/p4-workflow.md`（英語）。
> 手順の詳細: `.claude/vendor/p4-harness/` のスキル `p4-workflow`。

## チェンジリスト説明文の形式

```
<type>: <description>

<任意の本文（日本語）>
```

type は feat / fix / refactor / docs / test / chore / perf / ci。コミットメッセージと同じ。

## 作業の開始と終了

Perforce 管理下のファイルに触る作業 **すべて** に適用する。`team-change`、`/speckit.implement`、
素の「直して」依頼のいずれでも同じ。

- **開始**: 最初の編集の前に `p4 change -i` で新しい保留 CL を作り（説明文は `<type>: <description>`）、
  以後のファイルはすべてその CL に開く（`p4 edit -c N` / `add -c N` / `delete -c N`）。
  default CL にファイルを残さない。別の作業の CL を使い回さない。
- **終了**: 編集がビルドを通り、CL に意図したファイルだけが入っていることを `/p4-status` で確認し、
  ユーザーの了承を得てシェルブし、新しいセッションで実行する `/review-cl <CL>` を案内するまでが作業の完了。
  シェルブ前で止めてよいのは、ユーザーがそう指示したときだけ。

## Claude に許される操作

| 操作 | ルール |
|------|------|
| `p4 edit` / `add` / `delete` / `reopen` / `change -i` | 許可。必ず説明文付きの番号付き CL に入れる |
| `p4 shelve` | CL 番号・説明文・対象ファイル一覧をユーザーに提示して了承を得た **後** に許可 |
| `p4 submit` / `revert` / `shelve -d` / `change -d` / `obliterate` | `scm-guard` と `p4-harness` が拒否。ユーザーが P4V で行う |

すべての p4 コマンドは `p4 -p "$P4_PROXY"` で実行する。`P4_PROXY` は到達可能なサーバーのアドレスで、
ファイルには書かない。

## レビューの引き渡し

変更を書いたセッションではレビューしない。シェルブ後、**新しいセッション**で `/review-cl <CL>`
（`p4-cl-cross-review` スキル）を実行する。指摘の修正は同じ CL に入れて `p4 shelve -r -c <CL>` で
再シェルブし、再レビューする。

拒否される操作が本当に必要なときは、ガードを回避せず、ユーザーにコマンドか P4V の手順を渡す。
