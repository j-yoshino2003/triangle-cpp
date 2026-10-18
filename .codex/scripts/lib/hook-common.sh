#!/bin/bash
#---------------------------------------
# フック共通ライブラリ（source して使う）.
#
# Node.js を前提にできない CLI 向けに、フックのペイロード解析と応答の組み立てを grep / sed だけで行う.
# 置き場所で応答形式を切り替える:
#   .codex/  配下 → Codex 形式（hookSpecificOutput）、スラッシュコマンドは /prompts:<skill>
#   .agent/  配下 → Antigravity 形式（decision / reason）、スラッシュコマンドは /<skill>
#
# 提供する関数:
#   hook_read_input          標準入力を HOOK_INPUT に読み込む（空なら exit 0）
#   hook_tool_name           ツール名（取得できなければ空）
#   hook_is_exec_tool        実行系ツールなら 0 を返す（ツール名不明なら 0 = 安全側で判定を続ける）
#   hook_is_write_tool       書き込み系ツールなら 0 を返す（ツール名不明なら 0 = 安全側で判定を続ける）
#   hook_command             実行しようとしているコマンド文字列（文字列形式・argv 配列形式に対応）
#   hook_target_paths        編集対象のパスを 1 行 1 件で出力する（JSON キーと apply_patch 本文から）
#   hook_tool_output         PostToolUse のツール出力（取得できなければ空）
#   hook_strip_quotes STR    引用符で囲まれた部分を取り除く（オプション判定用）
#   hook_deny REASON         拒否応答を出力して exit 0
#   hook_context TEXT        モデルへの補足文脈を出力する（拒否しない）
#   hook_warn TEXT           stderr に警告を出す
#---------------------------------------

case "${BASH_SOURCE[0]}" in
  */.agent/*) HOOK_FLAVOR="antigravity"; HOOK_SLASH="/" ;;
  *)          HOOK_FLAVOR="codex";       HOOK_SLASH="/prompts:" ;;
esac

# 実行系とみなすツール名のパターン（大文字小文字は無視）.
HOOK_EXEC_TOOL_PATTERN='shell|bash|exec|command|terminal|process|run'

# 書き込み系とみなすツール名のパターン. 実行系より先に判定して対象外にする
# （hooks.json のような「禁止コマンドの文字列を含むファイル」の編集を誤ブロックしないため）.
HOOK_WRITE_TOOL_PATTERN='patch|write|edit|create|replace|notebook'

# コマンドが入り得る JSON キー.
HOOK_COMMAND_KEYS='command|cmd|commandLine|CommandLine|shell_command'

# 編集対象のパスが入り得る JSON キー（CLI ごとの呼び名の違いをまとめて吸収する）.
HOOK_PATH_KEYS='file_path|filePath|path|file|target_file|targetFile|TargetFile|notebook_path|abs_path|absPath|AbsolutePath'

# ツール出力が入り得る JSON キー.
HOOK_OUTPUT_KEYS='output|stdout|tool_output|result|content'

hook_read_input() {
  HOOK_INPUT=$(cat)
  [[ -z "$HOOK_INPUT" ]] && exit 0
  return 0
}

hook_tool_name() {
  printf '%s' "$HOOK_INPUT" \
    | grep -oE '"(tool_name|toolName|tool)"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -n 1 \
    | sed -E 's/.*"([^"]*)"$/\1/'
}

hook_is_exec_tool() {
  local tool
  tool=$(hook_tool_name)
  [[ -z "$tool" ]] && return 0
  printf '%s' "$tool" | grep -qiE "$HOOK_WRITE_TOOL_PATTERN" && return 1
  printf '%s' "$tool" | grep -qiE "$HOOK_EXEC_TOOL_PATTERN" && return 0
  return 1
}

hook_is_write_tool() {
  local tool
  tool=$(hook_tool_name)
  [[ -z "$tool" ]] && return 0
  printf '%s' "$tool" | grep -qiE "$HOOK_WRITE_TOOL_PATTERN" && return 0
  return 1
}

# JSON 文字列値のエスケープを戻す（\\ \" \/ \n \r \t）.
# 「\\」は placeholder に退避してから最後に戻す. 素直に順番へ置換すると、Windows パスの
# 「\\n」「\\t」を改行・タブに壊してしまうため（例: D:\\node_modules → D:\<改行>ode_modules）.
hook_unescape() {
  sed -E 's/\\\\/\x01/g; s/\\"/"/g; s/\\\//\//g; s/\\n/\n/g; s/\\r/\r/g; s/\\t/\t/g; s/\x01/\\/g'
}

hook_command() {
  local raw
  raw=$(printf '%s' "$HOOK_INPUT" \
    | grep -oE "\"($HOOK_COMMAND_KEYS)\"[[:space:]]*:[[:space:]]*(\[[^]]*\]|\"([^\"\\\\]|\\\\.)*\")" \
    | head -n 1)
  [[ -z "$raw" ]] && return 0
  printf '%s' "$raw" \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*//' \
    | sed -E 's/^\[[[:space:]]*//; s/[[:space:]]*\]$//' \
    | sed -E 's/"[[:space:]]*,[[:space:]]*"/ /g' \
    | sed -E 's/^"//; s/"$//' \
    | hook_unescape
}

hook_tool_output() {
  printf '%s' "$HOOK_INPUT" \
    | grep -oE "\"($HOOK_OUTPUT_KEYS)\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
    | head -n 1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//' \
    | hook_unescape
}

# 編集対象のパスを 1 行 1 件で出力する.
# JSON のキーと、apply_patch 形式のパッチ本文（*** Add / Update / Delete File:）の両方から集める.
# キーの値はエスケープを戻してから返す（Windows の絶対パスは「\」が「\\」で届くため、
# そのままだと呼び出し側の区切り正規化で「//」に化けて許可リストに一致しなくなる）.
hook_target_paths() {
  {
    printf '%s' "$HOOK_INPUT" \
      | grep -oE "\"($HOOK_PATH_KEYS)\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
      | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//' \
      | hook_unescape
    printf '%s' "$HOOK_INPUT" \
      | grep -oE '\*\*\* (Add|Update|Delete) File: [^"]*' \
      | sed -E 's/^\*\*\* (Add|Update|Delete) File: //' \
      | sed -E 's/\\+[nrt].*$//' \
      | sed -E 's/[[:space:]]+$//'
  } | sed '/^[[:space:]]*$/d'
}

# 引用符で囲まれた部分（コミットメッセージ等）を取り除く. オプションの判定を値に引きずられないため.
hook_strip_quotes() {
  printf '%s' "$1" | sed -E "s/\"([^\"\\\\]|\\\\.)*\"/\"\"/g; s/'[^']*'/''/g"
}

hook_json_escape() {
  printf '%s' "$1" | tr '\n\r\t' '   ' | sed -E 's|\\|\\\\|g; s|"|\\"|g'
}

hook_deny() {
  local reason
  reason=$(hook_json_escape "$1")
  if [[ "$HOOK_FLAVOR" == "antigravity" ]]; then
    printf '{"decision":"deny","reason":"%s"}\n' "$reason"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  fi
  exit 0
}

hook_context() {
  local text
  text=$(hook_json_escape "$1")
  if [[ "$HOOK_FLAVOR" == "antigravity" ]]; then
    # Antigravity には補足文脈を返す公式の形式が無いため、stderr に出す.
    printf '%s\n' "$1" >&2
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$text"
  fi
}

hook_warn() {
  printf '%s\n' "$1" >&2
}
