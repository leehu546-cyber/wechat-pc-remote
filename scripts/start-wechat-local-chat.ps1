# 微信 <-> 本地 Ollama 纯对话（qwen2.5:7b）
$bridge = Join-Path $PSScriptRoot "..\wechat-local-chat\index.mjs"
$cliDist = Join-Path $PSScriptRoot "..\cli-in-wechat\dist\index.js"

if (-not (Test-Path $cliDist)) {
    Write-Error "请先构建 cli-in-wechat: cd D:\cursor\61\cli-in-wechat && npm install && npm run build"
    exit 1
}

# 检查 Ollama
try {
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
} catch {
    Write-Error "Ollama 未运行。请先执行: ollama serve"
    exit 1
}

Write-Host ""
Write-Host "  微信发消息 -> 本地 qwen2.5:7b 回复" -ForegroundColor Cyan
Write-Host "  首次运行需微信 ClawBot 扫码" -ForegroundColor Yellow
Write-Host "  保持本窗口打开" -ForegroundColor DarkGray
Write-Host ""

node $bridge
