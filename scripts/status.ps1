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

$nodes = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodes) {
    $count = $nodes.Count
    Write-Host "[ok] node process running ($count)" -ForegroundColor Green
} else {
    Write-Host "[..] bridge not running - run start-wechat-local-chat.ps1" -ForegroundColor Yellow
}

Write-Host ""
