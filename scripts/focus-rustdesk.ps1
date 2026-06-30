# focus-rustdesk.ps1 - focus RustDesk main window (ID display)
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class FocusRustDeskWin32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
'@

$found = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.ProcessName -match '^(?i)rustdesk$'
} | Select-Object -First 1

if (-not $found) {
    $starts = @(
        "$env:ProgramFiles\RustDesk\RustDesk.exe",
        "${env:ProgramFiles(x86)}\RustDesk\RustDesk.exe",
        "$env:LOCALAPPDATA\Programs\RustDesk\RustDesk.exe"
    )
    foreach ($exe in $starts) {
        if (Test-Path -LiteralPath $exe) {
            Start-Process -FilePath $exe
            Start-Sleep -Seconds 2
            break
        }
    }
    $found = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.ProcessName -match '^(?i)rustdesk$'
    } | Select-Object -First 1
}

if (-not $found) {
    Write-Host "WECHAT_FAIL: rustdesk_not_found"
    exit 1
}

[void][FocusRustDeskWin32]::ShowWindowAsync($found.MainWindowHandle, 9)
[void][FocusRustDeskWin32]::SetForegroundWindow($found.MainWindowHandle)
Start-Sleep -Milliseconds 300
Write-Host "WECHAT_OK: rustdesk focused"
Write-Host "WECHAT_USER_REPLY: 已打开 RustDesk，请看屏幕。"
