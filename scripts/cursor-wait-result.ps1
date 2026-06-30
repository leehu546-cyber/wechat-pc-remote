param(
    [Parameter(Mandatory = $true)]
    [string]$Task,
    [int]$TimeoutSec = 420,
    [int]$PollSec = 5,
    [int]$MinWaitSec = 8,
    [int]$StablePolls = 2
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "cursor-common.ps1")

function Write-Fail([string]$Code) {
    Write-Host "WECHAT_FAIL: $Code"
    exit 1
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

$task = $Task.Trim()
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$minDone = (Get-Date).AddSeconds($MinWaitSec)
$lastHash = ""
$stable = 0
$switched = $false
$upgradeStreak = 0
$sawBusy = $false

Start-Sleep -Seconds $MinWaitSec

while ((Get-Date) -lt $deadline) {
    $ocr = Get-CursorPanelOcrText
    if (Test-CursorUpgradeHint $ocr) {
        $upgradeStreak++
        if (-not $sawBusy -and $upgradeStreak -ge 2 -and -not $switched) {
            if (Invoke-CursorAccountSwitchAndRefocus -Task $task) {
                $switched = $true
                $upgradeStreak = 0
                $stable = 0
                $lastHash = ""
                $sawBusy = $false
                Start-Sleep -Seconds $MinWaitSec
                continue
            }
            Write-Fail "cursor_upgrade_blocked"
        }
        if (-not $sawBusy -and $upgradeStreak -ge 6) {
            Write-Fail "cursor_upgrade_blocked"
        }
        Write-Host "WECHAT_PROGRESS: Cursor quota banner still visible"
        Start-Sleep -Seconds $PollSec
        continue
    }
    $upgradeStreak = 0

    if (Test-CursorAgentBusy $ocr) {
        $sawBusy = $true
        $stable = 0
        $lastHash = ""
        Write-Host "WECHAT_PROGRESS: Cursor still working"
        Start-Sleep -Seconds $PollSec
        continue
    }

    if (-not $sawBusy) {
        Write-Host "WECHAT_PROGRESS: waiting for Cursor agent to start"
        Start-Sleep -Seconds $PollSec
        continue
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

    Write-Host "WECHAT_PROGRESS: waiting ($stable/$StablePolls)"
    Start-Sleep -Seconds $PollSec
}

$final = Get-ResultSnippet (Get-CursorPanelOcrText) 160
if (Test-CursorUpgradeHint $final) {
    Write-Fail "cursor_upgrade_blocked"
}
if (-not $sawBusy) {
    Write-Fail "cursor_upgrade_blocked"
}
if ($final.Length -lt 8) {
    Write-Fail "cursor_timeout"
}
Write-Host "WECHAT_USER_REPLY: Cursor 超时；屏幕摘要：$final"
Write-Host "WECHAT_OK: cursor_task_timeout_partial"
exit 0
