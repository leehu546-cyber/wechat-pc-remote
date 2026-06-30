# Shared helpers for Cursor WeChat worker scripts
. (Join-Path $PSScriptRoot "utf8-console.ps1")

function Test-CursorUpgradeHint {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    $t = $Text.ToLowerInvariant()
    foreach ($p in @(
        'upgrade', 'subscribe', 'trial ended', 'usage limit', 'hit your usage',
        'rate limit', 'pro plan', 'out of credits', 'upgrade to pro', 'get cursor pro',
        'more agent usage', 'cursor pro'
    )) {
        if ($t.Contains($p)) { return $true }
    }
    if ($Text -match '\u5347\u7ea7|\u8ba2\u9605|\u989d\u5ea6|\u8bd5\u7528\u7ed3\u675f|\u8bf7\u5347\u7ea7|\u7528\u91cf|\u989d\u5ea6\u7528\u5b8c') {
        return $true
    }
    return $false
}

function Test-CursorAgentBusy {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    if ($Text -match '(?i)running|waiting for|generating|queued to send|planning|exploring|tool use|run in background|composer') {
        return $true
    }
    if ($Text -match '\d+\s*%\s*$|\d+\s*%\s*\n|Waiting fo') {
        return $true
    }
    return $false
}

function Get-CursorPanelOcrText {
    $ocrScript = Join-Path $PSScriptRoot "screen-ocr.ps1"
    if (-not (Test-Path -LiteralPath $ocrScript)) { return "" }
    $raw = & $ocrScript -SkipWake -CropLeftRatio 0.35 2>&1 | Out-String
    if ($raw -match '(?s)--- OCR ---\s*(.*)$') {
        return $Matches[1].Trim()
    }
    return $raw.Trim()
}

function Invoke-CursorAccountSwitchAndRefocus {
    param([string]$Task)
    $accountSwitch = Join-Path $PSScriptRoot "cursor-account-switch.ps1"
    $focusChat = Join-Path $PSScriptRoot "cursor-focus-wechat-chat.ps1"
    $desktopInteract = Join-Path $PSScriptRoot "desktop-interact.ps1"

    if (-not (Test-Path -LiteralPath $accountSwitch)) {
        return $false
    }
    Write-Host "WECHAT_PROGRESS: Cursor quota/limit detected, running AI assistant switch"
    & $accountSwitch
    if ($LASTEXITCODE -ne 0) { return $false }

    Start-Sleep -Seconds 3
    if (Test-Path -LiteralPath $focusChat) {
        & $focusChat
        if ($LASTEXITCODE -ne 0) { return $false }
    }

    if ($Task -and (Test-Path -LiteralPath $desktopInteract)) {
        & $desktopInteract -App Cursor -Target chat_input -Text $Task -Send
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    return $true
}

function Test-CursorSubmitAccepted {
    param(
        [string]$Task,
        [int]$WaitSec = 3
    )
    Start-Sleep -Seconds $WaitSec
    $ocr = Get-CursorPanelOcrText
    if (Test-CursorUpgradeHint $ocr) {
        return @{ Ok = $false; Reason = 'upgrade'; Ocr = $ocr }
    }
    if (Test-CursorAgentBusy $ocr) {
        return @{ Ok = $true; Reason = 'busy'; Ocr = $ocr }
    }
    $snippet = $Task
    if ($snippet.Length -gt 24) { $snippet = $snippet.Substring(0, 24) }
    if ($ocr -like "*$snippet*" -and -not (Test-CursorAgentBusy $ocr)) {
        return @{ Ok = $false; Reason = 'not_started'; Ocr = $ocr }
    }
    return @{ Ok = $true; Reason = 'unknown'; Ocr = $ocr }
}

function Submit-CursorTaskWithQuotaRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Task,
        [int]$MaxSwitchRetries = 1
    )

    $desktopInteract = Join-Path $PSScriptRoot "desktop-interact.ps1"
    $focusChat = Join-Path $PSScriptRoot "cursor-focus-wechat-chat.ps1"
    if (-not (Test-Path -LiteralPath $desktopInteract)) {
        Write-Host "WECHAT_FAIL: cursor_desktop_interact_missing"
        return $false
    }

    $task = $Task.Trim()
    if ($task.Length -lt 2) {
        Write-Host "WECHAT_FAIL: cursor_task_empty"
        return $false
    }

    for ($attempt = 0; $attempt -le $MaxSwitchRetries; $attempt++) {
        if (Test-Path -LiteralPath $focusChat) {
            & $focusChat
            if ($LASTEXITCODE -ne 0) {
                Write-Host "WECHAT_FAIL: cursor_chat_focus_failed"
                return $false
            }
        }

        Write-Host "WECHAT_PROGRESS: submitting task to Cursor (attempt $($attempt + 1))"
        & $desktopInteract -App Cursor -Target chat_input -Text $task -Send
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WECHAT_FAIL: cursor_submit_failed"
            return $false
        }

        $check = Test-CursorSubmitAccepted -Task $task -WaitSec 3
        if ($check.Ok) {
            Write-Host "WECHAT_OK: cursor_submitted"
            return $true
        }

        if ($check.Reason -eq 'upgrade' -or $check.Reason -eq 'not_started') {
            if ($attempt -lt $MaxSwitchRetries) {
                if (-not (Invoke-CursorAccountSwitchAndRefocus -Task $task)) {
                    break
                }
                continue
            }
        }
        break
    }

    Write-Host "WECHAT_FAIL: cursor_upgrade_blocked"
    return $false
}
