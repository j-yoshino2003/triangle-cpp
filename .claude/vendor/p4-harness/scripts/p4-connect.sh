#!/usr/bin/env bash
#---------------------------------------
# 共通: Perforce への接続確認.
#
# P4_PROXY（ssl:<host>:<port>）が設定されていることと、チケットが有効なことを確認する.
# チケットが無効で P4PASSWD があればログインを試みる. 無ければユーザーにログインを依頼して止まる.
# 成功時は何も出力せず 0 を返す. 失敗時は日本語の理由を stderr に出す.
#
# 終了コード: 0 = 接続可 / 3 = P4_PROXY 未設定 / 4 = チケット無効（ログイン不可）
#---------------------------------------
set -u

if [ -z "${P4_PROXY:-}" ]; then
  echo "P4_PROXY が未設定です。到達可能な Perforce サーバー（例: ssl:<host>:<port>）を環境変数 P4_PROXY に設定してください。" >&2
  exit 3
fi

if p4 -p "$P4_PROXY" login -s >/dev/null 2>&1; then
  exit 0
fi

if [ -n "${P4PASSWD:-}" ]; then
  if printf '%s\n' "$P4PASSWD" | p4 -p "$P4_PROXY" login >/dev/null 2>&1; then
    exit 0
  fi
  echo "P4PASSWD でのログインに失敗しました。パスワードとサーバー（P4_PROXY）を確認してください。" >&2
  exit 4
fi

echo "Perforce のチケットが無効です。P4V でログインするか、環境変数 P4PASSWD を設定してから再実行してください。" >&2
exit 4
