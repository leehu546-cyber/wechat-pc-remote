# WeClaw ACP session watchdog - recover from stuck sessions (backup to session/cancel patch)
# Run as daemon: .\weclaw-watchdog.ps1 -Daemon
# One-shot   : .\weclaw-watchdog.ps1
param(
    [int]$ErrorThreshold = 3,
    [int]$ErrorWindowMinutes = 10,
    [int]$NoReplyMinutes = 5,
    [int]$QuickIntentGraceMinutes = 2,
    [int]$CheckIntervalSec = 60,
    [switch]$Daemon = $false
)

$ErrorActionPreference = "Continue"
$weclawLog = Join-Path $env:USERPROFILE ".weclaw\weclaw.log"
$weclawConfig = Join-Path $env:USERPROFILE ".weclaw\config.json"
$restartScript = Join-Path $PSScriptRoot "restart-weclaw.ps1"
$everosScript = Join-Path $PSScriptRoot "start-everos.ps1"
$watchdogLog = Join-Path $env:USERPROFILE ".weclaw\watchdog.log"

function Test-EverOSEnabled {
    if (-not (Test-Path $weclawConfig)) { return $false }
    try {
        $cfg = Get-Content $weclawConfig -Raw -Encoding UTF8 | ConvertFrom-Json
        return [bool]$cfg.memory.everos.enabled
    } catch {
        return $false
    }
}

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

function Get-LogLinesSinceBridgeStart {
    $lines = Get-RecentLogLines -Tail 800
    $startIdx = 0
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match 'Available agents:') {
            $startIdx = $i
            break
        }
    }
    if ($startIdx -gt 0) { return $lines[$startIdx..($lines.Count - 1)] }
    return $lines
}

function Get-ACPProcessIdFromLog {
    $lines = Get-LogLinesSinceBridgeStart
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

function Test-IsScreenshotOrWakeMessage([string]$Msg) {
    if ([string]::IsNullOrWhiteSpace($Msg)) { return $false }
    $keys = @(
        [char]0x622A + [char]0x56FE,
        [char]0x622A + [char]0x5C4F,
        [char]0x4EAE + [char]0x5C4F,
        [char]0x5524 + [char]0x9192 + [char]0x5C4F + [char]0x5E55,
        [char]0x70B9 + [char]0x4EAE + [char]0x5C4F + [char]0x5E55,
        [char]0x5F00 + [char]0x5C4F,
        [char]0x6253 + [char]0x5F00 + [char]0x5C4F + [char]0x5E55,
        [char]0x5173 + [char]0x5C4F,
        [char]0x7184 + [char]0x5C4F,
        [char]0x5173 + [char]0x95ED + [char]0x5C4F + [char]0x5E55,
        [char]0x5C4F + [char]0x5E55 + [char]0x5173 + [char]0x95ED
    )
    foreach ($k in $keys) { if ($Msg.Contains($k)) { return $true } }
    return $false
}

function Test-LocalQuickScriptRunning {
    foreach ($proc in Get-Process -Name powershell,pwsh,python -ErrorAction SilentlyContinue) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($cmd -match 'screenshot\.ps1|wake-screen\.ps1|turn-off-screen\.ps1|wake-display\.py') {
                return $true, "local script running (pid=$($proc.Id))"
            }
        } catch { }
    }
    return $false, ''
}

function Test-LastMessageIsQuickIntent {
    $lines = Get-LogLinesSinceBridgeStart
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '\[handler\] received from.*: "(.+)"') {
            $msg = $matches[1]
            if (Test-IsScreenshotOrWakeMessage $msg) {
                return $true, $msg
            }
            return $false, ''
        }
    }
    return $false, ''
}

function Get-RecentErrors {
    param([int]$WindowMinutes = $ErrorWindowMinutes)
    $cutoff = (Get-Date).AddMinutes(-$WindowMinutes)
    # GetUpdates handled separately - avoid single backoff triggering restart
    $patterns = @(
        'context canceled',
        'agent returned empty response',
        'default task canceled before reply',
        'turn timed out',
        'read loop ended',
        'connection refused.*8080',
        'everos.*search failed'
    )
    $errors = @()
    foreach ($line in (Get-LogLinesSinceBridgeStart)) {
        $ts = Parse-LogTimestamp $line
        if ($ts -and $ts -lt $cutoff) { continue }
        if ($line -match ($patterns -join '|')) { $errors += $line }
    }
    return $errors
}

function Test-NoReplyStuck {
    param([int]$StuckMinutes = $NoReplyMinutes)
    $lines = Get-LogLinesSinceBridgeStart
    $lastReceived = $null
    $lastReceivedIdx = -1
    $lastMsg = ''
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '\[handler\] received from.*: "(.+)"') {
            $lastReceived = Parse-LogTimestamp $lines[$i]
            $lastReceivedIdx = $i
            $lastMsg = $matches[1]
            break
        }
    }
    if (-not $lastReceived) { return $false, '' }

    $grace = $StuckMinutes
    if (Test-IsScreenshotOrWakeMessage $lastMsg) { $grace = $QuickIntentGraceMinutes + 2 }

    $age = ((Get-Date) - $lastReceived).TotalMinutes
    if ($age -lt $grace) { return $false, '' }

    for ($j = $lastReceivedIdx; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '\[sender\] sent reply to') {
            $progressTag = -join @([char]0x5904, [char]0x7406, [char]0x4E2D)
            if (-not $lines[$j].Contains($progressTag)) { return $false, '' }
            continue
        }
        if ($lines[$j] -match '\[handler\] agent replied') { return $false, '' }
        if ($lines[$j] -match '\[handler\] quick.*screenshot|\[handler\] quick.*wake') { return $false, '' }
        if ($lines[$j] -match 'Available agents:') { return $false, '' }
    }
    return $true, "no reply for $([math]::Round($age, 1)) min since '$lastMsg'"
}

function Test-GetUpdatesErrors {
    param([int]$WindowMinutes = 10, [int]$MinCount = 3)
    $cutoff = (Get-Date).AddMinutes(-$WindowMinutes)
    $count = 0
    foreach ($line in (Get-LogLinesSinceBridgeStart)) {
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
    param([int]$HangMinutes = 5)
    $lines = Get-LogLinesSinceBridgeStart
    $bridgeStart = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'Available agents:') {
            $bridgeStart = Parse-LogTimestamp $lines[$i]
            break
        }
    }

    $lastTool = $null
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match 'type=tool_call' -and $lines[$i] -notmatch 'tool_call_update') {
            $ts = Parse-LogTimestamp $lines[$i]
            if ($bridgeStart -and $ts -and $ts -lt $bridgeStart) { continue }
            $lastTool = $ts
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
        if ($lines[$i] -match '\[handler\] received from') { return $false, '' }
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
    $scriptRunning, $scriptReason = Test-LocalQuickScriptRunning
    if ($scriptRunning) {
        Write-Log "check: skip restart - $scriptReason"
        return $true, 'ok (quick script running)'
    }

    $quickMsg = ''
    $isQuick, $quickMsg = Test-LastMessageIsQuickIntent
    if ($isQuick) {
        $lines = Get-LogLinesSinceBridgeStart
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -match '\[handler\] received from.*: "(.+)"') {
                $ts = Parse-LogTimestamp $lines[$i]
                if ($ts -and ((Get-Date) - $ts).TotalMinutes -lt ($QuickIntentGraceMinutes + 2)) {
                    Write-Log "check: skip restart - quick intent in progress ($quickMsg)"
                    return $true, 'ok (quick intent grace)'
                }
                break
            }
        }
    }

    $weclawOk = $null -ne (Get-Process -Name weclaw -ErrorAction SilentlyContinue)
    $everosRequired = Test-EverOSEnabled
    $everosOk = if ($everosRequired) { Test-EverOSHealthy } else { $true }
    $acpPid = Get-ACPProcessIdFromLog
    $acpAlive = Test-ProcessAlive $acpPid
    $errors = Get-RecentErrors
    $stuck, $stuckReason = Test-NoReplyStuck
    $getUpdatesStuck, $getUpdatesReason = Test-GetUpdatesErrors
    $toolHang, $toolHangReason = Test-ToolHangStuck

    $everosLabel = if ($everosRequired) { $everosOk } else { 'skip' }
    Write-Log "check: weclaw=$weclawOk everos=$everosLabel acp_log_pid=$acpPid acp_alive=$acpAlive agent_errors=$($errors.Count) stuck=$stuck getupdates=$getUpdatesStuck toolhang=$toolHang"

    if (-not $weclawOk) { return $false, 'weclaw not running' }
    if ($everosRequired -and -not $everosOk) {
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
        return $false, "$($errors.Count) agent errors in last ${ErrorWindowMinutes}m"
    }
    if ($acpPid -and -not $acpAlive -and $errors.Count -ge 2) {
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
