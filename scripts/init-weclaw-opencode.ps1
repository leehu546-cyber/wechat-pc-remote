# Initialize WeClaw config: default agent = OpenCode (ACP)
$ErrorActionPreference = "Stop"

$projectRoot = "D:\cursor\61"
$workDir = $projectRoot
$model = "opencode/deepseek-v4-flash-free"

Write-Host "=== WeClaw + OpenCode init ===" -ForegroundColor Cyan

$opencodeCmd = Join-Path $env:APPDATA "npm\opencode.cmd"
if (-not (Test-Path $opencodeCmd)) {
    $opencodeCmd = (Get-Command opencode -ErrorAction Stop).Source
}
Write-Host "OpenCode: $opencodeCmd" -ForegroundColor Green

$weclawDir = Join-Path $env:USERPROFILE ".weclaw"
$configPath = Join-Path $weclawDir "config.json"
New-Item -ItemType Directory -Path $weclawDir -Force | Out-Null

$cmdEscaped = $opencodeCmd -replace '\\', '\\'
$workEscaped = $workDir -replace '\\', '\\'
$prompt = 'Reply in concise Chinese for WeChat (under 120 chars). Use PowerShell for PC tasks; probe real exe paths before Start-Process.'

$rawJson = @"
{
  "default_agent": "opencode",
  "agents": {
    "opencode": {
      "type": "acp",
      "command": "$cmdEscaped",
      "args": ["acp"],
      "cwd": "$workEscaped",
      "model": "$model",
      "system_prompt": "$prompt"
    }
  }
}
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($configPath, $rawJson.Trim(), $utf8NoBom)
Write-Host "Wrote $configPath" -ForegroundColor Green

# Migrate legacy wechat-local-chat credentials if WeClaw has none
$accountsDir = Join-Path $weclawDir "accounts"
$legacyCred = Join-Path $env:USERPROFILE ".wechat-local-chat\credentials.json"
if (-not (Test-Path $accountsDir) -and (Test-Path $legacyCred)) {
    $legacy = Get-Content $legacyCred -Raw -Encoding UTF8 | ConvertFrom-Json
    New-Item -ItemType Directory -Path $accountsDir -Force | Out-Null
    $id = ($legacy.ilinkBotId -replace '@', '-' -replace '\.', '-')
    $weclawCred = @{
        bot_token     = $legacy.botToken
        ilink_bot_id  = $legacy.ilinkBotId
        baseurl       = $legacy.baseUrl
        ilink_user_id = $legacy.ilinkUserId
    } | ConvertTo-Json -Depth 3 -Compress
    $credPath = Join-Path $accountsDir "$id.json"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($credPath, $weclawCred, $utf8NoBom)
    Write-Host "Migrated WeChat credentials from wechat-local-chat" -ForegroundColor Green
}

# Re-write credentials without BOM if already migrated (fixes WeClaw load)
if (Test-Path $accountsDir) {
    Get-ChildItem $accountsDir -Filter "*.json" | ForEach-Object {
        try {
            $c = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($c.bot_token) {
                $fixed = @{
                    bot_token     = $c.bot_token
                    ilink_bot_id  = $c.ilink_bot_id
                    baseurl       = $c.baseurl
                    ilink_user_id = $c.ilink_user_id
                } | ConvertTo-Json -Compress
                $utf8 = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($_.FullName, $fixed, $utf8)
            }
        } catch { }
    }
}
Write-Host "  default_agent: opencode"
Write-Host "  model: $model"
Write-Host "  cwd: $workDir"
Write-Host ""
Write-Host "Next: weclaw start (scan QR on first run)" -ForegroundColor Cyan
