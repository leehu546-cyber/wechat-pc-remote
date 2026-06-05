# WeChat <-> Local Ollama chat bridge
$bridge = Join-Path $PSScriptRoot "..\wechat-local-chat\index.mjs"
$cliDist = Join-Path $PSScriptRoot "..\cli-in-wechat\dist\index.js"
$loginHtml = Join-Path $env:USERPROFILE ".wechat-local-chat\login.html"

if (-not (Test-Path $cliDist)) {
    Write-Error "Build cli-in-wechat first: cd D:\cursor\61\cli-in-wechat && npm install && npm run build"
    exit 1
}

try {
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
} catch {
    Write-Error "Ollama not running. Start: ollama serve"
    exit 1
}

Write-Host ""
Write-Host "  WeChat -> local qwen2.5:7b" -ForegroundColor Cyan
Write-Host "  First run: browser opens QR page for WeChat ClawBot" -ForegroundColor Yellow
Write-Host "  Keep this window open" -ForegroundColor DarkGray
Write-Host ""

$watcher = Start-Job -ScriptBlock {
    param($path)
    for ($i = 0; $i -lt 90; $i++) {
        if (Test-Path $path) {
            Start-Process $path
            return
        }
        Start-Sleep -Seconds 1
    }
} -ArgumentList $loginHtml

node $bridge

Stop-Job $watcher -ErrorAction SilentlyContinue
Remove-Job $watcher -Force -ErrorAction SilentlyContinue
