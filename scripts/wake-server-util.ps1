# Singleton helpers for wake-server.ps1 (dot-sourced by start/restart/status)

function Get-WakeServerConfigPath {
    Join-Path $env:USERPROFILE ".weclaw\wake-server.json"
}

function Get-WakeServerDefaults {
    @{
        port  = 18790
        token = $null
        bind  = "+"
    }
}

function Read-WakeServerConfig {
    $path = Get-WakeServerConfigPath
    $defaults = Get-WakeServerDefaults
    if (-not (Test-Path $path)) {
        return [PSCustomObject]$defaults
    }
    try {
        $cfg = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        [PSCustomObject]@{
            port  = if ($cfg.port) { [int]$cfg.port } else { $defaults.port }
            token = [string]$cfg.token
            bind  = if ($cfg.bind) { [string]$cfg.bind } else { $defaults.bind }
        }
    } catch {
        Write-Warning "Unreadable wake-server config: $path"
        [PSCustomObject]$defaults
    }
}

function Ensure-WakeServerConfig {
    $path = Get-WakeServerConfigPath
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $path) {
        return Read-WakeServerConfig
    }
    $token = [guid]::NewGuid().ToString("N")
    $cfg = @{
        port  = 18790
        token = $token
        bind  = "+"
    } | ConvertTo-Json
    Set-Content -Path $path -Value $cfg -Encoding UTF8
    Write-Host "Created wake-server config: $path" -ForegroundColor Green
    Read-WakeServerConfig
}

function Stop-WakeServerDaemon {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and (
                $_.CommandLine -match 'wake-server\.ps1' -or
                $_.CommandLine -match 'wake-server\.mjs'
            )
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

function Start-WakeServerDaemon {
    param([string]$ScriptsRoot = $PSScriptRoot)
    Stop-WakeServerDaemon
    Start-Sleep -Milliseconds 300
    Ensure-WakeServerConfig | Out-Null

    $nodeScript = Join-Path $ScriptsRoot "wake-server.mjs"
    if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $nodeScript)) {
        $proc = Start-Process node -ArgumentList @("`"$nodeScript`"") -WindowStyle Hidden -PassThru
        return $proc
    }

    $psScript = Join-Path $ScriptsRoot "wake-server.ps1"
    if (-not (Test-Path $psScript)) {
        Write-Warning "wake-server not found"
        return $null
    }
    $proc = Start-Process powershell -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$psScript`""
    ) -WindowStyle Hidden -PassThru
    return $proc
}

function Get-WakeServerDaemonPids {
    @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and (
                $_.CommandLine -match 'wake-server\.ps1' -or
                $_.CommandLine -match 'wake-server\.mjs'
            )
        } |
        ForEach-Object { $_.ProcessId })
}

function Get-LanIPv4Addresses {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        Select-Object -ExpandProperty IPAddress -Unique
}

function Get-WakeServerLogPath {
    Join-Path $env:USERPROFILE ".weclaw\wake-server.log"
}

function Get-WakeServerBoundPrefix {
    $logPath = Get-WakeServerLogPath
    if (-not (Test-Path $logPath)) { return $null }
    $line = Get-Content $logPath -Tail 30 -ErrorAction SilentlyContinue |
        Where-Object { $_ -match 'started on (http://[^\s/]+)' } |
        Select-Object -Last 1
    if ($line -match 'started on (http://[^\s/]+)') {
        return $Matches[1]
    }
    return $null
}

function Get-WakeMobileUrls {
    param([PSCustomObject]$Config = (Read-WakeServerConfig))
    $port = $Config.port
    $token = $Config.token
    if (Test-WakeServerLanReady) {
        return @(Get-LanWakeMobileUrl -Config $Config)
    }
    $bound = Get-WakeServerBoundPrefix
    if ($bound) {
        $base = $bound.TrimEnd('/')
        if ($base -match '0\.0\.0\.0') {
            return @(Get-LanWakeMobileUrl -Config $Config)
        }
        return @("${base}/?t=$token")
    }
    $ips = @(Get-LanIPv4Addresses)
    if ($ips.Count -eq 0) {
        return @("http://127.0.0.1:${port}/?t=$token")
    }
    foreach ($ip in $ips) {
        "http://${ip}:${port}/?t=$token"
    }
}

function Test-WakeServerLanReady {
    $bound = Get-WakeServerBoundPrefix
    if ($bound -match '0\.0\.0\.0|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.' ) {
        return $true
    }
    if ($bound -and $bound -notmatch '127\.0\.0\.1|localhost') {
        return $true
    }
    $cfg = Read-WakeServerConfig
    $port = $cfg.port
    $listen = netstat -ano 2>$null | Select-String "LISTENING" | Select-String ":$port\s"
    if ($listen -match '0\.0\.0\.0:\d+|192\.168\.') { return $true }
    return $false
}

function Get-LanWakeMobileUrl {
    param([PSCustomObject]$Config = (Read-WakeServerConfig))
    $port = $Config.port
    $token = $Config.token
    $ips = @(Get-LanIPv4Addresses)
    if ($ips.Count -gt 0) {
        return "http://$($ips[0]):${port}/?t=$token"
    }
    return "http://127.0.0.1:${port}/?t=$token"
}
