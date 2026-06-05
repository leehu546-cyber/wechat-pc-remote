# Check WeChat local chat bridge status
Write-Host ""
Write-Host "=== WeChat Local Chat Status ===" -ForegroundColor Cyan

try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
    $models = ($tags.models | ForEach-Object { $_.name }) -join ", "
    Write-Host "[ok] Ollama running | models: $models" -ForegroundColor Green
} catch {
    Write-Host "[--] Ollama not running" -ForegroundColor Red
}

$cred = Join-Path $env:USERPROFILE ".wechat-local-chat\credentials.json"
if (Test-Path $cred) {
    Write-Host "[ok] WeChat logged in" -ForegroundColor Green
} else {
    Write-Host "[..] WeChat not logged in - scan QR" -ForegroundColor Yellow
    $loginHtml = Join-Path $env:USERPROFILE ".wechat-local-chat\login.html"
    if (Test-Path $loginHtml) {
        Write-Host "     QR page: $loginHtml" -ForegroundColor DarkGray
    }
}

$dist = Join-Path $PSScriptRoot "..\cli-in-wechat\dist\index.js"
if (Test-Path $dist) {
    Write-Host "[ok] cli-in-wechat built" -ForegroundColor Green
} else {
    Write-Host "[--] cli-in-wechat not built" -ForegroundColor Red
}

$configPath = Join-Path $PSScriptRoot "..\wechat-local-chat\config.json"
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $mode = if ($cfg.agentMode -ne $false) { "Agent (PowerShell)" } else { "Chat only" }
        Write-Host "[ok] bridge mode: $mode | workDir: $($cfg.workDir)" -ForegroundColor Green
    } catch { }
}

$pidFile = Join-Path $env:USERPROFILE ".wechat-local-chat\bridge.pid"
if (Test-Path $pidFile) {
    $bpid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($bpid -and (Get-Process -Id $bpid -ErrorAction SilentlyContinue)) {
        Write-Host "[ok] bridge process pid=$bpid" -ForegroundColor Green
    }
}

$cmdLog = Join-Path $env:USERPROFILE ".wechat-local-chat\logs\commands.log"
if (Test-Path $cmdLog) {
    $lines = (Get-Content $cmdLog -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    Write-Host "[ok] command audit log: $lines lines" -ForegroundColor Green
}

$nodes = Get-Process -Name node -ErrorAction SilentlyContinue
if (-not (Test-Path $pidFile) -and $nodes) {
    Write-Host "[ok] node process running ($($nodes.Count))" -ForegroundColor Green
} elseif (-not (Test-Path $pidFile)) {
    Write-Host "[..] bridge not running - run start-wechat-local-chat-background.ps1" -ForegroundColor Yellow
}

Write-Host ""
