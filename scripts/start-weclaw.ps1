# 启动 weclaw 微信 ClawBot 桥接（首次运行需微信扫码）
$weclaw = Join-Path $PSScriptRoot "..\weclaw\weclaw.exe"
if (-not (Test-Path $weclaw)) {
    Write-Error "未找到 weclaw.exe，请先在 weclaw 目录执行: go build -o weclaw.exe ."
    exit 1
}
Write-Host "启动 weclaw... 首次运行请用微信 ClawBot 扫码登录" -ForegroundColor Cyan
& $weclaw start
