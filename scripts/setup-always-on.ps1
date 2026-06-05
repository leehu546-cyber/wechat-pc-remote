# Configure PC for 24/7 WeClaw + OpenCode bridge
# Run as Administrator for full effect (lid/network settings)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== WeClaw Bridge Always-On Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Power: never sleep on AC ---
Write-Host "[1/7] Power settings..." -ForegroundColor Yellow
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 30
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
powercfg /change standby-timeout-dc 60
powercfg /change monitor-timeout-dc 10
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
powercfg -SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg -SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
powercfg -SETACTIVE SCHEME_CURRENT
Write-Host "      AC: never sleep | Lid closed on AC: stay awake" -ForegroundColor Green

# --- 2. Network adapter: disable power saving ---
Write-Host "[2/7] Network adapter power saving..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | ForEach-Object {
        Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
    }
    Write-Host "      Network adapters: wake disabled power-off" -ForegroundColor Green
} else {
    Write-Host "      Skip (need Admin). Right-click -> Run as administrator" -ForegroundColor DarkYellow
}

# --- 3. Scheduled task: auto-start WeClaw on login ---
Write-Host "[3/7] Auto-start WeClaw on login..." -ForegroundColor Yellow
$taskName = "WeClawBridge"
$bgScript = Join-Path $PSScriptRoot "start-weclaw.ps1"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$bgScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "      Task: $taskName" -ForegroundColor Green

foreach ($legacy in @("WeChatLocalChatBridge", "WeChatOpenCodeServe")) {
    if (Get-ScheduledTask -TaskName $legacy -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $legacy -Confirm:$false
        Write-Host "      Removed legacy task: $legacy" -ForegroundColor DarkGray
    }
}

# --- 4. Ensure WeClaw + OpenCode config ---
Write-Host "[4/7] WeClaw + OpenCode config..." -ForegroundColor Yellow
$initScript = Join-Path $PSScriptRoot "init-weclaw-opencode.ps1"
if (Test-Path $initScript) { & $initScript }
$ocSetup = Join-Path $PSScriptRoot "setup-gemini-opencode.ps1"
if (-not (Test-Path (Join-Path $env:USERPROFILE ".config\opencode\opencode.json"))) {
    if (Test-Path $ocSetup) { & $ocSetup }
}

$stopLegacy = Join-Path $PSScriptRoot "stop-wechat-local-chat.ps1"
if (Test-Path $stopLegacy) { & $stopLegacy | Out-Null }

# --- 5. Start WeClaw now ---
Write-Host "[5/7] Starting WeClaw..." -ForegroundColor Yellow
& $bgScript
Start-Sleep -Seconds 3
& (Join-Path $PSScriptRoot "status.ps1")

# --- 6. Scheduled task: EverOS memory server on login ---
Write-Host "[6/7] EverOS memory server..." -ForegroundColor Yellow
$everosTask = "EverOSServer"
$everosScript = Join-Path $PSScriptRoot "start-everos.ps1"
if (Test-Path $everosScript) {
    $everosAction = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$everosScript`""
    $everosTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    Register-ScheduledTask -TaskName $everosTask -Action $everosAction -Trigger $everosTrigger -Settings $settings -Force | Out-Null
    & $everosScript
    Write-Host "      Task: $everosTask" -ForegroundColor Green
} else {
    Write-Host "      Skip (start-everos.ps1 not found)" -ForegroundColor DarkYellow
}

# --- 7. Scheduled task: ACP watchdog (every 5 min) ---
Write-Host "[7/7] ACP session watchdog..." -ForegroundColor Yellow
$watchdogTask = "WeClawWatchdog"
$watchdogScript = Join-Path $PSScriptRoot "weclaw-watchdog.ps1"
$watchdogAction = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogScript`""
$watchdogTrigger = New-ScheduledTaskTrigger -Daily -At "00:00" -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName $watchdogTask -Action $watchdogAction -Trigger $watchdogTrigger -Settings $settings -Force | Out-Null
Write-Host "      Task: $watchdogTask (every 5 min)" -ForegroundColor Green

Write-Host "Done. Tips:" -ForegroundColor Cyan
Write-Host "  - Keep PC plugged in for 24/7 use"
Write-Host "  - Log: $env:USERPROFILE\.weclaw\weclaw.log"
Write-Host "  - After weclaw/ code changes: cd weclaw && go build -o weclaw.exe ."
Write-Host "  - Remove task: Unregister-ScheduledTask -TaskName $taskName -Confirm:`$false"
Write-Host ""
