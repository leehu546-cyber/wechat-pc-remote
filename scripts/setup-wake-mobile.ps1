# One-time setup: firewall + HTTP URL reservation + wake-server daemon
# Run as Administrator for firewall/urlacl. Without admin, still creates config and starts server on loopback test.
param(
    [switch]$SkipFirewall
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "wake-server-util.ps1")

$cfg = Ensure-WakeServerConfig
$port = $cfg.port
$ruleName = "WeClaw Wake Mobile $port"
$urlAcl = "http://+:${port}/"

Write-Host ""
Write-Host "=== Wake Mobile Setup (port $port) ===" -ForegroundColor Cyan

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

$fixNet = Join-Path $PSScriptRoot "fix-screen-off-network.ps1"
if ($isAdmin -and (Test-Path $fixNet)) {
    & $fixNet
}

if ($isAdmin -and -not $SkipFirewall) {
    $aclUrls = @($urlAcl)
    foreach ($ip in (Get-LanIPv4Addresses)) {
        $aclUrls += "http://${ip}:${port}/"
    }
    foreach ($acl in ($aclUrls | Select-Object -Unique)) {
        $existingAcl = netsh http show urlacl 2>$null | Select-String -SimpleMatch $acl
        if (-not $existingAcl) {
            netsh http add urlacl url=$acl user=Everyone | Out-Null
            Write-Host "[ok] URL reservation: $acl" -ForegroundColor Green
        }
    }

    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Profile Private, Domain | Out-Null
        Write-Host "[ok] Firewall rule: $ruleName (Private, Domain)" -ForegroundColor Green
    } else {
        Write-Host "[ok] Firewall rule already exists" -ForegroundColor Green
    }
} else {
    Write-Host "[!!] Not admin — phone LAN access needs one-time admin setup." -ForegroundColor Yellow
    Write-Host "     Right-click: scripts\install-wake-mobile-admin.bat -> Run as administrator" -ForegroundColor Yellow
}

$proc = Start-WakeServerDaemon -ScriptsRoot $PSScriptRoot
if ($proc) {
    Write-Host "[ok] wake-server pid=$($proc.Id)" -ForegroundColor Green
} else {
    Write-Host "[fail] could not start wake-server" -ForegroundColor Red
}

Start-Sleep -Seconds 1
try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:${port}/api/health" -TimeoutSec 5
    if ($health.ok) {
        Write-Host "[ok] local health check passed" -ForegroundColor Green
    }
} catch {
    Write-Host "[warn] health check failed: $_" -ForegroundColor Yellow
    Write-Host "       If access denied, run this script as Administrator once." -ForegroundColor Yellow
}

if (-not (Test-WakeServerLanReady)) {
    Write-Host ""
    Write-Host "[!!] Server bound to localhost only — phone cannot connect yet." -ForegroundColor Red
    Write-Host "     Run install-wake-mobile-admin.bat as Administrator, then re-run this script." -ForegroundColor Yellow
}

$urls = @(Get-WakeMobileUrls -Config $cfg)
Write-Host ""
Write-Host "=== Phone URLs (same WiFi) ===" -ForegroundColor Cyan
foreach ($u in $urls) {
    Write-Host $u -ForegroundColor White
    $qr = "https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=$([uri]::EscapeDataString($u))"
    Write-Host "  QR: $qr" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Token: $($cfg.token)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  1. Phone scan QR or open URL in Safari/Chrome"
Write-Host "  2. Add to Home Screen -> one-tap wake app"
Write-Host "  3. restart-weclaw.ps1 auto-starts wake-server with bridge"
Write-Host ""
