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
$routerPrompt = @(
    'You are WeClaw Router — a JSON-only intent classifier for WeChat PC-control messages.',
    'Output EXACTLY one JSON object, no markdown, no explanation, no tools.',
    'Schema: {"domain":"screen|file|browser|doc|sys|info|compound|chat","action":"screenshot|ocr|wake|off|unlock|open_file|music|desktop_typing|stock|orchestrate|chat","compound":false,"params":{}}',
    'Rules: 检索/看屏幕上有什么/读屏幕文字 → domain=screen action=ocr. 截图 → screenshot. 亮屏/开屏 → wake. 关屏/熄屏 → off.',
    '解锁/解除锁屏/进桌面/锁屏输密码 → domain=sys action=unlock. Plain 锁屏 alone is NOT unlock — use action=chat domain=chat.',
    '股票/持仓/510300 → domain=info action=stock. 放歌/听歌 → domain=browser action=music. 打开文件 → domain=file action=open_file.',
    '应用里输入/Word/WPS打字 → domain=doc action=desktop_typing. Multi-step or open+screenshot+verify → domain=compound action=orchestrate compound=true.',
    'General chat/greeting/time/questions with no PC action → domain=chat action=chat.'
) -join ' '

$specialistPrompt = @(
    'You are WeClaw Specialist — execution brain AFTER the Router has classified intent.',
    'WeClaw Router already chose domain/action; follow [ROUTER:...] prefix in the user message.',
    'Load the indicated weclaw-*-agent skill, then run ONE fixed script or output WECLAW_DELEGATE for unlock.',
    'Read .opencode/AGENTS.md for reply templates and script rules.',
    'Compound tasks: load wechat-task-orchestrator, Plan->Act->Verify->Report in one WeChat turn.',
    'OCR summary-only turns: user message says OCR already ran — summarize in ≤40 Chinese chars, no tools.',
    'UNLOCK: only when [ROUTER:sys/unlock] or user clearly wants unlock — output exactly: WECLAW_DELEGATE: openclaw-unlocker. Never bash unlock-screen.ps1.',
    'STOCK: run scripts/stock-info.ps1 once; reply = verbatim mini WECHAT_STOCK_CARD from stdout.',
    'Prefer WECHAT_USER_REPLY from script stdout; never retype Chinese stock card text.',
    'Emit WECHAT_PROGRESS: <step> for multi-step work. Final reply ≤120 chars except stock card.',
    'Encoding: Chinese scripts use UTF-8 BOM + scripts/utf8-console.ps1.'
) -join ' '

# Legacy name kept for opencode agent block below
$prompt = $specialistPrompt

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
    router_agent     = "router"
    specialist_agent = "opencode"
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

function Ensure-RouterAgents {
    param(
        [object]$Cfg,
        [string]$OpenCodeCmd,
        [string]$WorkDir,
        [string]$Model
    )
    if (-not $Cfg.agents) {
        $Cfg | Add-Member -NotePropertyName agents -NotePropertyValue (@{})
    }
    if (-not $Cfg.agents.router) {
        $Cfg.agents | Add-Member -NotePropertyName router -NotePropertyValue ([pscustomobject]@{
            type = "acp"; command = $OpenCodeCmd; args = @("acp"); cwd = $WorkDir; model = $Model
            system_prompt = $routerPrompt
        })
        Write-Host "Added router agent (JSON-only classifier)" -ForegroundColor Yellow
    } else {
        $Cfg.agents.router | Add-Member -NotePropertyName system_prompt -NotePropertyValue $routerPrompt -Force
        if (-not $Cfg.agents.router.command) {
            $Cfg.agents.router | Add-Member -NotePropertyName command -NotePropertyValue $OpenCodeCmd -Force
        }
        if (-not $Cfg.agents.router.cwd) {
            $Cfg.agents.router | Add-Member -NotePropertyName cwd -NotePropertyValue $WorkDir -Force
        }
        if (-not $Cfg.agents.router.model) {
            $Cfg.agents.router | Add-Member -NotePropertyName model -NotePropertyValue $Model -Force
        }
    }
    if (-not $Cfg.routing) {
        $Cfg | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$defaultRouting)
    } else {
        if ($null -eq $Cfg.routing.router_enabled) {
            $Cfg.routing | Add-Member -NotePropertyName router_enabled -NotePropertyValue $true -Force
        }
        if (-not $Cfg.routing.router_agent) {
            $Cfg.routing | Add-Member -NotePropertyName router_agent -NotePropertyValue "router" -Force
        }
        if (-not $Cfg.routing.specialist_agent) {
            $Cfg.routing | Add-Member -NotePropertyName specialist_agent -NotePropertyValue "opencode" -Force
        }
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
        if ($null -eq $cfg.routing.router_enabled) {
            $cfg.routing | Add-Member -NotePropertyName router_enabled -NotePropertyValue $true -Force
            Write-Host "Added routing.router_enabled → true (Plan A two-stage router)" -ForegroundColor Yellow
        }
        if (-not $cfg.routing.router_agent) {
            $cfg.routing | Add-Member -NotePropertyName router_agent -NotePropertyValue "router" -Force
        }
        if (-not $cfg.routing.specialist_agent) {
            $cfg.routing | Add-Member -NotePropertyName specialist_agent -NotePropertyValue "opencode" -Force
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
        $cfg.agents.opencode | Add-Member -NotePropertyName system_prompt -NotePropertyValue $specialistPrompt -Force
    }
    Ensure-RouterAgents -Cfg $cfg -OpenCodeCmd $opencodeCmd -WorkDir $workDir -Model $model
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
            router = [ordered]@{
                type          = "acp"
                command       = $opencodeCmd
                args          = @("acp")
                cwd           = $workDir
                model         = $model
                system_prompt = $routerPrompt
            }
            opencode = [ordered]@{
                type          = "acp"
                command       = $opencodeCmd
                args          = @("acp")
                cwd           = $workDir
                model         = $model
                system_prompt = $specialistPrompt
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
Write-Host "  routing.router_enabled: $($defaultRouting.router_enabled) (Plan A: router → dispatch)"
Write-Host "  routing.router_agent: $($defaultRouting.router_agent)"
Write-Host "  routing.specialist_agent: $($defaultRouting.specialist_agent)"
Write-Host "  memory.everos: enabled=$($defaultMemory.everos.enabled)"
Write-Host "  memory.local: enabled=$($defaultMemory.local.enabled), max_turns=$($defaultMemory.local.max_turns)"
Write-Host ""
Write-Host "Next: weclaw start (scan QR on first run)" -ForegroundColor Cyan
