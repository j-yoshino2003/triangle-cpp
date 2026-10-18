# edit-scope-guard

**編集範囲制限**の hook だけをまとめたローカルプラグインです。

## 定義されている hook

| id | イベント | 内容 |
|----|--------|------|
| `edit-scope-guard` | PreToolUse (`Edit` / `Write` / `NotebookEdit`) | `AGENTS.md` の作業範囲外への編集をブロック |

スクリプト本体: `scripts/edit-scope-guard.sh`（`${CLAUDE_PLUGIN_ROOT}` 経由で参照）

許可パスを変えるときは、このスクリプト内の `ALLOW_PATTERNS` ブロックだけを書き換えます
（`AGENTS.md` の作業範囲ルールと内容を揃えてください）。

SCM・公開系の hook は別プラグイン [scm-guard](../../scm-guard/hooks/README.md)、
通知系の hook は [desktop-notify](../../desktop-notify/hooks/README.md) にあります。

## 有効化

`.claude/settings.local.json`:

```json
{
  "extraKnownMarketplaces": {
    "edit-scope-guard": {
      "source": { "source": "directory", "path": "./.claude/vendor/edit-scope-guard" }
    }
  },
  "enabledPlugins": {
    "edit-scope-guard@edit-scope-guard": true
  }
}
```

## 注意点

- hooks は複数ソースから **合算** されます。`settings.local.json` の `"hooks"` に同じ定義を残すと
  **二重実行** になるため、必ずどちらか一方にだけ書いてください。
- プラグインの読み込みは Claude Code の起動時のみ。変更後は再起動が必要です。
- このプラグインが無効・読み込み失敗だと **編集ガードが効かなくなります**。
  反映後は `/hooks` で登録状況を確認してください。
