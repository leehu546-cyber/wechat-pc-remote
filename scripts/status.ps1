# Check WeClaw + OpenCode bridge status
Write-Host ""
Write-Host "=== WeClaw + OpenCode Status ===" -ForegroundColor Cyan

$weclaw = Join-Path $PSScriptRoot "..\weclaw\weclaw.exe"
$weclawProc = Get-Process -Name weclaw -ErrorAction SilentlyContinue
if ($weclawProc) {
    Write-Host "[ok] weclaw running pid=$($weclawProc.Id -join ',')" -ForegroundColor Green
} elseif (Test-Path $weclaw) {
    & $weclaw status 2>&1
} else {
    Write-Host "[--] weclaw.exe not found" -ForegroundColor Red
}

try {
    $ocVer = opencode --version 2>&1
    Write-Host "[ok] OpenCode $ocVer" -ForegroundColor Green
} catch {
    Write-Host "[--] OpenCode not installed" -ForegroundColor Red
}

$weclawConfig = Join-Path $env:USERPROFILE ".weclaw\config.json"
if (Test-Path $weclawConfig) {
    try {
        $wc = Get-Content $weclawConfig -Raw -Encoding UTF8 | ConvertFrom-Json
        $agent = $wc.default_agent
        $model = $wc.agents.opencode.model
        $cwd = $wc.agents.opencode.cwd
        Write-Host "[ok] default_agent: $agent | model: $model | cwd: $cwd" -ForegroundColor Green
    } catch {
        Write-Host "[..] weclaw config present but unreadable" -ForegroundColor Yellow
    }
} else {
    Write-Host "[..] weclaw not configured - run init-weclaw-opencode.ps1" -ForegroundColor Yellow
}

$accountsDir = Join-Path $env:USERPROFILE ".weclaw\accounts"
$ilinkCreds = Get-ChildItem -Path $accountsDir -Filter "*.json" -ErrorAction SilentlyContinue
if ($ilinkCreds) {
    Write-Host "[ok] WeChat logged in ($($ilinkCreds.Count) account(s))" -ForegroundColor Green
} else {
    $legacyCred = Join-Path $env:USERPROFILE ".wechat-local-chat\credentials.json"
    if (Test-Path $legacyCred) {
        Write-Host "[..] Legacy wechat-local-chat credentials exist; weclaw needs its own login" -ForegroundColor Yellow
    } else {
        Write-Host "[..] WeChat not logged in - run weclaw login or weclaw start" -ForegroundColor Yellow
    }
}

$weclawLog = Join-Path $env:USERPROFILE ".weclaw\weclaw.log"
if (Test-Path $weclawLog) {
    $logSize = (Get-Item $weclawLog).Length
    Write-Host "[ok] weclaw log: $weclawLog ($logSize bytes)" -ForegroundColor Green
}

# Legacy wechat-local-chat (optional)
$legacyPid = Join-Path $env:USERPROFILE ".wechat-local-chat\bridge.pid"
if (Test-Path $legacyPid) {
    $bpid = Get-Content $legacyPid -ErrorAction SilentlyContinue
    if ($bpid -and (Get-Process -Id $bpid -ErrorAction SilentlyContinue)) {
        Write-Host "[!!] Legacy wechat-local-chat still running pid=$bpid - run stop-wechat-local-chat.ps1" -ForegroundColor Red
    }
}

Write-Host ""
