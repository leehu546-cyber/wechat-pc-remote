# Initialize WeClaw: OpenCode ACP + paid DeepSeek API (deepseek/deepseek-v4-flash)
# Merges into ~/.weclaw/config.json — no OpenCode Zen free cloud, no Codex.
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$workDir = $projectRoot
$model = "deepseek/deepseek-v4-flash"

Write-Host "=== WeClaw + OpenCode + DeepSeek (paid API) ===" -ForegroundColor Cyan

$opencodeCmd = Join-Path $env:APPDATA "npm\opencode.cmd"
if (-not (Test-Path $opencodeCmd)) {
    $opencodeCmd = (Get-Command opencode -ErrorAction Stop).Source
}
Write-Host "OpenCode: $opencodeCmd" -ForegroundColor Green

try {
    $ocVer = & $opencodeCmd --version 2>&1
    Write-Host "OpenCode version: $ocVer" -ForegroundColor Green
} catch {
    Write-Host "WARNING: opencode --version failed" -ForegroundColor Yellow
}

$authPath = Join-Path $env:USERPROFILE ".local\share\opencode\auth.json"
if (Test-Path $authPath) {
    Write-Host "OpenCode auth: OK ($authPath)" -ForegroundColor Green
} else {
    Write-Host "WARNING: OpenCode auth missing. Run: opencode auth login" -ForegroundColor Yellow
    Write-Host "  Or: scripts\setup-opencode-deepseek.ps1" -ForegroundColor Yellow
}

$weclawDir = Join-Path $env:USERPROFILE ".weclaw"
$configPath = Join-Path $weclawDir "config.json"
New-Item -ItemType Directory -Path $weclawDir -Force | Out-Null

$brainPrompt = @(
    'You are the WeChat remote-control brain via OpenCode ACP. Model billing uses the user paid DeepSeek API (deepseek/deepseek-v4-flash), NOT opencode/*-free.',
    'Read .opencode/AGENTS.md and skills. Every NL message: load weclaw-router, then ONE weclaw-*-agent expert, then atomic skill or fixed script.',
    'Compound tasks: load wechat-task-orchestrator; Plan->Act->Verify->Report in one WeChat turn.',
    'UNLOCK: only for 解锁/解除锁屏/进桌面/锁屏输密码 — output exactly: WECLAW_DELEGATE: openclaw-unlocker. Never bash unlock-screen.ps1.',
    'OCR/检索: wechat-screen-ocr + scripts/screen-ocr.ps1 only — NOT unlock. Plain 锁屏 is NOT unlock.',
    'STOCK: scripts/stock-info.ps1 once; reply = verbatim mini WECHAT_STOCK_CARD from stdout.',
    'Prefer WECHAT_USER_REPLY from script stdout; never retype Chinese stock card. Final reply <=120 chars except stock card.',
    'Emit WECHAT_PROGRESS: <step> for multi-step work. Encoding: Chinese ps1 = UTF-8 BOM + scripts/utf8-console.ps1.'
) -join ' '

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

$defaultProgress = @{
    enabled         = $true
    mode            = "brain"
    interval_sec    = 30
    max_messages    = 5
    start_delay_sec = 15
}
$defaultRouting = @{
    simple_bypass    = $false
    cancel_previous  = $false
    router_enabled   = $false
    router_agent     = "deepseek-router"
    specialist_agent = "opencode"
}
$defaultMemory = @{
    everos = @{
        enabled          = $false
        base_url         = "http://127.0.0.1:8080"
        top_k            = 5
        method           = "keyword"
        inject_max_chars = 1500
    }
    local = @{
        enabled   = $true
        max_turns = 30
        max_chars = 6000
    }
}
$defaultUnlocker = @{
    script_path = (Join-Path $workDir "scripts\unlock-screen.ps1")
    timeout_sec = 45
}

function Ensure-OpenCodeBrain {
    param(
        [object]$Cfg,
        [string]$OpenCodeCmd,
        [string]$WorkDir,
        [string]$Model
    )
    if (-not $Cfg.agents) {
        $Cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{})
    }

    $opencodeCfg = [ordered]@{
        type          = "acp"
        command       = $OpenCodeCmd
        args          = @("acp")
        cwd           = $WorkDir
        model         = $Model
        system_prompt = $brainPrompt
    }
    $Cfg.agents | Add-Member -NotePropertyName opencode -NotePropertyValue ([pscustomobject]$opencodeCfg) -Force
    Write-Host "Configured agents.opencode (ACP, model=$Model)" -ForegroundColor Green

    $Cfg.default_agent = "opencode"
    if (-not $Cfg.routing) {
        $Cfg | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$defaultRouting)
    } else {
        $Cfg.routing | Add-Member -NotePropertyName router_enabled -NotePropertyValue $false -Force
        $Cfg.routing | Add-Member -NotePropertyName specialist_agent -NotePropertyValue "opencode" -Force
        $Cfg.routing | Add-Member -NotePropertyName simple_bypass -NotePropertyValue $false -Force
        $Cfg.routing | Add-Member -NotePropertyName cancel_previous -NotePropertyValue $false -Force
    }
}

function Ensure-LocalUnlocker {
    param([object]$Cfg)
    if ($Cfg.agents -and $Cfg.agents.PSObject.Properties.Name -contains "openclaw-unlocker") {
        $Cfg.agents.PSObject.Properties.Remove("openclaw-unlocker")
    }
    if (-not $Cfg.unlocker) {
        $Cfg | Add-Member -NotePropertyName unlocker -NotePropertyValue ([pscustomobject]$defaultUnlocker)
    } else {
        if (-not $Cfg.unlocker.script_path) {
            $Cfg.unlocker | Add-Member -NotePropertyName script_path -NotePropertyValue $defaultUnlocker.script_path -Force
        }
        if (-not $Cfg.unlocker.timeout_sec) {
            $Cfg.unlocker | Add-Member -NotePropertyName timeout_sec -NotePropertyValue $defaultUnlocker.timeout_sec -Force
        }
    }
    Write-Host "Configured unlocker: $($Cfg.unlocker.script_path)" -ForegroundColor Green
}

if (Test-Path $configPath) {
    $cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $cfg = [pscustomobject]@{
        progress = [pscustomobject]$defaultProgress
        memory   = [pscustomobject]$defaultMemory
        agents   = @{}
    }
}

if (-not $cfg.progress) {
    $cfg | Add-Member -NotePropertyName progress -NotePropertyValue ([pscustomobject]$defaultProgress)
}
if ($cfg.progress.mode -ne "brain") {
    $cfg.progress | Add-Member -NotePropertyName mode -NotePropertyValue "brain" -Force
}
if (-not $cfg.memory) {
    $cfg | Add-Member -NotePropertyName memory -NotePropertyValue ([pscustomobject]$defaultMemory)
}
if ($cfg.memory.everos -and $cfg.memory.everos.enabled -eq $true) {
    $cfg.memory.everos.enabled = $false
}

Ensure-OpenCodeBrain -Cfg $cfg -OpenCodeCmd $opencodeCmd -WorkDir $workDir -Model $model
Ensure-LocalUnlocker -Cfg $cfg

$json = $cfg | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
Write-Host "Wrote $configPath" -ForegroundColor Green

Write-Host "  default_agent: opencode"
Write-Host "  model: $model (paid DeepSeek via OpenCode auth)"
Write-Host "  cwd: $workDir"
Write-Host "  routing.router_enabled: false (all NL -> OpenCode ACP)"
Write-Host ""
Write-Host "Next: scripts\restart-weclaw.ps1" -ForegroundColor Cyan

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
