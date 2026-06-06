# turn-off-screen.ps1 - turn display off (monitor power off)
# SendNotifyMessage (not SendMessage) — broadcast SendMessage can block on unresponsive windows.
param()

$ErrorActionPreference = "Continue"

$def = @'
[DllImport("user32.dll", EntryPoint = "SendNotifyMessageW")]
public static extern bool SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@

try {
    [Win32.Win32DisplayApi] | Out-Null
} catch {
    Add-Type -MemberDefinition $def -Name Win32DisplayApi -Namespace Win32 -ErrorAction Stop
}

# WM_SYSCOMMAND (0x0112) + SC_MONITORPOWER (0xF170), lParam=2 => monitor off
$off = [IntPtr]2
[void][Win32.Win32DisplayApi]::SendNotifyMessage([IntPtr]0xFFFF, 0x0112, [IntPtr]0xF170, $off)

Write-Host "WECHAT_OK: 已关闭显示器"
