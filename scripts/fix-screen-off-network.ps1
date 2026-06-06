# Keep LAN alive when display is off (WeChat iLink + wake-mobile HTTP)
# Run as Administrator once.
param()

$ErrorActionPreference = "Continue"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host "[fail] Need Administrator. Right-click -> Run as administrator" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Fix network when display is off ===" -ForegroundColor Cyan

Write-Host "[1/5] Network adapter: disable power saving..." -ForegroundColor Yellow
Get-NetAdapter -Physical -ErrorAction SilentlyContinue | ForEach-Object {
    Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
    foreach ($kw in @('DeviceSleepOnDisconnect', '*DeviceSleepOnDisconnect', '*SSIdleTimeout', '*UltraLowPowerMode')) {
        Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword $kw -RegistryValue 0 -ErrorAction SilentlyContinue
    }
    Write-Host "      $($_.Name)" -ForegroundColor Green
}

Write-Host "[2/5] Disable Modern Standby (S0ix)..." -ForegroundColor Yellow
$aoac = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
if (-not (Test-Path $aoac)) { New-Item -Path $aoac -Force | Out-Null }
Set-ItemProperty -Path $aoac -Name 'PlatformAoAcOverride' -Value 0 -Type DWord -Force
Write-Host "      PlatformAoAcOverride=0" -ForegroundColor Green

Write-Host "[3/5] powercfg: block sleep on AC..." -ForegroundColor Yellow
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP AWAYMODE 0
powercfg -SETACTIVE SCHEME_CURRENT

Write-Host "[4/5] powercfg: keep node/weclaw system awake (display may be off)..." -ForegroundColor Yellow
$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($nodePath) {
    powercfg /requestsoverride process $nodePath system awaymode execution
    Write-Host "      node: $nodePath" -ForegroundColor Green
}
$weclaw = Join-Path $PSScriptRoot "..\weclaw\weclaw.exe"
if (Test-Path $weclaw) {
    powercfg /requestsoverride process $weclaw system awaymode execution
    Write-Host "      weclaw" -ForegroundColor Green
}

Write-Host "[5/5] Firewall: allow wake-mobile port..." -ForegroundColor Yellow
. (Join-Path $PSScriptRoot "wake-server-util.ps1")
$cfg = Read-WakeServerConfig
$port = $cfg.port
$ruleName = "WeClaw Wake Mobile $port"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Profile Private, Domain | Out-Null
}
Write-Host "      port $port allowed (Private, Domain)" -ForegroundColor Green

Write-Host ""
Write-Host "[ok] Done. Reboot once recommended (Modern Standby change)." -ForegroundColor Cyan
Write-Host "    Then: WeChat关屏 -> phone tap 亮屏 (same WiFi)" -ForegroundColor Cyan
Write-Host ""
