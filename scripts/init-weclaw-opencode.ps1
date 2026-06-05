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
$prompt = @(
    'WeChat agent: always end with one concise Chinese reply (max 120 chars) after tools.',
    'Never finish with only tool calls. Say WECHAT_OK: <summary> when a PC task completes.',
    'Scripts must exit within 30s; NEVER while True. Prefer Start-Process msedge URL.',
    'Selenium: driver.quit() then exit. Read .opencode/AGENTS.md in project.'
) -join ' '

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

if (Test-Path $configPath) {
    $cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $cfg.agents) { $cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{}) }
    if (-not $cfg.agents.opencode) {
        $cfg.agents | Add-Member -NotePropertyName opencode -NotePropertyValue ([pscustomobject]@{
            type = "acp"; command = $opencodeCmd; args = @("acp"); cwd = $workDir; model = $model
        })
    }
    $cfg.default_agent = "opencode"
    $cfg.agents.opencode | Add-Member -NotePropertyName system_prompt -NotePropertyValue $prompt -Force
    $cfg.agents.opencode | Add-Member -NotePropertyName model -NotePropertyValue $model -Force
    $cfg.agents.opencode | Add-Member -NotePropertyName cwd -NotePropertyValue $workDir -Force
    $json = $cfg | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
    Write-Host "Updated opencode system_prompt in $configPath" -ForegroundColor Green
} else {
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
    [System.IO.File]::WriteAllText($configPath, $rawJson.Trim(), $utf8NoBom)
    Write-Host "Wrote $configPath" -ForegroundColor Green
}

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
