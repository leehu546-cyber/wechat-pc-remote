# Initialize WeClaw: DeepSeek HTTP Router + Codex Specialist (no OpenCode)
# Merges defaults into ~/.weclaw/config.json
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$workDir = $projectRoot
$deepseekModel = "deepseek-chat"
$deepseekEndpoint = "https://api.deepseek.com/v1/chat/completions"

Write-Host "=== WeClaw init (DeepSeek HTTP + Codex) ===" -ForegroundColor Cyan

$codexCmd = Join-Path $env:APPDATA "npm\codex.cmd"
if (-not (Test-Path $codexCmd)) {
    $codexCmd = (Get-Command codex -ErrorAction Stop).Source
}
Write-Host "Codex: $codexCmd" -ForegroundColor Green

$weclawDir = Join-Path $env:USERPROFILE ".weclaw"
$configPath = Join-Path $weclawDir "config.json"
$deepseekKeyPath = Join-Path $weclawDir "deepseek.json"
New-Item -ItemType Directory -Path $weclawDir -Force | Out-Null

function Get-DeepSeekApiKey {
    if ($env:DEEPSEEK_API_KEY -and $env:DEEPSEEK_API_KEY.Trim()) {
        return $env:DEEPSEEK_API_KEY.Trim()
    }
    if (Test-Path $deepseekKeyPath) {
        try {
            $k = Get-Content $deepseekKeyPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($k.api_key -and $k.api_key.ToString().Trim()) {
                return $k.api_key.ToString().Trim()
            }
        } catch { }
    }
    return $null
}

$deepseekKey = Get-DeepSeekApiKey
if (-not $deepseekKey) {
    Write-Host "WARNING: No DeepSeek API key." -ForegroundColor Yellow
    Write-Host "  Set env DEEPSEEK_API_KEY or run: scripts\setup-deepseek-key.ps1" -ForegroundColor Yellow
} else {
    Write-Host "DeepSeek API key: OK (from $(if ($env:DEEPSEEK_API_KEY) { 'env' } else { 'deepseek.json' }))" -ForegroundColor Green
}

$routerPrompt = @(
    'You are WeClaw Router — a JSON-only intent classifier for WeChat PC-control messages.',
    'Output EXACTLY one JSON object, no markdown, no explanation.',
    'Schema: {"domain":"screen|file|browser|doc|sys|info|compound|chat","action":"screenshot|ocr|wake|off|unlock|open_file|music|desktop_typing|stock|orchestrate|chat","compound":false,"params":{}}',
    'Rules: 检索/看屏幕上有什么/读屏幕文字 → domain=screen action=ocr. 截图 → screenshot. 亮屏/开屏 → wake. 关屏/熄屏 → off.',
    '解锁/解除锁屏/进桌面/锁屏输密码 → domain=sys action=unlock. Plain 锁屏 alone is NOT unlock — use action=chat domain=chat.',
    '股票/持仓/510300 → domain=info action=stock. 放歌/听歌 → domain=browser action=music. 打开文件 → domain=file action=open_file.',
    '应用里输入/Word/WPS打字 → domain=doc action=desktop_typing. Multi-step or open+screenshot+verify → domain=compound action=orchestrate compound=true.',
    'General chat/greeting/time/questions with no PC action → domain=chat action=chat.'
) -join ' '

$specialistPrompt = @(
    'You are WeClaw Specialist (Codex) — execution brain AFTER the Router classified intent.',
    'WeClaw Router already chose domain/action; follow [ROUTER:...] prefix in the user message.',
    'Working directory: D:\cursor\61. Read .opencode/AGENTS.md and load the indicated weclaw-*-agent skill.',
    'Run ONE fixed script under scripts/ or output WECLAW_DELEGATE: openclaw-unlocker for unlock. Never bash unlock-screen.ps1.',
    'Compound tasks: load wechat-task-orchestrator; Plan->Act->Verify->Report in one WeChat turn.',
    'STOCK: scripts/stock-info.ps1 once; reply = verbatim mini WECHAT_STOCK_CARD from stdout.',
    'Prefer WECHAT_USER_REPLY from script stdout. Final reply ≤120 chars except stock card.',
    'Emit WECHAT_PROGRESS: <step> for multi-step work.'
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
    router_enabled   = $true
    router_agent     = "deepseek-router"
    specialist_agent = "codex"
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

function Ensure-DeepSeekCodexAgents {
    param(
        [object]$Cfg,
        [string]$CodexCmd,
        [string]$WorkDir,
        [string]$ApiKey
    )
    if (-not $Cfg.agents) {
        $Cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{})
    }

    $routerCfg = [ordered]@{
        type          = "http"
        endpoint      = $deepseekEndpoint
        model         = $deepseekModel
        system_prompt = $routerPrompt
    }
    if ($ApiKey) { $routerCfg.api_key = $ApiKey }

    $Cfg.agents | Add-Member -NotePropertyName "deepseek-router" -NotePropertyValue ([pscustomobject]$routerCfg) -Force
    Write-Host "Configured deepseek-router (HTTP JSON classifier)" -ForegroundColor Green

    $codexArgs = @("app-server", "--listen", "stdio://")
    $codexCfg = [ordered]@{
        type          = "acp"
        command       = $CodexCmd
        args          = $codexArgs
        cwd           = $WorkDir
        system_prompt = $specialistPrompt
    }
    $Cfg.agents | Add-Member -NotePropertyName codex -NotePropertyValue ([pscustomobject]$codexCfg) -Force
    Write-Host "Configured codex specialist (ACP app-server)" -ForegroundColor Green

    $Cfg.default_agent = "codex"
    if (-not $Cfg.routing) {
        $Cfg | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$defaultRouting)
    } else {
        $Cfg.routing | Add-Member -NotePropertyName router_enabled -NotePropertyValue $true -Force
        $Cfg.routing | Add-Member -NotePropertyName router_agent -NotePropertyValue "deepseek-router" -Force
        $Cfg.routing | Add-Member -NotePropertyName specialist_agent -NotePropertyValue "codex" -Force
    }
}

function Ensure-LocalUnlocker {
    param([object]$Cfg)
    if ($Cfg.agents -and $Cfg.agents.PSObject.Properties.Name -contains "openclaw-unlocker") {
        $Cfg.agents.PSObject.Properties.Remove("openclaw-unlocker")
        Write-Host "Removed legacy HTTP agent: openclaw-unlocker" -ForegroundColor Yellow
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
    Write-Host "Configured local unlocker: $($Cfg.unlocker.script_path)" -ForegroundColor Green
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
if (-not $cfg.routing) {
    $cfg | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$defaultRouting)
} else {
    $cfg.routing | Add-Member -NotePropertyName simple_bypass -NotePropertyValue $false -Force
    $cfg.routing | Add-Member -NotePropertyName cancel_previous -NotePropertyValue $false -Force
}
if (-not $cfg.memory) {
    $cfg | Add-Member -NotePropertyName memory -NotePropertyValue ([pscustomobject]$defaultMemory)
}
if ($cfg.memory.everos -and $cfg.memory.everos.enabled -eq $true) {
    $cfg.memory.everos.enabled = $false
}

Ensure-DeepSeekCodexAgents -Cfg $cfg -CodexCmd $codexCmd -WorkDir $workDir -ApiKey $deepseekKey
Ensure-LocalUnlocker -Cfg $cfg

$json = $cfg | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
Write-Host "Wrote $configPath" -ForegroundColor Green

Write-Host "  default_agent: codex"
Write-Host "  router: deepseek-router (HTTP $deepseekModel)"
Write-Host "  specialist: codex (ACP)"
Write-Host "  cwd: $workDir"
Write-Host "  routing.router_enabled: true"
Write-Host ""
if (-not $deepseekKey) {
    Write-Host "Next: scripts\setup-deepseek-key.ps1  then  scripts\restart-weclaw.ps1" -ForegroundColor Yellow
} else {
    Write-Host "Next: scripts\restart-weclaw.ps1" -ForegroundColor Cyan
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
