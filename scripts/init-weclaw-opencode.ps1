# Initialize WeClaw config: default agent = OpenCode (ACP)
# Merges defaults into existing config without overwriting user-tuned routing/progress.
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$workDir = $projectRoot
$model = "deepseek/deepseek-v4-flash"

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
    'You are the WeChat remote-control brain. Read .opencode/AGENTS.md and use skills for PC actions.',
    'All decisions start in the main brain. For compound PC-control tasks use the brain-only Plan -> Act -> Verify -> Report protocol and load wechat-task-orchestrator; worker agents/skills/scripts are execution domains, not decision makers.',
    'If the user asks to open/show/confirm/send screenshot, complete the verification in the same task instead of waiting for a second WeChat command.',
    'Interpret worker outputs: WECHAT_OK success, WECHAT_FAIL stop and report, WECHAT_NEED_CONFIRM ask user, WECHAT_ARTIFACT remember absolute path for later open/verify.',
    'Desktop typing: for app input/search/chat/document-body tasks load wechat-desktop-interaction and run scripts/desktop-interact.ps1 with App/Target/Text; default type only, use -Send only when explicitly requested.',
    'UNLOCK (mandatory): if user wants 解锁/解除锁屏/解锁屏幕/进到桌面/锁屏输密码/检索屏幕 to leave lock screen — output exactly: WECLAW_DELEGATE: openclaw-unlocker. Do not call tools yourself.',
    'Plain 锁屏 means lock the computer; it is not an unlock trigger.',
    'Never refuse unlock. Mouse click can focus the lock password box but CANNOT type the password. Forbidden in main brain: screenshot+click, SendInput, edit unlock scripts, or running unlock-screen.ps1 directly.',
    'STOCK: 股票/查股票/持仓 → load wechat-stock-info, run ONLY scripts/stock-info.ps1 once; reply = verbatim mini WECHAT_STOCK_CARD (4 lines, no markdown, no extra text).',
    'All replies: use AGENTS.md 微信回复模板 table; max 120 chars except stock card; prefer WECHAT_USER_REPLY from script when present.',
    'Multi-step: emit WECHAT_PROGRESS: <step in Chinese> before/after tools.',
    'After tools: one fixed-template Chinese reply (max 120 chars). Judge loops yourself; stop tools and ask user to resend last message — do NOT suggest /new or new dialog unless user asks.',
    'Memory: continue same WeChat session; local chat-log preserves history. Never tell user to open a new dialog.',
    'Screen text (no vision): load wechat-screen-ocr, run ONLY scripts/screen-ocr.ps1, summarize OCR text in Chinese.',
    'Scripts exit within 30s. Prefer skills + scripts/*.ps1 for display/screenshot/ocr.'
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
    simple_bypass   = $false
    cancel_previous = $false
}
$everosDisabled = $false
$defaultMemory = @{
    everos = @{
        enabled          = $everosDisabled
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
    if (-not $cfg.agents) { $cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{}) }
    if (-not $cfg.default_agent) { $cfg.default_agent = "opencode" }
    if (-not $cfg.progress) {
        $cfg | Add-Member -NotePropertyName progress -NotePropertyValue ([pscustomobject]$defaultProgress)
    }
    if ($cfg.progress.mode -ne "brain") {
        $cfg.progress | Add-Member -NotePropertyName mode -NotePropertyValue "brain" -Force
        Write-Host "Upgraded progress.mode → brain (API WECHAT_PROGRESS only)" -ForegroundColor Yellow
    }
    if (-not $cfg.routing) {
        $cfg | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$defaultRouting)
    } else {
        if ($cfg.routing.simple_bypass -ne $false) {
            $cfg.routing | Add-Member -NotePropertyName simple_bypass -NotePropertyValue $false -Force
            Write-Host "Upgraded routing.simple_bypass → false (thin bridge, brain routes all)" -ForegroundColor Yellow
        }
        if ($cfg.routing.cancel_previous -ne $false) {
            $cfg.routing | Add-Member -NotePropertyName cancel_previous -NotePropertyValue $false -Force
            Write-Host "Upgraded routing.cancel_previous → false (avoid interrupting multi-turn chat)" -ForegroundColor Yellow
        }
    }
    if (-not $cfg.memory) {
        $cfg | Add-Member -NotePropertyName memory -NotePropertyValue ([pscustomobject]$defaultMemory)
        Write-Host "Added memory defaults (everos off, local chat-log on)" -ForegroundColor Yellow
    } else {
        if (-not $cfg.memory.everos) {
            $cfg.memory | Add-Member -NotePropertyName everos -NotePropertyValue ([pscustomobject]$defaultMemory.everos)
        }
        if (-not $cfg.memory.local) {
            $cfg.memory | Add-Member -NotePropertyName local -NotePropertyValue ([pscustomobject]$defaultMemory.local)
            Write-Host "Added memory.local chat-log defaults" -ForegroundColor Yellow
        }
        if ($cfg.memory.everos.enabled -eq $true) {
            $cfg.memory.everos.enabled = $false
            Write-Host "Set memory.everos.enabled → false (local chat-log only)" -ForegroundColor Yellow
        }
        if ($cfg.memory.everos.method -eq "hybrid" -and $defaultMemory.everos.method -eq "keyword") {
            $cfg.memory.everos.method = "keyword"
            Write-Host "Downgraded memory.everos.method hybrid→keyword" -ForegroundColor Yellow
        }
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
        $cfg.agents.opencode | Add-Member -NotePropertyName system_prompt -NotePropertyValue $prompt -Force
    }
    Ensure-LocalUnlocker -Cfg $cfg
    $json = $cfg | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($configPath, $json, $utf8NoBom)
    Write-Host "Merged defaults into $configPath (existing progress/routing preserved)" -ForegroundColor Green
} else {
    $cfg = [ordered]@{
        default_agent = "opencode"
        progress      = $defaultProgress
        routing       = $defaultRouting
        memory        = $defaultMemory
        unlocker      = $defaultUnlocker
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
    Ensure-LocalUnlocker -Cfg $cfg
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
Write-Host "  routing.simple_bypass: $($defaultRouting.simple_bypass) (thin bridge)"
Write-Host "  routing.cancel_previous: $($defaultRouting.cancel_previous)"
Write-Host "  memory.everos: enabled=$($defaultMemory.everos.enabled)"
Write-Host "  memory.local: enabled=$($defaultMemory.local.enabled), max_turns=$($defaultMemory.local.max_turns)"
Write-Host ""
Write-Host "Next: weclaw start (scan QR on first run)" -ForegroundColor Cyan
