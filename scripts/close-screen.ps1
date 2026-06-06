# close-screen.ps1 - turn off display, keep system awake
$code = @"
using System;
using System.Runtime.InteropServices;
public class DisplayPower {
    [DllImport("user32.dll")]
    public static extern int PostMessage(int hWnd, int hMsg, int wParam, int lParam);
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
"@
Add-Type -TypeDefinition $code

[DisplayPower]::PostMessage(-1, 0x0112, 0xF170, 2)
[DisplayPower]::SetThreadExecutionState(0x80000001)
Write-Host "WECHAT_OK: screen off, bridge running"