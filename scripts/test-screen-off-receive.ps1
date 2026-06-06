# Diagnose: after WeChat "关屏", can iLink still receive messages without waking display?
param(
    [int]$WatchSec = 45
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "keep-awake-util.ps1")

$log = Join-Path $env:USERPROFILE ".weclaw\weclaw.log"

Write-Host ""
Write-Host "=== Screen-off receive test (L1 iLink) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Steps:" -ForegroundColor Yellow
Write-Host "  1. WeChat: send 关闭屏幕 (brain runs turn-off-screen.ps1)"
Write-Host "  2. While display is OFF, send 1 to File Helper — do NOT wake display"
Write-Host "  3. This script watches weclaw.log for $WatchSec seconds"
Write-Host ""

$pids = Get-KeepAwakeDaemonPids
if ($pids.Count -eq 1) {
    Write-Host "[ok] keep-awake singleton pid=$($pids[0])" -ForegroundColor Green
} elseif ($pids.Count -gt 1) {
    Write-Host "[warn] multiple keep-awake: $($pids -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "[fail] keep-awake not running — run restart-weclaw.ps1" -ForegroundColor Red
}

if (-not (Test-Path $log)) {
    Write-Host "[fail] log missing: $log" -ForegroundColor Red
    exit 1
}

$startLen = (Get-Item $log).Length
$deadline = (Get-Date).AddSeconds($WatchSec)
$gotReceive = $false
$gotGetUpdatesErr = $false

Write-Host "Watching $log ..." -ForegroundColor DarkGray

while ((Get-Date) -lt $deadline) {
    $content = Get-Content $log -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content.Length -gt $startLen) {
        $newPart = $content.Substring($startLen)
        if ($newPart -match '\[handler\] received from') {
            $gotReceive = $true
            $line = ($newPart -split "`n" | Where-Object { $_ -match '\[handler\] received from' } | Select-Object -Last 1)
            Write-Host "[ok] received: $line" -ForegroundColor Green
            break
        }
        if ($newPart -match '\[monitor\] GetUpdates error') {
            $gotGetUpdatesErr = $true
            $line = ($newPart -split "`n" | Where-Object { $_ -match 'GetUpdates error' } | Select-Object -Last 1)
            Write-Host "[warn] $line" -ForegroundColor Yellow
        }
    }
    Start-Sleep -Milliseconds 500
}

Write-Host ""
if ($gotReceive) {
    Write-Host "PASS: message received while display off (L1 OK)" -ForegroundColor Green
    exit 0
}

Write-Host "FAIL: no [handler] received in ${WatchSec}s while display off" -ForegroundColor Red
Write-Host "Checks:" -ForegroundColor Yellow
Write-Host "  - restart-weclaw.ps1 (keep-awake dual pin)"
Write-Host "  - Admin: setup-always-on.ps1 (disable NIC power save)"
Write-Host "  - docs/weclaw-vpn.md (iLink DIRECT / route-exclude)"
if ($gotGetUpdatesErr) {
    Write-Host "  - log had GetUpdates errors (L1 transport)" -ForegroundColor Yellow
}
exit 1
