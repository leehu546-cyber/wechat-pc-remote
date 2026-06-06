# wake-server.ps1 - HTTP server for mobile one-tap display wake (PWA + /api/wake)
param()

$ErrorActionPreference = "Continue"

. (Join-Path $PSScriptRoot "wake-server-util.ps1")

$repoRoot = Split-Path $PSScriptRoot -Parent
$mobileDir = Join-Path $repoRoot "wake-mobile"
$wakeScript = Join-Path $PSScriptRoot "wake-screen.ps1"
$logPath = Join-Path $env:USERPROFILE ".weclaw\wake-server.log"
$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') $Message"
    try {
        Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
}

$config = Read-WakeServerConfig
if (-not $config.token) {
    $config = Ensure-WakeServerConfig
}

$port = $config.port
$token = $config.token
$bind = $config.bind

function Get-ListenerPrefixes {
    param([string]$Bind, [int]$Port)
    if ($Bind -and $Bind -ne "+") {
        return @("http://${Bind}:${Port}/")
    }
    # Prefer LAN IP (no urlacl) then localhost; + needs admin urlacl — try last
    $list = @()
    foreach ($ip in (Get-LanIPv4Addresses)) {
        $list += "http://${ip}:${Port}/"
    }
    $list += @(
        "http://127.0.0.1:${Port}/",
        "http://localhost:${Port}/",
        "http://+:${Port}/"
    )
    return $list | Select-Object -Unique
}

$listener = $null
foreach ($prefix in (Get-ListenerPrefixes -Bind $bind -Port $port)) {
    $candidate = New-Object System.Net.HttpListener
    try {
        $candidate.Prefixes.Add($prefix)
        $candidate.Start()
        $listener = $candidate
        Write-Log "started on $prefix"
        break
    } catch {
        Write-Log "failed $prefix : $_"
        try { $candidate.Close() } catch { }
    }
}
if (-not $listener) {
    Write-Log "no listener prefix succeeded"
    exit 1
}

$script:lastWake = [datetime]::MinValue
$script:rateLimitSec = 2

function Get-RequestToken {
    param([System.Net.HttpListenerRequest]$Request)
    $auth = $Request.Headers["Authorization"]
    if ($auth -and $auth -match '^Bearer\s+(.+)$') {
        return $Matches[1].Trim()
    }
    return $Request.QueryString["token"]
}

function Close-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [string]$ContentType,
        [byte[]]$Bytes
    )
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $Bytes.Length
    $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    $Response.OutputStream.Close()
}

function Send-Json {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [object]$Body
    )
    $json = $Body | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    Close-Response -Response $Response -StatusCode $StatusCode -ContentType "application/json; charset=utf-8" -Bytes $bytes
}

function Send-Text {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [string]$Text,
        [string]$ContentType = "text/plain; charset=utf-8"
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    Close-Response -Response $Response -StatusCode $StatusCode -ContentType $ContentType -Bytes $bytes
}

function Send-File {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$FilePath,
        [string]$ContentType
    )
    if (-not (Test-Path $FilePath)) {
        Send-Text -Response $Response -StatusCode 404 -Text "not found"
        return
    }
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    Close-Response -Response $Response -StatusCode 200 -ContentType $ContentType -Bytes $bytes
}

function Invoke-WakeDisplay {
    if (-not (Test-Path $wakeScript)) {
        return @{ ok = $false; message = "wake-screen.ps1 missing" }
    }
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wakeScript 2>&1
    $text = ($out | ForEach-Object { "$_" }) -join " "
    if ($text -match 'WECHAT_OK') {
        return @{ ok = $true; message = "已唤醒显示器" }
    }
    return @{ ok = $true; message = $(if ($text) { $text } else { "wake sent" }) }
}

Write-Log "listening on $($listener.Prefixes -join ', ')"

while ($listener.IsListening) {
    $context = $null
    try {
        $context = $listener.GetContext()
    } catch {
        if ($listener.IsListening) {
            Write-Log "GetContext error: $_"
        }
        break
    }

    $request = $context.Request
    $response = $context.Response
    $path = $request.Url.LocalPath.TrimEnd('/')
    if (-not $path) { $path = "/" }

    try {
        switch ($path) {
            "/" {
                Send-File -Response $response -FilePath (Join-Path $mobileDir "index.html") -ContentType "text/html; charset=utf-8"
            }
            "/manifest.json" {
                Send-File -Response $response -FilePath (Join-Path $mobileDir "manifest.json") -ContentType "application/manifest+json; charset=utf-8"
            }
            "/icon.svg" {
                Send-File -Response $response -FilePath (Join-Path $mobileDir "icon.svg") -ContentType "image/svg+xml"
            }
            "/api/health" {
                Send-Json -Response $response -StatusCode 200 -Body @{ ok = $true; service = "wake-server" }
            }
            "/api/wake" {
                if ($request.HttpMethod -ne "POST") {
                    Send-Json -Response $response -StatusCode 405 -Body @{ ok = $false; error = "POST only" }
                    break
                }
                $reqToken = Get-RequestToken -Request $request
                if ($reqToken -ne $token) {
                    Write-Log "unauthorized wake from $($request.RemoteEndPoint)"
                    Send-Json -Response $response -StatusCode 401 -Body @{ ok = $false; error = "unauthorized" }
                    break
                }
                $elapsed = ((Get-Date) - $script:lastWake).TotalSeconds
                if ($elapsed -lt $script:rateLimitSec) {
                    Send-Json -Response $response -StatusCode 429 -Body @{ ok = $false; error = "rate limited" }
                    break
                }
                $script:lastWake = Get-Date
                $result = Invoke-WakeDisplay
                Write-Log "wake from $($request.RemoteEndPoint) -> $($result.message)"
                Send-Json -Response $response -StatusCode 200 -Body $result
            }
            default {
                Send-Text -Response $response -StatusCode 404 -Text "not found"
            }
        }
    } catch {
        Write-Log "handler error $path : $_"
        try {
            Send-Json -Response $response -StatusCode 500 -Body @{ ok = $false; error = "internal error" }
        } catch { }
    }
}
