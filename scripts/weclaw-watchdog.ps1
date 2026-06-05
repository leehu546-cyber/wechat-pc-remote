# WeClaw ACP session watchdog — recover from stuck sessions (backup to session/cancel patch)
# Run as daemon: .\weclaw-watchdog.ps1 -Daemon
# One-shot   : .\weclaw-watchdog.ps1
param(
    [int]$ErrorThreshold = 2,
    [int]$ErrorWindowMinutes = 10,
    [int]$NoReplyMinutes = 5,
    [int]$CheckIntervalSec = 60,
    [switch]$Daemon = $false
)

$ErrorActionPreference = "Continue"
$weclawLog = Join-Path $env:USERPROFILE ".weclaw\weclaw.log"
$restartScript = Join-Path $PSScriptRoot "restart-weclaw.ps1"
$watchdogLog = Join-Path $env:USERPROFILE ".weclaw\watchdog.log"

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [watchdog] $msg"
    Add-Content $watchdogLog $line
    Write-Host $line -ForegroundColor $(if ($msg -match 'restart|error|stuck|unhealthy') { 'Red' } else { 'Green' })
}

function Parse-LogTimestamp($line) {
    if ($line -match '^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})') {
        try { return [datetime]::ParseExact($matches[1], 'yyyy/MM/dd HH:mm:ss', $null) } catch { }
    }
    return $null
}

function Get-RecentLogLines {
    param([int]$Tail = 300)
    if (-not (Test-Path $weclawLog)) { return @() }
    return @(Get-Content $weclawLog -Tail $Tail -ErrorAction SilentlyContinue)
}

function Get-ACPProcessIdFromLog {
    $lines = Get-RecentLogLines
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '\[acp\] started subprocess.*pid=(\d+)') {
            return [int]$matches[1]
        }
    }
    return $null
}

function Test-ProcessAlive($pid) {
    if (-not $pid) { return $false }
    return $null -ne (Get-Process -Id $pid -ErrorAction SilentlyContinue)
}

function Get-RecentErrors {
    param([int]$WindowMinutes = $ErrorWindowMinutes)
    $cutoff = (Get-Date).AddMinutes(-$WindowMinutes)
    $patterns = @('context canceled', 'agent returned empty response', 'default task canceled before reply')
    $errors = @()
    foreach ($line in (Get-RecentLogLines)) {
        $ts = Parse-LogTimestamp $line
        if ($ts -and $ts -lt $cutoff) { continue }
        if ($line -match ($patterns -join '|')) { $errors += $line }
    }
    return $errors
}

function Test-NoReplyStuck {
    param([int]$StuckMinutes = $NoReplyMinutes)
    $lines = Get-RecentLogLines
    $lastReceived = $null
    $lastReceivedIdx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '\[handler\] received from') {
            $lastReceived = Parse-LogTimestamp $lines[$i]
            $lastReceivedIdx = $i
            break
        }
    }
    if (-not $lastReceived) { return $false, '' }

    $age = ((Get-Date) - $lastReceived).TotalMinutes
    if ($age -lt $StuckMinutes) { return $false, '' }

    for ($j = $lastReceivedIdx; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '\[sender\] sent reply to') { return $false, '' }
        if ($lines[$j] -match 'Available agents:') { return $false, '' }
    }
    return $true, "no reply for $([math]::Round($age, 1)) min since last received message"
}

function Test-Healthy {
    $weclawOk = $null -ne (Get-Process -Name weclaw -ErrorAction SilentlyContinue)
    $acpPid = Get-ACPProcessIdFromLog
    $acpAlive = Test-ProcessAlive $acpPid
    $errors = Get-RecentErrors
    $stuck, $stuckReason = Test-NoReplyStuck

    Write-Log "check: weclaw=$weclawOk acp_log_pid=$acpPid acp_alive=$acpAlive recent_errors=$($errors.Count) stuck=$stuck"

    if (-not $weclawOk) { return $false, 'weclaw not running' }
    if ($stuck) { return $false, $stuckReason }
    if ($errors.Count -ge $ErrorThreshold) {
        return $false, "$($errors.Count) errors in last ${ErrorWindowMinutes}m"
    }
    if ($acpPid -and -not $acpAlive -and $errors.Count -ge 1) {
        return $false, "ACP pid $acpPid from log is not running"
    }

    return $true, 'ok'
}

function Restart-Bridge {
    Write-Log "restarting via restart-weclaw.ps1..."
    if (Test-Path $restartScript) {
        & $restartScript
    } else {
        Get-Process -Name weclaw -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        & (Join-Path $PSScriptRoot "start-weclaw.ps1")
    }
    Write-Log "weclaw restarted"
}

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
