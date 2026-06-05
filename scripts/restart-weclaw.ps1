# Recover from stuck WeClaw/OpenCode session (no WeChat reply after PC task done)
$ErrorActionPreference = "Continue"

$weclaw = Join-Path $PSScriptRoot "..\weclaw\weclaw.exe"
if (-not (Test-Path $weclaw)) {
    Write-Error "weclaw.exe not found"
    exit 1
}

Write-Host "=== WeClaw recovery ===" -ForegroundColor Cyan

Write-Host "[1/3] Stopping browser automation leftovers..." -ForegroundColor Yellow
foreach ($name in @("msedge", "msedgedriver", "python", "chromedriver", "geckodriver")) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Write-Host "[2/3] Restarting WeClaw..." -ForegroundColor Yellow
& $weclaw stop 2>&1 | Out-Null
Start-Sleep -Seconds 2
Get-Process -Name weclaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
& (Join-Path $PSScriptRoot "start-weclaw.ps1")

Write-Host "[3/3] Status..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
& (Join-Path $PSScriptRoot "status.ps1")

Write-Host ""
Write-Host "Tip: send /new in WeChat to clear the stuck OpenCode session." -ForegroundColor Cyan
