$ErrorActionPreference = "Continue"
$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
$cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pwd = [string]$cfg.password

Add-Type -AssemblyName System.Windows.Forms

# 先唤醒
Add-Type @"
[DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
[DllImport("user32.dll", EntryPoint = "SendNotifyMessageW")]
public static extern bool SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
[DllImport("user32.dll")]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
"@ -Name Wake -Namespace Win32

[Win32.Wake]::SetThreadExecutionState(2147483651) | Out-Null
[Win32.Wake]::SendNotifyMessage([IntPtr]0xFFFF, 0x0112, [IntPtr]0xF170, [IntPtr](-1)) | Out-Null
[Win32.Wake]::mouse_event(0x0001, 1, 0, 0, [UIntPtr]::Zero) | Out-Null

Start-Sleep -Seconds 2

# 在当前会话直接发送按键
Write-Host "Sending Space..."
[System.Windows.Forms.SendKeys]::SendWait(' ')
Start-Sleep -Milliseconds 1500

Write-Host "Sending password..."
foreach ($ch in $pwd.ToCharArray()) {
    [System.Windows.Forms.SendKeys]::SendWait($ch.ToString())
    Start-Sleep -Milliseconds 80
}
Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')

Write-Host "DONE"
