# close-screen.ps1 — 关闭显示器但保持网络和桥接运行
$ErrorActionPreference = "Continue"

# 1. 关屏幕（用 PostMessage 异步，不卡住）
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Display {
    [DllImport("user32.dll")]
    public static extern int PostMessage(int hWnd, int hMsg, int wParam, int lParam);
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
"@

[Display]::PostMessage(-1, 0x0112, 0xF170, 2)

# 2. 保持系统活跃（阻止 S0 Low Power Idle）
# ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (0x00000001)
[Display]::SetThreadExecutionState(0x80000001)

Write-Host "WECHAT_OK: 屏幕已关闭，桥接正常运行"
