#!/usr/bin/env bash
#---------------------------------------
# 保留チェンジリストの取得（読み取り専用）.
#
# 使い方:
#   p4-describe.sh <CL>          メタデータ（describe -s）を出力する
#   p4-describe.sh <CL> --diff   シェルブ済み差分（describe -S -du5）を出力する
#
# クライアントワークスペースに依存しない describe だけを使うため、レビュー用マシンでも動く.
#
# 終了コード:
#   0 = 成功 / 2 = 引数不正 / 3,4 = 接続不可（p4-connect.sh と同じ）
#   5 = CL が存在しない / 6 = 既に submit 済み / 7 = シェルブされたファイルが無い
#---------------------------------------
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CL="${1:-}"
MODE="${2:-}"

if ! [[ "$CL" =~ ^[0-9]+$ ]]; then
  echo "使い方: p4-describe.sh <CL番号> [--diff]" >&2
  exit 2
fi

bash "$SCRIPT_DIR/p4-connect.sh" || exit $?

META=$(p4 -p "$P4_PROXY" describe -s "$CL" 2>&1)
if printf '%s' "$META" | grep -qiE 'no such changelist|Change [0-9]+ unknown'; then
  echo "チェンジリスト $CL は存在しません。" >&2
  exit 5
fi
if printf '%s' "$META" | grep -qE "^Change $CL by .* \*submitted\*|^Change $CL by [^*]*$" && ! printf '%s' "$META" | grep -q '\*pending\*'; then
  echo "チェンジリスト $CL は既に submit 済みです（保留 CL ではありません）。" >&2
  exit 6
fi

if [ "$MODE" != "--diff" ]; then
  printf '%s\n' "$META"
  exit 0
fi

DIFF=$(p4 -p "$P4_PROXY" describe -S -du5 "$CL" 2>&1)
if ! printf '%s' "$DIFF" | grep -q '^Shelved files:'; then
  cat >&2 <<EOF
チェンジリスト $CL にはシェルブされたファイルがありません。
P4V で対象チェンジリストを右クリック →「シェルブ」を実行してから、再度実行してください。
EOF
  exit 7
fi

printf '%s\n' "$DIFF"
exit 0
