# Register WeClawWatchdog scheduled task (every 5 min, one-shot check per run)
$ErrorActionPreference = "Stop"

$watchdogScript = Join-Path $PSScriptRoot "weclaw-watchdog.ps1"
if (-not (Test-Path $watchdogScript)) {
    Write-Error "weclaw-watchdog.ps1 not found: $watchdogScript"
    exit 1
}

$taskName = "WeClawWatchdog"
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogScript`""

# -Once + Repetition works on Windows PowerShell 5.1; MaxValue is rejected by Task Scheduler XML.
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "[ok] Registered scheduled task: $taskName (every 5 min)" -ForegroundColor Green

$info = Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskInfo
Write-Host "     State: $($info.LastTaskResult) | Next run: $($info.NextRunTime)" -ForegroundColor DarkGray
