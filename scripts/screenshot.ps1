# screenshot.ps1 — 截屏并通过微信发送
param()

$ErrorActionPreference = "Continue"
$weclaw = "D:\cursor\61\weclaw\weclaw.exe"
$user = "o9cq801Ug93dPoIRZhHYx0dqwYuA@im.wechat"
$dir = Join-Path $env:USERPROFILE ".wechat-local-chat\screenshots"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# 1. 截屏
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$filePath = Join-Path $dir "ss_$ts.png"
$bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bitmap.Dispose()
Write-Host "[screenshot] saved: $filePath"

# 2. 找可用端口 + 启动 HTTP 服务器
$port = 18090
while ($true) {
    $inUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if (-not $inUse) { break }
    $port++
}
$p = Start-Process python -ArgumentList "-m http.server $port --directory `"$dir`"" -WindowStyle Hidden -PassThru
Start-Sleep 2

# 3. 发图
$url = "http://127.0.0.1:$port/ss_$ts.png"
Write-Host "[screenshot] sending to WeChat..."
$sendResult = & $weclaw send --to $user --text "📷 截图" --media $url 2>&1
Write-Host $sendResult

# 4. 等 weclaw 下载完图片再关服务器
Start-Sleep 8
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue

if ($sendResult -match "Error|error|fail") {
    Write-Host "WECHAT_FAIL: 截图发送失败，稍后再试"
} else {
    Write-Host "WECHAT_OK: 截图已发送"
}
