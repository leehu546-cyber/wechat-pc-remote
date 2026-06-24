# screenshot.ps1 - wake display, capture all screens, send via WeChat
param(
    [switch]$SkipWake = $false
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "utf8-console.ps1")
$weclaw = "D:\cursor\61\weclaw\weclaw.exe"
$user = "o9cq801Ug93dPoIRZhHYx0dqwYuA@im.wechat"
$dir = Join-Path $env:TEMP "wechat_screenshots"
$wakeScript = Join-Path $PSScriptRoot "wake-screen.ps1"

if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

if (-not $SkipWake -and (Test-Path $wakeScript)) {
    & $wakeScript | Out-Null
    Start-Sleep -Milliseconds 500
}

Get-Process -Name python -ErrorAction SilentlyContinue | ForEach-Object {
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    if ($cmd -and $cmd -match "http\.server") { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}

function Test-BitmapMostlyBlack([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width
    $h = $bmp.Height
    if ($w -lt 8 -or $h -lt 8) { return $true }
    $sum = 0L
    $samples = 0
    $stepX = [Math]::Max(1, [int]($w / 16))
    $stepY = [Math]::Max(1, [int]($h / 16))
    for ($y = 0; $y -lt $h; $y += $stepY) {
        for ($x = 0; $x -lt $w; $x += $stepX) {
            $c = $bmp.GetPixel($x, $y)
            $sum += $c.R + $c.G + $c.B
            $samples++
        }
    }
    if ($samples -eq 0) { return $true }
    $avg = $sum / (3.0 * $samples)
    return $avg -lt 12
}

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$bounds = [System.Drawing.Rectangle]::Empty
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    $bounds = [System.Drawing.Rectangle]::Union($bounds, $s.Bounds)
}
$bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
$g.Dispose()

if (Test-BitmapMostlyBlack $bitmap) {
    $bitmap.Dispose()
    Write-Host "WECHAT_FAIL: 显示器关闭或锁屏，无法截图（请先发「亮屏」或保持屏幕常亮）"
    exit 1
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$filePath = Join-Path $dir "ss_$ts.png"
$bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

# Fast port pick — avoid slow Get-NetTCPConnection scan
$port = 18090 + ($PID % 30)
$proc = Start-Process python -ArgumentList "-m http.server $port --directory `"$dir`"" -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 800

$url = "http://127.0.0.1:$port/ss_$ts.png"
$result = & $weclaw send --to $user --text "[screenshot]" --media $url 2>&1
Write-Host $result

Start-Sleep -Seconds 2
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

if ($result -match "Error|error|fail") {
    Write-Host "WECHAT_FAIL: 截图发送失败"
    Write-Host "WECHAT_USER_REPLY: 没做成：截图发送失败。"
    exit 1
}
Write-Host "WECHAT_OK: 截图已发送"
Write-Host "WECHAT_MEDIA_SENT: screenshot"
