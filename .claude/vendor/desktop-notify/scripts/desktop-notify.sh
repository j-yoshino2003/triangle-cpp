#!/bin/bash
# Windows トースト通知を表示する.
# 引数: $1 = メッセージ本文, $2 = アイコン種別 (Info / Warning / Error, 省略時 Info)

MESSAGE="${1:-Claude Code}"
ICON="${2:-Info}"

powershell.exe -c "
Add-Type -AssemblyName System.Windows.Forms
\$n = [System.Windows.Forms.NotifyIcon]::new()
\$n.Icon = [System.Drawing.SystemIcons]::Information
\$n.Visible = \$true
\$n.ShowBalloonTip(4000, 'Claude Code', '$MESSAGE', [System.Windows.Forms.ToolTipIcon]::$ICON)
Start-Sleep 4
\$n.Dispose()
" 2>/dev/null

exit 0
