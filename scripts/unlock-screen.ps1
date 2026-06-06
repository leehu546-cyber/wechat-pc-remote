# unlock-screen.ps1 - wake display + unlock Windows lock screen (canonical, do not edit in chat)
# Verified: schtasks current USER + unlock-sendkeys.ps1 (HIGHEST, else LIMITED). No RunAs/SYSTEM/SendInput.
param()

$ErrorActionPreference = "Continue"

$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
if (-not (Test-Path $configPath)) {
    Write-Host "WECHAT_FAIL: 未配置密码，请运行 scripts/setup-unlock-screen.ps1"
    exit 1
}

try {
    $pwd = [string](Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).password
} catch {
    Write-Host "WECHAT_FAIL: 无法读取 unlock-screen.json"
    exit 1
}

if (-not $pwd) {
    Write-Host "WECHAT_FAIL: password 为空"
    exit 1
}

$wakeScript = Join-Path $PSScriptRoot "wake-screen.ps1"
if (Test-Path $wakeScript) {
    & $wakeScript | Out-Null
    Start-Sleep -Seconds 2
}

$helper = Join-Path $PSScriptRoot "unlock-sendkeys.ps1"
if (-not (Test-Path $helper)) {
    Write-Host "WECHAT_FAIL: unlock-sendkeys.ps1 missing"
    exit 1
}

$taskName = "WeClawUnlock_$(Get-Random)"
$taskCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helper`""
$runAt = (Get-Date).AddMinutes(1).ToString("HH:mm")
$runDate = Get-Date -Format "yyyy/MM/dd"
$user = "$env:USERDOMAIN\$env:USERNAME"

function Invoke-UnlockTask {
    param([string]$Level)  # HIGHEST or LIMITED
    $args = @(
        "/create", "/tn", $taskName,
        "/tr", $taskCmd,
        "/sc", "once", "/st", $runAt, "/sd", $runDate,
        "/ru", $user, "/f"
    )
    if ($Level -eq "HIGHEST") { $args += @("/rl", "HIGHEST") }
    $out = & schtasks.exe @args 2>&1 | Out-String
    return @{ code = $LASTEXITCODE; out = $out.Trim() }
}

try {
    $created = Invoke-UnlockTask -Level "HIGHEST"
    $level = "HIGHEST"
    if ($created.code -ne 0 -and $created.out -match 'Access is denied') {
        $created = Invoke-UnlockTask -Level "LIMITED"
        $level = "LIMITED"
    }
    if ($created.code -ne 0) {
        Write-Host "WECHAT_FAIL: schtasks create: $($created.out)"
        exit 1
    }

    $run = (& schtasks.exe /run /tn $taskName 2>&1 | Out-String).Trim()
    Start-Sleep -Seconds 8
    $null = & schtasks.exe /delete /tn $taskName /f 2>&1

    if ($run -match 'SUCCESS|成功') {
        Write-Host "WECHAT_OK: unlock password sent ($level)"
    } else {
        Write-Host "WECHAT_FAIL: schtasks run: $run"
    }
}
catch {
    Write-Host "WECHAT_FAIL: $($_.Exception.Message)"
}
