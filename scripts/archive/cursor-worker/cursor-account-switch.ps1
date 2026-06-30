# cursor-account-switch.ps1 - Run D:\AI助手.bat then wait before Cursor resubmit
param(
    [int]$PostSwitchWaitSec = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\cursor-wechat-agent.json"
$aiBat = "D:\AI助手.bat"
if (Test-Path -LiteralPath $configPath) {
    $cfg = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cfg.account_switch_bat) { $aiBat = [string]$cfg.account_switch_bat }
    if ($null -ne $cfg.post_switch_wait_sec) { $PostSwitchWaitSec = [int]$cfg.post_switch_wait_sec }
}

$projectRoot = Split-Path $PSScriptRoot -Parent
$cursorExe = Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe"
$workspace = $projectRoot

if (-not (Test-Path -LiteralPath $aiBat)) {
    Write-Host "WECHAT_FAIL: ai_assistant_bat_missing"
    exit 1
}

Write-Host "WECHAT_PROGRESS: running AI assistant switch ($aiBat)"
$proc = Start-Process -FilePath $aiBat -WorkingDirectory (Split-Path $aiBat -Parent) -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) {
    Write-Host "WECHAT_FAIL: ai_assistant_switch_failed"
    exit 1
}

Write-Host "WECHAT_PROGRESS: switch script done, waiting ${PostSwitchWaitSec}s before Cursor"
Start-Sleep -Seconds $PostSwitchWaitSec

$cursorProc = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if (-not $cursorProc) {
    if (-not (Test-Path -LiteralPath $cursorExe)) {
        Write-Host "WECHAT_FAIL: cursor_exe_not_found"
        exit 1
    }
    Write-Host "WECHAT_PROGRESS: restarting Cursor"
    Start-Process -FilePath $cursorExe -ArgumentList "`"$workspace`""
    Start-Sleep -Seconds 8
}

$focusChat = Join-Path $PSScriptRoot "cursor-focus-wechat-chat.ps1"
if (Test-Path -LiteralPath $focusChat) {
    & $focusChat 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WECHAT_FAIL: cursor_chat_focus_failed"
        exit 1
    }
}

Write-Host "WECHAT_OK: cursor_account_switched"
exit 0
