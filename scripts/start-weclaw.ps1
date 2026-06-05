# Start WeClaw WeChat bridge (default agent: OpenCode ACP)
$weclaw = Join-Path $PSScriptRoot "..\weclaw\weclaw.exe"
if (-not (Test-Path $weclaw)) {
    Write-Error "weclaw.exe not found. Build: cd weclaw && go build -o weclaw.exe ."
    exit 1
}

$initScript = Join-Path $PSScriptRoot "init-weclaw-opencode.ps1"
$configPath = Join-Path $env:USERPROFILE ".weclaw\config.json"
if (-not (Test-Path $configPath) -and (Test-Path $initScript)) {
    & $initScript
}

$stopLegacy = Join-Path $PSScriptRoot "stop-wechat-local-chat.ps1"
if (Test-Path $stopLegacy) { & $stopLegacy | Out-Null }

Write-Host "Starting WeClaw (default: OpenCode)... Scan QR on first run." -ForegroundColor Cyan
& $weclaw start
