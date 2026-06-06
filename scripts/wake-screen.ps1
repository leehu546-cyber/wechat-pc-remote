# wake-screen.ps1 - turn display on (monitor was off / screen saver)
param()

$ErrorActionPreference = "Stop"
$pyScript = Join-Path $PSScriptRoot "wake-display.py"

if (Test-Path $pyScript) {
    python $pyScript
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    exit 0
}

$def = @'
[DllImport("user32.dll", EntryPoint = "SendMessageW")]
public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
[DllImport("user32.dll")]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
'@

try {
    [Win32.Win32WakeApi] | Out-Null
} catch {
    Add-Type -MemberDefinition $def -Name Win32WakeApi -Namespace Win32 -ErrorAction Stop
}

$on = [IntPtr](-1)
[void][Win32.Win32WakeApi]::SendMessage([IntPtr]0xFFFF, 0x0112, [IntPtr]0xF170, $on)
[Win32.Win32WakeApi]::mouse_event(0x0001, 1, 0, 0, [UIntPtr]::Zero)

Write-Host "WECHAT_OK: 已唤醒显示器"
