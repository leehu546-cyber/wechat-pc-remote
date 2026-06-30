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

$defaultRouting = @{
    simple_bypass      = $false
    cancel_previous    = $true
    router_enabled     = $true
    router_agent       = "planner"
    chat_agent         = "chat"
    specialist_agent   = "opencode"
    script_forge_agent = "scriptsmith"
}

$chatPrompt = @(
    'You are a concise WeChat assistant on the user''s Windows PC.',
    'Reply in plain Chinese, friendly and brief (<=120 chars unless user asks for detail).',
    'You do NOT run scripts or control the PC — the Planner routes tasks elsewhere.',
    'If user asks to screenshot/unlock/open apps, say you will pass it to the task system (they can rephrase as a command).'
) -join ' '

$taskWorkerPrompt = @(
    'You are the WeChat PC task worker via OpenCode ACP (NOT casual chat — chat uses HTTP DeepSeek).',
    'You receive [PLANNER:...] prefixed tasks only: compound fallback, file/browser/doc/music steps.',
    'Load the indicated weclaw-*-agent skill; at most ONE bash per turn; max 3 tool calls then reply.',
    'Compound: load wechat-task-orchestrator; Plan->Act->Verify->Report.',
    'UNLOCK: output exactly WECLAW_DELEGATE: openclaw-unlocker — never bash unlock-screen.ps1.',
    'Never leak English tool titles or skill names. Final reply <=120 chars except stock card.',
    'WECHAT_PROGRESS for multi-step. Chinese ps1 = UTF-8 BOM + utf8-console.ps1.'
) -join ' '

$scriptsmithPrompt = @(
    'You are ScriptSmith: write or fix scripts/*.ps1 for repeat WeChat PC tasks.',
    'Load wechat-scriptsmith. Output WECHAT_USER_REPLY when done.',
    'Register in config/script-manifest.json and run: python scripts/init-registry-db.py',
    'Max 2 bash calls. No casual chat.'
) -join ' '

$plannerPrompt = @(
    'You are a WeChat PC task planner. Reply with JSON only (optionally fenced in ```json).',
    'Schema: {"domain":"screen|file|browser|doc|sys|info|compound|chat|forge","action":"screenshot|ocr|wake|off|unlock|open_file|music|desktop_typing|stock|gui|rustdesk|orchestrate|chat|script_forge|netdisk_transfer","compound":bool,"params":{},"steps":[{"action":"unlock|wake|off|screenshot|ocr|stock|gui|rustdesk|open_file|desktop_typing","goal":"..."}]}',
    'Rules: 检索/看屏幕文字/下载进度/网盘 -> ocr or [gui,ocr], NOT screenshot alone for reading.',
    '网盘传输/百度下载/有没有在下载 -> netdisk_transfer (fixed script baidu-netdisk-transfer-status.ps1).',
    '截图->screenshot. rustdesk -> steps:[{"action":"rustdesk"}] only.',
    'Do NOT add unlock/wake unless user explicitly asks 解锁/解除锁屏/进桌面.',
    'WRITE RULE: 写/输入/打字/一段话/WPS/Word正文 -> doc/desktop_typing or steps with desktop_typing + desktop-interact.ps1. NEVER gui/windows-use for writing.',
    'GUI RULE: gui/windows-use ONLY for 打开应用/打开文件夹/聚焦窗口 with NO typing (e.g. 打开百度网盘, 打开文件夹).',
    '打开未知App(不写文字)-> single gui step. Max 3 steps unless user lists many actions.',
    'Pure chat/闲聊/你好/在吗-> chat/chat (HTTP DeepSeek, NOT OpenCode).',
    '做成固定脚本/沉淀/写脚本-> script_forge/script_forge (ScriptSmith/Herm).',
    'Complex desktop -> orchestrate with gui/open_file/screenshot (max 3). Unhandled coding -> orchestrate or chat.'
) -join ' '

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

$defaultProgress = @{
    enabled         = $true
    mode            = "brain"
    interval_sec    = 30
    max_messages    = 5
    start_delay_sec = 15
}

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
        $Cfg.routing | Add-Member -NotePropertyName chat_agent -NotePropertyValue "chat" -Force
        $Cfg.routing | Add-Member -NotePropertyName specialist_agent -NotePropertyValue "opencode" -Force
        $Cfg.routing | Add-Member -NotePropertyName script_forge_agent -NotePropertyValue "scriptsmith" -Force
    }
}

function Ensure-ChatAgent {
    param(
        [object]$Cfg,
        [string]$ApiKey
    )
    if (-not $ApiKey) { return }
    if (-not $Cfg.agents) {
        $Cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{})
    }
    $chatCfg = [ordered]@{
        type          = "http"
        endpoint      = "https://api.deepseek.com/chat/completions"
        api_key       = $ApiKey
        model         = "deepseek-chat"
        system_prompt = $chatPrompt
        max_history   = 20
    }
    $Cfg.agents | Add-Member -NotePropertyName chat -NotePropertyValue ([pscustomobject]$chatCfg) -Force
    Write-Host "Configured agents.chat (HTTP deepseek-chat, conversation)" -ForegroundColor Green
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
        system_prompt = $taskWorkerPrompt
    }
    $Cfg.agents | Add-Member -NotePropertyName opencode -NotePropertyValue ([pscustomobject]$opencodeCfg) -Force
    Write-Host "Configured agents.opencode (ACP task worker, model=$Model)" -ForegroundColor Green

    $scriptsmithCfg = [ordered]@{
        type          = "acp"
        command       = $OpenCodeCmd
        args          = @("acp")
        cwd           = $WorkDir
        model         = $Model
        system_prompt = $scriptsmithPrompt
    }
    $Cfg.agents | Add-Member -NotePropertyName scriptsmith -NotePropertyValue ([pscustomobject]$scriptsmithCfg) -Force
    Write-Host "Configured agents.scriptsmith (ACP ScriptSmith; swap to Herm via script_forge_agent)" -ForegroundColor Green

    $Cfg.default_agent = "chat"
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
        if (-not $Cfg.routing.chat_agent) {
            $Cfg.routing | Add-Member -NotePropertyName chat_agent -NotePropertyValue "chat" -Force
        }
        if (-not $Cfg.routing.script_forge_agent) {
            $Cfg.routing | Add-Member -NotePropertyName script_forge_agent -NotePropertyValue "scriptsmith" -Force
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
$apiKey = Get-DeepSeekApiKey
Ensure-PlannerAgent -Cfg $cfg -ApiKey $apiKey
Ensure-ChatAgent -Cfg $cfg -ApiKey $apiKey
Ensure-LocalUnlocker -Cfg $cfg
Remove-LegacyRouterAgents -Cfg $cfg

$json = $cfg | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
Write-Host "Wrote $configPath" -ForegroundColor Green

Write-Host "  default_agent: chat (HTTP DeepSeek; NOT OpenCode)"
Write-Host "  task worker: opencode (orchestrate / [PLANNER:...] only)"
Write-Host "  script_forge: $($cfg.routing.script_forge_agent)"
Write-Host "  model: $model (paid DeepSeek via OpenCode auth for ACP agents)"
Write-Host "  cwd: $workDir"
Write-Host "  routing: planner -> scripts | gui | chat(HTTP) | script_forge | opencode"
Write-Host "  routing.chat_agent: $($cfg.routing.chat_agent)"
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
