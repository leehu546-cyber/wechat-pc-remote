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
$everosScript = Join-Path $PSScriptRoot "start-everos.ps1"
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

function Test-ProcessAlive($processId) {
    if (-not $processId) { return $false }
    return $null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)
}

function Get-RecentErrors {
    param([int]$WindowMinutes = $ErrorWindowMinutes)
    $cutoff = (Get-Date).AddMinutes(-$WindowMinutes)
    $patterns = @(
        'context canceled',
        'agent returned empty response',
        'default task canceled before reply',
        'turn timed out',
        '本轮处理超时',
        'read loop ended',
        'connection refused.*8080',
        'everos.*search failed',
        '\[monitor\] GetUpdates error'
    )
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
        if ($lines[$j] -match '\[sender\] sent reply to') {
            if ($lines[$j] -notmatch '处理中：') { return $false, '' }
            continue
        }
        if ($lines[$j] -match '\[handler\] agent replied') { return $false, '' }
        if ($lines[$j] -match 'Available agents:') { return $false, '' }
    }
    return $true, "no reply for $([math]::Round($age, 1)) min since last received message"
}

function Test-GetUpdatesErrors {
    param([int]$WindowMinutes = 10, [int]$MinCount = 3)
    $cutoff = (Get-Date).AddMinutes(-$WindowMinutes)
    $count = 0
    foreach ($line in (Get-RecentLogLines -Tail 500)) {
        $ts = Parse-LogTimestamp $line
        if ($ts -and $ts -lt $cutoff) { continue }
        if ($line -match '\[monitor\] GetUpdates error') { $count++ }
    }
    if ($count -ge $MinCount) {
        return $true, "GetUpdates errors=$count in last ${WindowMinutes}m"
    }
    return $false, ''
}

function Test-ToolHangStuck {
    param([int]$HangMinutes = 3)
    $lines = Get-RecentLogLines -Tail 500
    $lastTool = $null
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '\[acp\] session/update.*type=tool_call') {
            $lastTool = Parse-LogTimestamp $lines[$i]
            break
        }
    }
    if (-not $lastTool) { return $false, '' }
    $age = ((Get-Date) - $lastTool).TotalMinutes
    if ($age -lt $HangMinutes) { return $false, '' }
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $ts = Parse-LogTimestamp $lines[$i]
        if ($ts -and $ts -lt $lastTool) { break }
        if ($lines[$i] -match '\[acp\] prompt result') { return $false, '' }
        if ($lines[$i] -match '\[handler\] agent replied') { return $false, '' }
    }
    return $true, "tool hang ${HangMinutes}m+ without prompt result"
}

function Test-EverOSHealthy {
    try {
        $r = Invoke-RestMethod "http://127.0.0.1:8080/health" -TimeoutSec 3
        return ($r.status -eq 'ok')
    } catch {
        return $false
    }
}

function Start-EverOSIfNeeded {
    if (Test-EverOSHealthy) { return $true }
    Write-Log "EverOS unhealthy, starting via start-everos.ps1..."
    if (Test-Path $everosScript) {
        & $everosScript | Out-Null
        Start-Sleep -Seconds 3
    }
    return (Test-EverOSHealthy)
}

function Test-Healthy {
    $weclawOk = $null -ne (Get-Process -Name weclaw -ErrorAction SilentlyContinue)
    $everosOk = Test-EverOSHealthy
    $acpPid = Get-ACPProcessIdFromLog
    $acpAlive = Test-ProcessAlive $acpPid
    $errors = Get-RecentErrors
    $stuck, $stuckReason = Test-NoReplyStuck
    $getUpdatesStuck, $getUpdatesReason = Test-GetUpdatesErrors
    $toolHang, $toolHangReason = Test-ToolHangStuck

    Write-Log "check: weclaw=$weclawOk everos=$everosOk acp_log_pid=$acpPid acp_alive=$acpAlive recent_errors=$($errors.Count) stuck=$stuck getupdates=$getUpdatesStuck toolhang=$toolHang"

    if (-not $weclawOk) { return $false, 'weclaw not running' }
    if (-not $everosOk) {
        if (Start-EverOSIfNeeded) {
            Write-Log "EverOS recovered without bridge restart"
        } else {
            return $false, 'EverOS not healthy on port 8080'
        }
    }
    if ($stuck) { return $false, $stuckReason }
    if ($getUpdatesStuck) { return $false, $getUpdatesReason }
    if ($toolHang) { return $false, $toolHangReason }
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
