# Focus Cursor chat: 工作 > WeChat account transfer (unified WeChat control history)
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\cursor-wechat-agent.json"
$desktopInteract = Join-Path $PSScriptRoot "desktop-interact.ps1"

if (-not (Test-Path -LiteralPath $desktopInteract)) {
    Write-Host "WECHAT_FAIL: cursor_desktop_interact_missing"
    exit 1
}

$folderTarget = "wechat_agent_folder"
$chatTarget = "wechat_agent_chat"
if (Test-Path -LiteralPath $configPath) {
    $cfg = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($cfg.folder_target) { $folderTarget = [string]$cfg.folder_target }
    if ($cfg.chat_target) { $chatTarget = [string]$cfg.chat_target }
}

Write-Host "WECHAT_PROGRESS: open Cursor chat WeChat account transfer"
& $desktopInteract -App Cursor -Target $folderTarget -Text "" -ClickOnly
if ($LASTEXITCODE -ne 0) {
    Write-Host "WECHAT_FAIL: cursor_folder_focus_failed"
    exit 1
}
Start-Sleep -Milliseconds 350

& $desktopInteract -App Cursor -Target $chatTarget -Text "" -ClickOnly
if ($LASTEXITCODE -ne 0) {
    Write-Host "WECHAT_FAIL: cursor_chat_focus_failed"
    exit 1
}
Start-Sleep -Milliseconds 500

Write-Host "WECHAT_OK: cursor_wechat_chat_focused"
exit 0
