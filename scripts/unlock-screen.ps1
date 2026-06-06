# unlock-screen.ps1 - wake display then type lock-screen password (Win11 lock UI)
# Password: %USERPROFILE%\.weclaw\unlock-screen.json (not in git)
param()

$ErrorActionPreference = "Continue"

$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
if (-not (Test-Path $configPath)) {
    $template = @{ password = "" } | ConvertTo-Json
    New-Item -ItemType Directory -Path (Split-Path $configPath) -Force | Out-Null
    Set-Content -Path $configPath -Value $template -Encoding UTF8
    Write-Host "WECHAT_FAIL: 未配置密码，请编辑 $configPath 填入 password 后重试"
    exit 1
}

try {
    $cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $password = [string]$cfg.password
} catch {
    Write-Host "WECHAT_FAIL: 无法读取 $configPath"
    exit 1
}

if (-not $password) {
    Write-Host "WECHAT_FAIL: unlock-screen.json 中 password 为空"
    exit 1
}

# Step 1: wake monitor (lock screen may be on black display)
$wakeScript = Join-Path $PSScriptRoot "wake-screen.ps1"
if (Test-Path $wakeScript) {
    & $wakeScript | Out-Null
    Start-Sleep -Seconds 1
}

# Step 2: SendKeys on lock screen needs HIGH integrity (UIPI blocks normal user process)
$taskName = "UnlockWorkstation_$(Get-Random)"
$escaped = $password -replace '([+^%~(){}\[\]])', '{$1}'
$scriptBlock = @"
    Start-Sleep -Seconds 2
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait('$escaped{ENTER}')
"@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptBlock))

try {
    $null = & schtasks.exe /create /tn $taskName `
        /tr "powershell.exe -NoProfile -WindowStyle Hidden -EncodedCommand $encoded" `
        /sc once /st 00:00 /ru "$env:USERDOMAIN\$env:USERNAME" /rl HIGHEST /f 2>&1

    $null = & schtasks.exe /run /tn $taskName 2>&1
    Start-Sleep -Seconds 6
    $null = & schtasks.exe /delete /tn $taskName /f 2>&1

    Write-Host "WECHAT_OK: unlock password sent"
}
catch {
    Write-Host "WECHAT_FAIL: $($_.Exception.Message)"
}
