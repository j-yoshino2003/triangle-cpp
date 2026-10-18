# desktop-notify

**デスクトップ通知**の hook だけをまとめたローカルプラグインです。

## 定義されている hooks

| id | イベント | 内容 |
|----|--------|------|
| `notify-input-needed` | Notification | 入力待ちをトースト通知（`入力が必要です` / Warning） |
| `notify-task-done` | Stop | タスク完了をトースト通知（`タスクが完了しました` / Info） |

スクリプト本体: `scripts/desktop-notify.sh`（`${CLAUDE_PLUGIN_ROOT}` 経由で参照）

編集範囲制限の hook は別プラグイン [edit-scope-guard](../../edit-scope-guard/hooks/README.md)、
SCM・公開系の hook は [scm-guard](../../scm-guard/hooks/README.md) にあります。

## 有効化

`.claude/settings.local.json`:

```json
{
  "extraKnownMarketplaces": {
    "desktop-notify": {
      "source": { "source": "directory", "path": "./.claude/vendor/desktop-notify" }
    }
  },
  "enabledPlugins": {
    "desktop-notify@desktop-notify": true
  }
}
```

## 注意点

- hooks は複数ソースから **合算** されます。`settings.local.json` の `"hooks"` に同じ定義を残すと
  トーストが **2 回** 出ます。必ずどちらか一方にだけ書いてください。
- プラグインの読み込みは Claude Code の起動時のみ。変更後は再起動が必要です。
- 通知を一時的に止めたいときは `enabledPlugins` の `desktop-notify@desktop-notify` を
  `false` にするだけで、編集ガード・SCM ガード側には影響しません。
