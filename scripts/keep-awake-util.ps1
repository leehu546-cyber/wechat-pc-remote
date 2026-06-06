# Shared helpers for keep-awake daemon singleton (dot-sourced by start-weclaw.ps1)

function Stop-KeepAwakeDaemon {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'keep-awake\.ps1' } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Start-KeepAwakeDaemon {
    param([string]$ScriptsRoot = $PSScriptRoot)
    Stop-KeepAwakeDaemon
    Start-Sleep -Milliseconds 300
    $script = Join-Path $ScriptsRoot "keep-awake.ps1"
    if (-not (Test-Path $script)) {
        Write-Warning "keep-awake.ps1 not found at $script"
        return $null
    }
    $proc = Start-Process powershell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script`""
    ) -WindowStyle Hidden -PassThru
    return $proc
}

function Get-KeepAwakeDaemonPids {
    @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'keep-awake\.ps1' } |
        ForEach-Object { $_.ProcessId })
}

function Test-WatchdogRunning {
    $null -ne (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'weclaw-watchdog\.ps1' } |
        Select-Object -First 1)
}

function Stop-WatchdogDaemon {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match 'weclaw-watchdog\.ps1' } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Start-WatchdogDaemon {
    param([string]$ScriptsRoot = $PSScriptRoot)
    Stop-WatchdogDaemon
    Start-Sleep -Milliseconds 300
    $watchdog = Join-Path $ScriptsRoot "weclaw-watchdog.ps1"
    if (-not (Test-Path $watchdog)) {
        Write-Warning "weclaw-watchdog.ps1 not found at $watchdog"
        return $null
    }
    $vbs = Join-Path $ScriptsRoot "run-hidden.vbs"
    $psCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$watchdog`" -Daemon"
    if (Test-Path $vbs) {
        return Start-Process wscript.exe -ArgumentList @("//B", "`"$vbs`"", "`"$psCmd`"") -WindowStyle Hidden -PassThru
    }
    return Start-Process powershell.exe -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$watchdog`"", "-Daemon"
    ) -WindowStyle Hidden -PassThru
}
