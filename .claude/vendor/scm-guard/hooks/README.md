# scm-guard

**不可逆・外向きの操作をブロックする** hook だけをまとめたローカルプラグインです。
このプロジェクトは変更を **PR 形式** で行うため、それを迂回してリモートや外部サービスへ
直接書き込む経路を塞ぐことを目的にしています。

## 定義されている hook

| id | イベント | 内容 |
|----|--------|------|
| `scm-guard` | PreToolUse (`Bash`) | リモート履歴を壊す操作／外部への公開・デプロイをブロック |

## ブロック対象

| 分類 | コマンド |
|------|---------|
| Git | `git push --force` / `-f` / `--force-with-lease` / `--force-if-includes`、`git push --delete` / `-d` / `--mirror`、`origin :branch` 形式の削除 refspec、`git send-email` |
| Git（許可） | 追記だけの `git push` は**ブロックしません**。ただし `rules/common/git-workflow.md` に従い、push 前にブランチ名を示してユーザーの了承を取ります |
| GitHub CLI | `gh pr` / `gh issue` の状態変更（`merge` `close` `edit` `reopen` `ready` `review` `lock` `unlock`）、`issue` / `repo` / `release` / `run` / `cache` の `delete` `archive` `transfer` `rename` `edit`、`gh release` の `create` `edit` `upload`、`gh workflow run`、`gh secret set`、`gh variable set`、`gh api` の書き込みメソッド（`-X POST/PUT/PATCH/DELETE`）と `gh api graphql` |
| GitHub CLI（許可） | `gh pr create` / `gh pr comment` / `gh issue create` / `gh repo create` は**ブロックしません**。変更の提案はできるが、マージ・公開・破棄はできない、という切り分けです（`settings.local.json` の `permissions.allow` と対応） |
| 公開・デプロイ | `func ... publish`（Azure Functions）／`dotnet nuget push`／`npm`・`pnpm`・`yarn`・`bun` の `publish`／`docker push` |

スクリプト本体: `scripts/scm-guard.sh`（`${CLAUDE_PLUGIN_ROOT}` 経由で参照）

禁止するコマンドを変えるときは、このスクリプト内の `BLOCK_PATTERNS` ブロックだけを書き換えます。

> NOTE:
> `git cherry-pick` / `git merge` / `git rebase` / `git commit --amend` は**対象外**です。
> リモートには一切触れないローカル操作であり、`git push` を塞いでいれば外へは出ないためです。
> `git reset --hard` などのローカル破壊系も対象外です。

## なぜ permissions.deny だけでは足りないか

`permissions.deny` の `Bash(...)` ルールは**コマンド文字列の前方一致**です。
リポジトリを明示する運用では、実際のコマンドが

```
git -C <リポジトリ> push --force origin develop
```

のように `git` と `push` の間にオプションが入るため、`Bash(git push --force:*)` では一致しません。
`gh` のグローバルオプション付き（`gh --repo o/r pr merge 96`）も同様です。
そのため、このプラグインは**コマンド全文を正規表現で検査**して `deny` を返します。
`permissions.deny` は素の形式に対する第一防御として併用します。

## 判定例

| 拒否 | 通過 |
|------|------|
| `git push -f origin develop` | `git status` / `git commit` / `git fetch` |
| `git -C <リポジトリ> push --force origin HEAD` | `git push origin HEAD`（追記だけの push は通る） |
| `git push --delete origin work/foo` / `git push origin :work/foo` | `git branch -d work/foo`（ローカル操作） |
| `git push --mirror` / `git.exe push -f` | `git revert HEAD` / `git reset --hard` |
| `git send-email --to a@b.c` | `git cherry-pick` / `git rebase` |
| `gh pr merge 96 --squash` / `gh pr close 96` | `gh pr create --fill` / `gh pr comment 96 --body ok` |
| `gh pr edit 96` / `gh pr review --approve 96` | `gh issue create` / `gh repo create foo` |
| `gh issue close 42` / `gh issue edit 42 --body x` | `gh issue view 42` / `gh issue list` |
| `gh release create v1.0.0` / `gh repo delete foo` | `gh pr view 96` / `gh pr list` / `gh pr diff 96` |
| `gh api -X POST ...` / `gh api graphql` | `gh api /repos/o/r/pulls/96`（GET は通る）/ `gh run view 123` |
| `gh workflow run lint.yml` / `gh secret set K` | `dotnet build ...` / `npm run build` |
| `func azure functionapp publish <name>` | `docker compose run --rm dev bash` |
| `dotnet nuget push` / `npm publish` / `docker push` | `ls` |

> NOTE:
> 誤爆より取りこぼしを避ける設計です。`npm run publish` のように
> ローカルのスクリプト名として `publish` という語が現れるコマンドもブロックされます。
> `gh` だけは「サブコマンド + 動詞」の並びで判定するため
> （`pr merge` / `release create` など）、`gh pr create --title "merge fix"` のように
> 引数の中に動詞が現れても、その並びを再現しない限りブロックされません。

## 有効化

`.claude/settings.local.json`:

```json
{
  "extraKnownMarketplaces": {
    "scm-guard": {
      "source": { "source": "directory", "path": "./.claude/vendor/scm-guard" }
    }
  },
  "enabledPlugins": {
    "scm-guard@scm-guard": true
  }
}
```

## 注意点

- hooks は複数ソースから **合算** されます。`settings.local.json` の `"hooks"` に同じ定義を残すと
  **二重実行** になるため、必ずどちらか一方にだけ書いてください。
- プラグインの読み込みは Claude Code の起動時のみ。変更後は再起動が必要です。
- このプラグインが無効・読み込み失敗だと **SCM ガードが効かなくなります**。
  反映後は `/hooks` で登録状況を確認してください。

編集範囲制限の hook は別プラグイン [edit-scope-guard](../../edit-scope-guard/hooks/README.md)、
通知系の hook は [desktop-notify](../../desktop-notify/hooks/README.md) にあります。
