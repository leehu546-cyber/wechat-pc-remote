# Run WeChat-Ollama bridge in background (survives without open terminal)
$bridge = Join-Path $PSScriptRoot "..\wechat-local-chat\index.mjs"
$cliDist = Join-Path $PSScriptRoot "..\cli-in-wechat\dist\index.js"
$logDir = Join-Path $env:USERPROFILE ".wechat-local-chat\logs"
$logFile = Join-Path $logDir "bridge.log"
$pidFile = Join-Path $env:USERPROFILE ".wechat-local-chat\bridge.pid"

if (-not (Test-Path $cliDist)) { exit 1 }

# Already running?
if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
        exit 0
    }
}

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# Wait for Ollama (up to 2 min after boot)
for ($i = 0; $i -lt 24; $i++) {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
        break
    } catch {
        Start-Sleep -Seconds 5
    }
}

$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodePath) { exit 1 }

$errFile = Join-Path $logDir "bridge.err.log"
$proc = Start-Process -FilePath $nodePath `
    -ArgumentList "`"$bridge`"" `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $errFile `
    -PassThru

Set-Content -Path $pidFile -Value $proc.Id -Encoding ASCII
$stamp = Join-Path $logDir "started-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Set-Content -Path $stamp -Value "pid=$($proc.Id)" -Encoding ASCII
