# turn-off-screen.ps1 - turn display off (monitor power off)
# SendNotifyMessage (not SendMessage) — broadcast SendMessage can block on unresponsive windows.
#
# One-shot SetThreadExecutionState below helps L3 (Agent bash during this prompt turn only).
# Persistent L1 (iLink GetUpdates while display is off) is owned by keep-awake.ps1 — not this script.
param()

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$def = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
[DllImport("user32.dll", EntryPoint = "SendNotifyMessageW")]
public static extern bool SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@

try {
    [Win32.Win32DisplayApi] | Out-Null
} catch {
    Add-Type -MemberDefinition $def -Name Win32DisplayApi -Namespace Win32 -ErrorAction Stop
}

# Transient pin for the current turn; exits when this process ends. See keep-awake.ps1 for L1.
[void][Win32.Win32DisplayApi]::SetThreadExecutionState([uint32]2147483651)

# WM_SYSCOMMAND (0x0112) + SC_MONITORPOWER (0xF170), lParam=2 => monitor off
$off = [IntPtr]2
[void][Win32.Win32DisplayApi]::SendNotifyMessage([IntPtr]0xFFFF, 0x0112, [IntPtr]0xF170, $off)

Write-Host "WECHAT_OK: 已关闭显示器"
Write-Host "WECHAT_USER_REPLY: 显示器已关闭。"
