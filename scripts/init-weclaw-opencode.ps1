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
    'You are the WeChat remote-control specialist via OpenCode ACP. DeepSeek API billing via paid key.',
    'WeClaw planner may handle atomic tasks (screenshot/OCR/off/wake/stock/unlock/gui steps) before you.',
    'When you receive [PLANNER:...] prefix: load the indicated weclaw-*-agent skill; at most ONE bash per turn.',
    'Compound fallback: load wechat-task-orchestrator; Plan->Act->Verify->Report; max 3 tool calls then reply.',
    'UNLOCK: output exactly WECLAW_DELEGATE: openclaw-unlocker — never bash unlock-screen.ps1.',
    'OCR/检索: wechat-screen-ocr + screen-ocr.ps1 — NOT unlock. Unknown apps: prefer gui is handled by planner; you use fixed scripts only.',
    'STOCK: stock-info.ps1 once; reply = verbatim WECHAT_STOCK_CARD.',
    'Never leak English tool titles or skill names to user. Final reply <=120 chars except stock card.',
    'WECHAT_PROGRESS for multi-step. Chinese ps1 = UTF-8 BOM + utf8-console.ps1.'
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
    cancel_previous  = $true
    router_enabled   = $true
    router_agent     = "planner"
    specialist_agent = "opencode"
}

$plannerPrompt = @(
    'You are a WeChat PC task planner. Reply with JSON only (optionally fenced in ```json).',
    'Schema: {"domain":"screen|file|browser|doc|sys|info|compound|chat","action":"screenshot|ocr|wake|off|unlock|open_file|music|desktop_typing|stock|gui|rustdesk|orchestrate|chat","compound":bool,"params":{},"steps":[{"action":"unlock|wake|off|screenshot|ocr|stock|gui|rustdesk|open_file","goal":"..."}]}',
    'Rules: 检索/看屏幕文字/下载进度/网盘 -> ocr or [gui,ocr], NOT screenshot alone for reading.',
    '截图->screenshot. rustdesk/RustDesk/远程桌面 -> steps:[{"action":"rustdesk"}] only; add screenshot step only if user asks 截图.',
    'Do NOT add unlock/wake unless user explicitly asks 解锁/解除锁屏/进桌面. Never unlock for 打开某应用.',
    '打开未知App(非rustdesk)-> single gui step with full user goal. Max 3 steps unless user lists many actions.',
    '解锁/进桌面->unlock only when user asks. Plain 锁屏 without 解->chat/chat. Pure chat->chat/chat.',
    'Complex/multi-step desktop -> orchestrate with gui/open_file/screenshot steps (max 3). Coding/doc -> chat/chat so OpenCode handles; if repeat task, user may ask to add a fixed script.'
) -join ' '

function Get-DeepSeekApiKey {
    $keyPath = Join-Path $weclawDir "deepseek.json"
    if (Test-Path $keyPath) {
        $k = (Get-Content $keyPath -Raw -Encoding UTF8 | ConvertFrom-Json).api_key
        if ($k) { return $k.Trim() }
    }
    if (Test-Path $authPath) {
        $auth = Get-Content $authPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $k = ($auth.deepseek).key
        if ($k) { return $k.Trim() }
    }
    return $null
}

function Ensure-PlannerAgent {
    param(
        [object]$Cfg,
        [string]$ApiKey
    )
    if (-not $ApiKey) {
        Write-Host "WARNING: No DeepSeek API key for planner; router will fall back to OpenCode only" -ForegroundColor Yellow
        if ($Cfg.routing) {
            $Cfg.routing | Add-Member -NotePropertyName router_enabled -NotePropertyValue $false -Force
        }
        return
    }
    if (-not $Cfg.agents) {
        $Cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{})
    }
    $plannerCfg = [ordered]@{
        type          = "http"
        endpoint      = "https://api.deepseek.com/chat/completions"
        api_key       = $ApiKey
        model         = "deepseek-chat"
        system_prompt = $plannerPrompt
        max_history   = 0
    }
    $Cfg.agents | Add-Member -NotePropertyName planner -NotePropertyValue ([pscustomobject]$plannerCfg) -Force
    Write-Host "Configured agents.planner (HTTP deepseek-chat, JSON only)" -ForegroundColor Green

    if (-not $Cfg.routing) {
        $Cfg | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$defaultRouting)
    } else {
        $Cfg.routing | Add-Member -NotePropertyName router_enabled -NotePropertyValue $true -Force
        $Cfg.routing | Add-Member -NotePropertyName router_agent -NotePropertyValue "planner" -Force
        $Cfg.routing | Add-Member -NotePropertyName specialist_agent -NotePropertyValue "opencode" -Force
    }
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
        if ($null -eq $Cfg.routing.router_enabled) {
            $Cfg.routing | Add-Member -NotePropertyName router_enabled -NotePropertyValue $true -Force
        }
        $Cfg.routing | Add-Member -NotePropertyName simple_bypass -NotePropertyValue $false -Force
        $Cfg.routing | Add-Member -NotePropertyName cancel_previous -NotePropertyValue $true -Force
        if (-not $Cfg.routing.router_agent) {
            $Cfg.routing | Add-Member -NotePropertyName router_agent -NotePropertyValue "planner" -Force
        }
        if (-not $Cfg.routing.specialist_agent) {
            $Cfg.routing | Add-Member -NotePropertyName specialist_agent -NotePropertyValue "opencode" -Force
        }
    }
}

function Remove-LegacyRouterAgents {
    param([object]$Cfg)
    if (-not $Cfg.agents) { return }
    foreach ($name in @('router', 'deepseek-router', 'codex')) {
        if ($Cfg.agents.PSObject.Properties.Name -contains $name) {
            $Cfg.agents.PSObject.Properties.Remove($name)
            Write-Host "Removed legacy agent: $name" -ForegroundColor Yellow
        }
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
Ensure-PlannerAgent -Cfg $cfg -ApiKey (Get-DeepSeekApiKey)
Ensure-LocalUnlocker -Cfg $cfg
Remove-LegacyRouterAgents -Cfg $cfg

$json = $cfg | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
Write-Host "Wrote $configPath" -ForegroundColor Green

Write-Host "  default_agent: opencode"
Write-Host "  model: $model (paid DeepSeek via OpenCode auth)"
Write-Host "  cwd: $workDir"
Write-Host "  routing.cancel_previous: true (new message cancels in-flight task)"
Write-Host "  routing.router_enabled: $($cfg.routing.router_enabled) (planner JSON -> scripts/steps -> OpenCode fallback)"
Write-Host "  routing.router_agent: $($cfg.routing.router_agent)"
Write-Host "  routing.specialist_agent: $($cfg.routing.specialist_agent)"
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
