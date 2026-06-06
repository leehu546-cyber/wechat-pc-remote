# Start hidden WeClaw watchdog daemon (replaces old 5-min scheduled task that flashed a console)
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "keep-awake-util.ps1")

$watchdogScript = Join-Path $PSScriptRoot "weclaw-watchdog.ps1"
if (-not (Test-Path $watchdogScript)) {
    Write-Error "weclaw-watchdog.ps1 not found: $watchdogScript"
    exit 1
}

$legacyTask = "WeClawWatchdog"
if (Get-ScheduledTask -TaskName $legacyTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $legacyTask -Confirm:$false
    Write-Host "[ok] Removed legacy scheduled task: $legacyTask" -ForegroundColor DarkGray
}

$proc = Start-WatchdogDaemon -ScriptsRoot $PSScriptRoot
if (-not $proc) {
    Write-Error "Failed to start watchdog daemon"
    exit 1
}
Write-Host "[ok] Watchdog daemon started hidden (pid=$($proc.Id))" -ForegroundColor Green
