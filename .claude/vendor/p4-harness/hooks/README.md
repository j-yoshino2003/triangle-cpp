# p4-harness

**Perforce 運用**のためのローカルプラグインです。git-harness の P4 版で、Claude が
`p4 edit / add / delete` でファイルを開き、説明文付きの保留チェンジリスト（CL）を作り、
ユーザー確認のうえで `p4 shelve` するところまでを扱います。**submit と revert は扱いません**
（scm-guard と本プラグインの両方が拒否します）。

## 定義されている hooks

| スクリプト | イベント | 内容 |
|----|--------|------|
| `block-p4-destructive.js` | PreToolUse(Bash) | `p4 submit` / `revert` / `obliterate` / `shelve -d` / `change -d` を拒否（exit 2） |
| `pre-bash-shelve-quality.js` | PreToolUse(Bash) | `p4 shelve` の直前に、対象 CL で開いているファイルの秘密情報・デバッグ残骸を検査し、CL 説明文の形式（`<type>: <description>`）を確認する。秘密情報があれば拒否、それ以外は警告 |
| `pre-bash-shelve-reminder.js` | PreToolUse(Bash) | `p4 shelve` の直前に「CL 番号・説明文・対象ファイルをユーザーに提示して了承を得たか」を additionalContext で促す |
| `post-bash-shelved.js` | PostToolUse(Bash) | `p4 shelve` / `p4 change` の成功出力から CL 番号を拾い、`/review-cl <CL>` を新しいセッションで実行するよう案内する |

すべて Node.js 製（`${CLAUDE_PLUGIN_ROOT}` 経由で参照）。共通処理は `scripts/lib/` にあります。

## 同梱しているもの

- `skills/p4-workflow/SKILL.md`: 保留 CL の運用、説明文の形式、シェルブとレビューの流れ、P4V での手順
- `commands/p4-shelve.md`: 自然言語で対象を指定して CL 作成 → 確認 → シェルブ
- `commands/review-cl.md`: `p4-cl-cross-review` スキルを起動する入口
- `commands/p4-status.md`: 開いているファイルと保留 CL の一覧
- `agents/`: git-harness と同じレビューエージェント 8 体（`code-reviewer` / `impact-scope-reviewer` / `silent-failure-hunter` / `coding-standards-reviewer` / `comment-analyzer` / `performance-reviewer` / `simplicity-reviewer` / `pr-test-analyzer`）
- `scripts/p4-connect.sh` / `scripts/p4-describe.sh`: スキルから使う共通の接続・取得スクリプト

## 前提

- `P4_PROXY` 環境変数に到達可能な Perforce サーバー（`ssl:<host>:<port>`）を設定する。
  全 p4 コマンドは `p4 -p "$P4_PROXY"` で実行する。
- チケットが切れているときは `P4PASSWD` があれば自動ログイン、無ければユーザーにログインを依頼して止まる。
- フックは `p4` コマンドが PATH に無い環境では何もせず通過する。

## 有効化

`.claude/settings.local.json`:

```json
{
  "extraKnownMarketplaces": {
    "p4-harness": {
      "source": { "source": "directory", "path": "./.claude/vendor/p4-harness" }
    }
  },
  "enabledPlugins": {
    "p4-harness@p4-harness": true
  }
}
```

## 注意点

- hooks は複数ソースから **合算** されます。`settings.local.json` の `"hooks"` に同じ定義を書かないでください。
- プラグインの読み込みは Claude Code の起動時のみ。変更後は再起動が必要です。
- `scm-guard` と役割が重なる拒否（submit / revert）は意図的な二重化です。片方を外しても守られます。
