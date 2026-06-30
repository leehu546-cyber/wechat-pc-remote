param(
    [Parameter(Mandatory = $true)]
    [string]$Task,
    [int]$TimeoutSec = 480,
    [int]$PollSec = 20,
    [int]$MinWaitSec = 45,
    [int]$StablePolls = 3
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$wakeScript = Join-Path $PSScriptRoot "wake-screen.ps1"
if (Test-Path -LiteralPath $wakeScript) {
    & $wakeScript | Out-Null
    Start-Sleep -Milliseconds 800
}

$desktopInteract = Join-Path $PSScriptRoot "desktop-interact.ps1"
$accountSwitch = Join-Path $PSScriptRoot "cursor-account-switch.ps1"
$ocrScript = Join-Path $PSScriptRoot "screen-ocr.ps1"

function Write-Fail([string]$Code) {
    Write-Host "WECHAT_FAIL: $Code"
    exit 1
}

function Test-UpgradeHint([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    $t = $Text.ToLowerInvariant()
    foreach ($p in @('upgrade', 'subscribe', 'trial ended', 'usage limit', 'rate limit', 'pro plan', 'out of credits')) {
        if ($t.Contains($p)) { return $true }
    }
    if ($Text -match '\u5347\u7ea7|\u8ba2\u9605|\u989d\u5ea6|\u8bd5\u7528\u7ed3\u675f|\u8bf7\u5347\u7ea7') {
        return $true
    }
    return $false
}

function Get-FullScreenOcrText {
    if (-not (Test-Path -LiteralPath $ocrScript)) { return "" }
    $raw = & $ocrScript -SkipWake 2>&1 | Out-String
    if ($raw -match '(?s)--- OCR ---\s*(.*)$') {
        return $Matches[1].Trim()
    }
    return $raw.Trim()
}

function Get-OcrHash([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 16)
    } finally {
        $sha.Dispose()
    }
}

function Get-ResultSnippet([string]$Text, [int]$MaxChars = 180) {
    $Text = ($Text -replace "\s+", ' ').Trim()
    if ($Text.Length -le $MaxChars) { return $Text }
    return $Text.Substring($Text.Length - $MaxChars)
}

if (-not (Test-Path -LiteralPath $desktopInteract)) {
    Write-Fail "cursor_desktop_interact_missing"
}

$focusChat = Join-Path $PSScriptRoot "cursor-focus-wechat-chat.ps1"
if (Test-Path -LiteralPath $focusChat) {
    Write-Host "WECHAT_PROGRESS: open WeChat account transfer chat"
    & $focusChat
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "cursor_chat_focus_failed"
    }
}

$task = $Task.Trim()
if ($task.Length -lt 2) {
    Write-Fail "cursor_task_empty"
}

Write-Host "WECHAT_PROGRESS: submitting task to Cursor"
& $desktopInteract -App Cursor -Target chat_input -Text $task -Send
if ($LASTEXITCODE -ne 0) {
    Write-Fail "cursor_submit_failed"
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$minDone = (Get-Date).AddSeconds($MinWaitSec)
$lastHash = ""
$stable = 0
$switched = $false

Start-Sleep -Seconds $MinWaitSec

while ((Get-Date) -lt $deadline) {
    $ocr = Get-FullScreenOcrText
    if (Test-UpgradeHint $ocr) {
        if (-not $switched -and (Test-Path -LiteralPath $accountSwitch)) {
            Write-Host "WECHAT_PROGRESS: Cursor upgrade hint, switching account"
            & $accountSwitch
            if ($LASTEXITCODE -eq 0) {
                $switched = $true
                Start-Sleep -Seconds 5
                & $desktopInteract -App Cursor -Target chat_input -Text $task -Send
                if ($LASTEXITCODE -ne 0) { Write-Fail "cursor_submit_failed" }
                $stable = 0
                $lastHash = ""
                Start-Sleep -Seconds $MinWaitSec
                continue
            }
        }
        Write-Fail "cursor_upgrade_blocked"
    }

    $hash = Get-OcrHash $ocr
    if ($hash -ne "" -and $hash -eq $lastHash -and (Get-Date) -ge $minDone) {
        $stable++
    } else {
        $stable = 0
        $lastHash = $hash
    }

    if ($stable -ge $StablePolls) {
        $snippet = Get-ResultSnippet $ocr
        if ($snippet.Length -lt 8) {
            Write-Host "WECHAT_USER_REPLY: Cursor 已完成，请查看 Cursor 窗口。"
        } else {
            Write-Host "WECHAT_USER_REPLY: Cursor 结果摘要：$snippet"
        }
        Write-Host "WECHAT_OK: cursor_task_done"
        exit 0
    }

    Write-Host "WECHAT_PROGRESS: waiting for Cursor ($stable/$StablePolls)"
    Start-Sleep -Seconds $PollSec
}

$final = Get-ResultSnippet (Get-FullScreenOcrText) 160
if ($final.Length -lt 8) {
    Write-Fail "cursor_timeout"
}
Write-Host "WECHAT_USER_REPLY: Cursor 超时；屏幕摘要：$final"
Write-Host "WECHAT_OK: cursor_task_timeout_partial"
exit 0
