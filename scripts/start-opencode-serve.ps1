# Start OpenCode serve in background (always-on for WeChat brain)
$ErrorActionPreference = "SilentlyContinue"

$logDir = Join-Path $env:USERPROFILE ".wechat-local-chat\logs"
$pidFile = Join-Path $env:USERPROFILE ".wechat-local-chat\opencode-serve.pid"
$logFile = Join-Path $logDir "opencode-serve.log"
$errFile = Join-Path $logDir "opencode-serve.err.log"
$port = 4096
$serveUrl = "http://127.0.0.1:$port"

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Test-ServeUp {
    try {
        $null = Invoke-WebRequest -Uri $serveUrl -UseBasicParsing -TimeoutSec 2
        return $true
    } catch {
        if ($_.Exception.Response) { return $true }
        return $false
    }
}

if (Test-ServeUp) { exit 0 }

if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
        if (Test-ServeUp) { exit 0 }
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    }
}

$opencodeCmd = Join-Path $env:APPDATA "npm\opencode.cmd"
if (-not (Test-Path $opencodeCmd)) {
    $opencodeCmd = (Get-Command opencode -ErrorAction SilentlyContinue).Source
}
if (-not $opencodeCmd -or -not (Test-Path $opencodeCmd)) { exit 1 }

$proc = Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c", "`"$opencodeCmd`" serve --port $port --hostname 127.0.0.1" `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $errFile `
    -PassThru

Set-Content -Path $pidFile -Value $proc.Id -Encoding ASCII

for ($i = 0; $i -lt 45; $i++) {
    Start-Sleep -Seconds 1
    if (Test-ServeUp) { exit 0 }
}
exit 1
