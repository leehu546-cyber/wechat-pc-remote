# Fix CC Switch Codex local routing (port 15721 conflict + disabled proxy_config)
$ErrorActionPreference = "Stop"
$ccSwitchExe = "$env:LOCALAPPDATA\Programs\CC Switch\cc-switch.exe"
$dbPath = "$env:USERPROFILE\.cc-switch\cc-switch.db"
$settingsPath = "$env:USERPROFILE\.cc-switch\settings.json"
$configPath = "$env:USERPROFILE\.codex\config.toml"
$backupDir = "$env:USERPROFILE\.cc-switch\backups\fix-routing-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$port = 15721

Write-Host "=== CC Switch routing fix ===" -ForegroundColor Cyan

New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item $dbPath $backupDir
Copy-Item $settingsPath $backupDir
Copy-Item $configPath $backupDir
Write-Host "Backed up to $backupDir" -ForegroundColor Green

# Stop CC Switch
Get-Process -Name "cc-switch" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Stopping CC Switch (PID $($_.Id))..."
    Stop-Process -Id $_.Id -Force
    Start-Sleep -Seconds 2
}

# Free port 15721 if occupied by orphan process
$lines = netstat -ano | Select-String ":$port\s"
foreach ($line in $lines) {
    if ($line -match '\s(\d+)\s*$') {
        $pid = [int]$Matches[1]
        if ($pid -gt 0) {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            Write-Host "Killing process on port ${port}: PID $pid ($($proc.ProcessName))" -ForegroundColor Yellow
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }
}

# Ensure settings.json master switch is on
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$settings.enableLocalProxy = $true
$settings.proxyConfirmed = $true
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Host "settings.json: enableLocalProxy=true" -ForegroundColor Green

# Enable Codex routing in SQLite
python -c "import sqlite3; from datetime import datetime, timezone; from pathlib import Path; db=sqlite3.connect(str(Path.home()/'.cc-switch'/'cc-switch.db')); cur=db.cursor(); now=datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S'); cur.execute(\"UPDATE proxy_config SET proxy_enabled=1, updated_at=? WHERE app_type='codex'\", (now,)); db.commit(); print('proxy_config codex:', cur.execute(\"SELECT app_type, proxy_enabled, enabled, live_takeover_active FROM proxy_config WHERE app_type='codex'\").fetchone()); db.close()"

# Point live Codex config at local proxy (CC Switch will manage key injection)
$content = Get-Content $configPath -Raw
if ($content -notmatch 'base_url = "http://127\.0\.0\.1:15721/v1"') {
    $content = $content -replace 'base_url = "https://api\.deepseek\.com"', 'base_url = "http://127.0.0.1:15721/v1"'
    Set-Content $configPath $content -Encoding UTF8 -NoNewline
    Write-Host "config.toml: base_url -> http://127.0.0.1:15721/v1" -ForegroundColor Green
} else {
    Write-Host "config.toml already uses local proxy" -ForegroundColor Green
}

# Start CC Switch
if (-not (Test-Path $ccSwitchExe)) {
    throw "CC Switch not found: $ccSwitchExe"
}
Write-Host "Starting CC Switch..."
Start-Process -FilePath $ccSwitchExe
Start-Sleep -Seconds 5

$listening = netstat -ano | Select-String "127\.0\.0\.1:$port\s.*LISTENING"
if ($listening) {
    Write-Host "OK: proxy listening on 127.0.0.1:$port" -ForegroundColor Green
    Write-Host $listening
} else {
    Write-Host "WARN: port $port not listening yet; check CC Switch UI / log" -ForegroundColor Yellow
}

Write-Host "`nLast CC Switch log lines:" -ForegroundColor Cyan
Get-Content "$env:USERPROFILE\.cc-switch\logs\cc-switch.log" -Tail 15
