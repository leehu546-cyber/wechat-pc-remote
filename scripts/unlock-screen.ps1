# unlock-screen.ps1 - wake display + unlock Windows lock screen (canonical, do not edit in chat)
# Verified: optional hodor pipe, else schtasks current USER + unlock-sendkeys.ps1 (HIGHEST, else LIMITED).
# Reports WECHAT_OK only after unlock-verify.ps1 passes.
param()

$ErrorActionPreference = "Continue"

$debugLog = Join-Path $env:TEMP ("unlock_screen_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
function Log-Unlock {
    param([string]$Msg)
    $line = "$(Get-Date -Format 'HH:mm:ss.fff') $Msg"
    Add-Content -Path $debugLog -Value $line -Encoding UTF8
}

$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
if (-not (Test-Path $configPath)) {
    Write-Host "WECHAT_FAIL: 未配置密码，请运行 scripts/setup-unlock-screen.ps1"
    Write-Host "WECHAT_USER_REPLY: 解锁失败：未配置密码，请运行 setup-unlock-screen.ps1。"
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

$method = "none"
$attemptOk = $false

# --- optional hodor Credential Provider pipe (preferred when installed) ---
$pipeScript = Join-Path $PSScriptRoot "unlock-via-pipe.ps1"
if (Test-Path $pipeScript) {
    $pipeOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pipeScript 2>&1 | Out-String).Trim()
    Log-Unlock "pipe: $pipeOut"
    if ($pipeOut -match 'PIPE_OK') {
        $method = "pipe"
        $attemptOk = $true
    }
}

# --- fallback: schtasks current USER + PIN SendKeys helper ---
if (-not $attemptOk) {
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
        param([string]$Level)
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
            Log-Unlock "schtasks create fail: $($created.out)"
            Write-Host "WECHAT_FAIL: schtasks create: $($created.out)"
            exit 1
        }

        $run = (& schtasks.exe /run /tn $taskName 2>&1 | Out-String).Trim()
        Log-Unlock "schtasks run ($level): $run"
        Start-Sleep -Seconds 8
        $null = & schtasks.exe /delete /tn $taskName /f 2>&1

        if ($run -match 'SUCCESS|成功') {
            $method = "sendkeys_$level"
            $attemptOk = $true
        } else {
            Write-Host "WECHAT_FAIL: schtasks run: $run"
            exit 1
        }
    }
    catch {
        Log-Unlock "exception: $($_.Exception.Message)"
        Write-Host "WECHAT_FAIL: $($_.Exception.Message)"
        exit 1
    }
}

# --- verify: do not trust schtasks/pipe alone ---
$verifyScript = Join-Path $PSScriptRoot "unlock-verify.ps1"
if (-not (Test-Path $verifyScript)) {
    Write-Host "WECHAT_FAIL: unlock-verify.ps1 missing"
    exit 1
}

$verifyOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifyScript 2>&1 | Out-String).Trim()
Log-Unlock "verify: $verifyOut debugLog=$debugLog"

if ($verifyOut -match 'WECHAT_OK') {
    Write-Host "WECHAT_OK: unlocked verified ($method)"
    Write-Host "WECHAT_USER_REPLY: 已解锁，请看屏幕。"
    exit 0
}

Write-Host "WECHAT_FAIL: PIN not accepted"
Write-Host "WECHAT_USER_REPLY: 解锁失败：密码未通过。"
exit 1
