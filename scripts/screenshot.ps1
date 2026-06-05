# screenshot.ps1 - capture all screens and send via WeChat
param()

$ErrorActionPreference = "Continue"
$weclaw = "D:\cursor\61\weclaw\weclaw.exe"
$user = "o9cq801Ug93dPoIRZhHYx0dqwYuA@im.wechat"
$dir = Join-Path $env:USERPROFILE ".wechat-local-chat\screenshots"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# Kill leftover Python HTTP servers
Get-Process -Name python -ErrorAction SilentlyContinue | ForEach-Object {
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
    if ($cmd -and $cmd -match "http.server") { Stop-Process -Id $_.Id -Force }
}

# Capture all screens
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$bounds = [System.Drawing.Rectangle]::Empty
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    $bounds = [System.Drawing.Rectangle]::Union($bounds, $s.Bounds)
}
$bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$filePath = Join-Path $dir "ss_$ts.png"
$bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bitmap.Dispose()

# Find available port + start HTTP server
$port = 18090
while ($true) {
    $inUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if (-not $inUse) { break }
    $port++
}
$proc = Start-Process python -ArgumentList "-m http.server $port --directory `"$dir`"" -WindowStyle Hidden -PassThru
Start-Sleep 2

# Send via weclaw
$url = "http://127.0.0.1:$port/ss_$ts.png"
$result = & $weclaw send --to $user --text "[screenshot]" --media $url 2>&1
Write-Host $result

# Keep server alive for weclaw to download
Start-Sleep 8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

if ($result -match "Error|error|fail") {
    Write-Host "WECHAT_FAIL: send failed"
} else {
    Write-Host "WECHAT_OK: screenshot sent"
}