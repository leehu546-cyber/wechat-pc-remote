# wake-screen.ps1 - turn display on (monitor off / screensaver)
# SendNotifyMessage (not SendMessage) — broadcast SendMessage can block on unresponsive windows.
param()

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$def = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
[DllImport("user32.dll", EntryPoint = "SendNotifyMessageW")]
public static extern bool SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
[DllImport("user32.dll")]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
'@

try {
    [Win32.Win32WakeApi] | Out-Null
} catch {
    Add-Type -MemberDefinition $def -Name Win32WakeApi -Namespace Win32 -ErrorAction Stop
}

# ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED
# ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED (must be uint32, not signed hex)
[void][Win32.Win32WakeApi]::SetThreadExecutionState([uint32]2147483651)

$on = [IntPtr](-1)
[void][Win32.Win32WakeApi]::SendNotifyMessage([IntPtr]0xFFFF, 0x0112, [IntPtr]0xF170, $on)
[Win32.Win32WakeApi]::mouse_event(0x0001, 1, 0, 0, [UIntPtr]::Zero)

Write-Host "WECHAT_OK: 已唤醒显示器"
Write-Host "WECHAT_USER_REPLY: 屏幕已点亮。"
