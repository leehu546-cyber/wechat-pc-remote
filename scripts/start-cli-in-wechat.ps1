# 微信消息 → CLI 桥接（cli-in-wechat）
# 用法: .\start-cli-in-wechat.ps1 [-Debug]
$initScript = Join-Path $PSScriptRoot "init-cli-in-wechat-config.ps1"
if (Test-Path $initScript) {
    & $initScript | Out-Null
}

$root = Join-Path $PSScriptRoot "..\cli-in-wechat"
$entry = Join-Path $root "dist\index.js"
if (-not (Test-Path $entry)) {
    Write-Error "未找到 dist\index.js，请先在 cli-in-wechat 目录执行: npm install && npm run build"
    exit 1
}

Set-Location $root
Write-Host ""
Write-Host "  微信 ClawBot  ->  CLI 桥接" -ForegroundColor Cyan
Write-Host "  默认工具: codex | 工作目录: D:\cursor\61" -ForegroundColor DarkGray
Write-Host "  微信发 @claude / @codex 可切换 CLI" -ForegroundColor DarkGray
Write-Host "  首次运行请扫码；保持本窗口不要关闭" -ForegroundColor Yellow
Write-Host ""

$nodeArgs = @("dist/index.js")
if ($args -contains "-Debug" -or $args -contains "--debug") {
    $nodeArgs += "--debug"
}
node @nodeArgs
