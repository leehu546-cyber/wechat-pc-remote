# Singleton keep-awake: PowerRequestExecutionRequired + periodic SetThreadExecutionState (L1 iLink)
. (Join-Path $PSScriptRoot "keep-awake-util.ps1")
$keepAwake = Start-KeepAwakeDaemon -ScriptsRoot $PSScriptRoot
if ($keepAwake) {
    Write-Host "keep-awake daemon pid=$($keepAwake.Id)" -ForegroundColor Green
}

. (Join-Path $PSScriptRoot "wake-server-util.ps1")
$wakeServer = Start-WakeServerDaemon -ScriptsRoot $PSScriptRoot
if ($wakeServer) {
    $wakePort = (Read-WakeServerConfig).port
    Write-Host "wake-server pid=$($wakeServer.Id) port=$wakePort (mobile亮屏)" -ForegroundColor Green
}

# Start WeClaw WeChat bridge (default agent: OpenCode ACP)
$weclaw = Join-Path $PSScriptRoot "..\weclaw\weclaw.exe"
if (-not (Test-Path $weclaw)) {
    Write-Error "weclaw.exe not found. Build: cd weclaw && go build -o weclaw.exe ."
    exit 1
}

$initScript = Join-Path $PSScriptRoot "init-weclaw-opencode.ps1"
$configPath = Join-Path $env:USERPROFILE ".weclaw\config.json"
if (-not (Test-Path $configPath) -and (Test-Path $initScript)) {
    & $initScript
}

$stopLegacy = Join-Path $PSScriptRoot "stop-wechat-local-chat.ps1"
if (Test-Path $stopLegacy) { & $stopLegacy | Out-Null }

$everosScript = Join-Path $PSScriptRoot "start-everos.ps1"
if (Test-Path $everosScript) { & $everosScript }

# Hidden daemon watchdog (replaces WeClawWatchdog scheduled task that flashed a console every 5 min)
$watchdogTask = "WeClawWatchdog"
if (Get-ScheduledTask -TaskName $watchdogTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $watchdogTask -Confirm:$false
    Write-Host "Removed legacy $watchdogTask scheduled task (console flash)" -ForegroundColor DarkGray
}
if (-not (Test-WatchdogRunning)) {
    $wd = Start-WatchdogDaemon -ScriptsRoot $PSScriptRoot
    if ($wd) { Write-Host "watchdog daemon pid=$($wd.Id) (hidden)" -ForegroundColor Green }
}

Write-Host "Starting WeClaw (default: OpenCode)... Scan QR on first run." -ForegroundColor Cyan
& $weclaw start

