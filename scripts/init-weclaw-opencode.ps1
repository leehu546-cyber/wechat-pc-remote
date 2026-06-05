# Initialize WeClaw config: default agent = OpenCode (ACP)
# Merges defaults into existing config without overwriting user-tuned routing/progress.
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$workDir = $projectRoot
$model = "zhipuai/glm-4-flash"

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
    'After any tool use, reply in one short Chinese sentence summarizing the outcome.',
    'Scripts must exit within 30s; NEVER while True. Prefer Start-Process msedge URL.',
    'Selenium detach: no driver.quit() in finally. Read .opencode/AGENTS.md in project.'
) -join ' '

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

$defaultProgress = @{
    enabled         = $true
    mode            = "minimal"
    interval_sec    = 30
    max_messages    = 3
    start_delay_sec = 30
}
$defaultRouting = @{
    simple_bypass   = $true
    cancel_previous = $false
}
$defaultMemory = @{
    everos = @{
        enabled          = $true
        base_url         = "http://127.0.0.1:8080"
        top_k            = 5
        method           = "keyword"
        inject_max_chars = 1500
    }
}

if (Test-Path $configPath) {
    $cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $cfg.agents) { $cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{}) }
    if (-not $cfg.default_agent) { $cfg.default_agent = "opencode" }
    if (-not $cfg.progress) {
        $cfg | Add-Member -NotePropertyName progress -NotePropertyValue ([pscustomobject]$defaultProgress)
    } elseif (-not $cfg.progress.mode) {
        $cfg.progress | Add-Member -NotePropertyName mode -NotePropertyValue "minimal" -Force
        $cfg.progress | Add-Member -NotePropertyName enabled -NotePropertyValue $true -Force
        $cfg.progress | Add-Member -NotePropertyName start_delay_sec -NotePropertyValue 30 -Force
        $cfg.progress | Add-Member -NotePropertyName interval_sec -NotePropertyValue 30 -Force
        if (-not $cfg.progress.max_messages) {
            $cfg.progress | Add-Member -NotePropertyName max_messages -NotePropertyValue 3 -Force
        }
        Write-Host "Upgraded progress to mode=minimal (30s delay)" -ForegroundColor Yellow
    }
    if (-not $cfg.routing) {
        $cfg | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$defaultRouting)
    }
    if (-not $cfg.memory) {
        $cfg | Add-Member -NotePropertyName memory -NotePropertyValue ([pscustomobject]$defaultMemory)
        Write-Host "Added memory.everos defaults (local http://127.0.0.1:8080)" -ForegroundColor Yellow
    } elseif (-not $cfg.memory.everos) {
        $cfg.memory | Add-Member -NotePropertyName everos -NotePropertyValue ([pscustomobject]$defaultMemory.everos)
        Write-Host "Added memory.everos defaults" -ForegroundColor Yellow
    } elseif ($cfg.memory.everos.method -eq "hybrid" -and $defaultMemory.everos.method -eq "keyword") {
        $cfg.memory.everos.method = "keyword"
        Write-Host "Downgraded memory.everos.method hybrid→keyword (local Ollama has no rerank)" -ForegroundColor Yellow
    }
    if (-not $cfg.agents.opencode) {
        $cfg.agents | Add-Member -NotePropertyName opencode -NotePropertyValue ([pscustomobject]@{
            type = "acp"; command = $opencodeCmd; args = @("acp"); cwd = $workDir; model = $model
            system_prompt = $prompt
        })
    } else {
        if (-not $cfg.agents.opencode.command) {
            $cfg.agents.opencode | Add-Member -NotePropertyName command -NotePropertyValue $opencodeCmd -Force
        }
        if (-not $cfg.agents.opencode.cwd) {
            $cfg.agents.opencode | Add-Member -NotePropertyName cwd -NotePropertyValue $workDir -Force
        }
        if (-not $cfg.agents.opencode.model) {
            $cfg.agents.opencode | Add-Member -NotePropertyName model -NotePropertyValue $model -Force
        }
    }
    $json = $cfg | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
    Write-Host "Merged defaults into $configPath (existing progress/routing preserved)" -ForegroundColor Green
} else {
    $cfg = [ordered]@{
        default_agent = "opencode"
        progress      = $defaultProgress
        routing       = $defaultRouting
        memory        = $defaultMemory
        agents        = [ordered]@{
            opencode = [ordered]@{
                type          = "acp"
                command       = $opencodeCmd
                args          = @("acp")
                cwd           = $workDir
                model         = $model
                system_prompt = $prompt
            }
        }
    }
    $json = $cfg | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
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
    [System.IO.File]::WriteAllText($credPath, $weclawCred, $utf8NoBom)
    Write-Host "Migrated WeChat credentials from wechat-local-chat" -ForegroundColor Green
}

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
                [System.IO.File]::WriteAllText($_.FullName, $fixed, $utf8NoBom)
            }
        } catch { }
    }
}
Write-Host "  default_agent: opencode"
Write-Host "  model: $model"
Write-Host "  cwd: $workDir"
Write-Host "  progress: mode=$($defaultProgress.mode), enabled=$($defaultProgress.enabled), start_delay=$($defaultProgress.start_delay_sec)s"
Write-Host "  routing.cancel_previous: $($defaultRouting.cancel_previous) (requires weclaw session/cancel patch)"
Write-Host "  memory.everos: enabled=$($defaultMemory.everos.enabled), base=$($defaultMemory.everos.base_url)"
Write-Host ""
Write-Host "Next: weclaw start (scan QR on first run)" -ForegroundColor Cyan
