# WeClaw ACP session watchdog — auto-recover from stuck sessions after cancel_previous
# Run as daemon: .\weclaw-watchdog.ps1 -Daemon
# One-shot   : .\weclaw-watchdog.ps1
param(
    [int]$ErrorThreshold = 2,
    [int]$CheckIntervalSec = 60,
    [switch]$Daemon = $false
)

$ErrorActionPreference = "Continue"
$weclawBin = Join-Path $PSScriptRoot "..\weclaw\weclaw.exe"
$weclawLog = Join-Path $env:USERPROFILE ".weclaw\weclaw.log"
$restartScript = Join-Path $PSScriptRoot "start-weclaw.ps1"
$watchdogLog = Join-Path $env:USERPROFILE ".weclaw\watchdog.log"

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] $msg"
    Add-Content $watchdogLog $line
    Write-Host $line -ForegroundColor $(if ($msg -match 'restart|error|stuck') { 'Red' } else { 'Green' })
}

function Get-RecentErrors {
    if (-not (Test-Path $weclawLog)) { return @() }
    $lines = Get-Content $weclawLog -Tail 80
    $errorPatterns = @('context canceled', 'agent returned empty response')
    return $lines | Where-Object { $_ -match ($errorPatterns -join '|') }
}

function Get-ACPProcessId {
    Get-Process -Name node -ErrorAction SilentlyContinue | ForEach-Object {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmd -and $cmd -match 'opencode.*acp') { return $_.Id }
    }
    return $null
}

function Test-Healthy {
    $weclawOk = (Get-Process -Name weclaw -ErrorAction SilentlyContinue) -ne $null
    $acpPid = Get-ACPProcessId
    $errors = Get-RecentErrors

    Write-Log "check: weclaw=$weclawOk acp_pid=$acpPid errors=$($errors.Count)"

    if (-not $weclawOk) { return $false, 'weclaw not running' }
    if (-not $acpPid) {
        # If no ACP process but recent errors → session is stuck
        if ($errors.Count -ge $ErrorThreshold) { return $false, "ACP dead with $($errors.Count) errors" }
    }
    if ($errors.Count -ge 5) { return $false, "$($errors.Count) errors in last 80 lines" }

    return $true, 'ok'
}

function Restart-Bridge {
    Write-Log "restarting weclaw..."
    Get-Process -Name weclaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
    # Clean up any orphan ACP processes
    Get-Process -Name node -ErrorAction SilentlyContinue | ForEach-Object {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmd -and $cmd -match 'opencode.*acp') {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep 1
    & $restartScript
    Write-Log "weclaw restarted"
}

# --- Main ---
if ($Daemon) {
    Write-Log "daemon started (interval=${CheckIntervalSec}s)"
    while ($true) {
        $healthy, $reason = Test-Healthy
        if (-not $healthy) {
            Write-Log "unhealthy: $reason"
            Restart-Bridge
        }
        Start-Sleep -Seconds $CheckIntervalSec
    }
} else {
    $healthy, $reason = Test-Healthy
    if ($healthy) {
        Write-Host "WeClaw looks healthy." -ForegroundColor Green
    } else {
        Write-Host "Unhealthy: $reason" -ForegroundColor Yellow
        Restart-Bridge
    }
}
