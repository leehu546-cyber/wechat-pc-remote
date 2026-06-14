# Test unlock methods (safe: does not print password). Run on LOCKED screen for real PIN test.
param(
    [switch]$Quiet,
    [switch]$LockScreenMode
)

$ErrorActionPreference = "Continue"
$logPath = Join-Path $env:USERPROFILE ".weclaw\unlock-method-test.log"
$results = @()

function Write-TestLog {
    param([string]$Line)
    $ts = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    $entry = "$ts $Line"
    Add-Content -Path $logPath -Value $entry -Encoding UTF8
    if (-not $Quiet) { Write-Host $entry }
}

function Test-SchtasksSendKeys {
    param(
        [string]$Name,
        [string]$RunAs  # USER or SYSTEM
    )
    $taskName = "UnlockTest_${Name}_$(Get-Random)"
    $helper = Join-Path $PSScriptRoot "unlock-sendkeys.ps1"
    if (-not (Test-Path $helper)) {
        return @{ ok = $false; detail = "unlock-sendkeys.ps1 missing" }
    }
    $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helper`""

    $st = (Get-Date).AddMinutes(1).ToString("HH:mm")
    $sd = Get-Date -Format "yyyy/MM/dd"
    $createArgs = @(
        "/create", "/tn", $taskName,
        "/tr", $tr,
        "/sc", "once", "/st", $st, "/sd", $sd,
        "/rl", "HIGHEST", "/f"
    )
    if ($RunAs -eq "USER") {
        $createArgs += @("/ru", "$env:USERDOMAIN\$env:USERNAME")
    } else {
        $createArgs += @("/ru", "SYSTEM")
    }

    $createOut = & schtasks.exe @createArgs 2>&1 | Out-String
    $level = "HIGHEST"
    if ($LASTEXITCODE -ne 0 -and $createOut -match 'Access is denied' -and $RunAs -eq "USER") {
        $createArgs = $createArgs | Where-Object { $_ -ne "HIGHEST" -and $_ -ne "/rl" }
        $createOut = & schtasks.exe @createArgs 2>&1 | Out-String
        $level = "LIMITED"
    }
    if ($LASTEXITCODE -ne 0) {
        return @{ ok = $false; detail = "create failed: $createOut".Trim() }
    }

    $runOut = & schtasks.exe /run /tn $taskName 2>&1 | Out-String
    Start-Sleep -Seconds 6
    $null = & schtasks.exe /delete /tn $taskName /f 2>&1

    $debugLogs = Get-ChildItem -Path $env:TEMP -Filter "unlock_debug_*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $debugHint = if ($debugLogs) { " debug=$($debugLogs.FullName)" } else { "" }

    if ($runOut -match 'SUCCESS|成功') {
        return @{ ok = $true; detail = "schtasks run ok ($RunAs $level PIN SendKeys)$debugHint" }
    }
    return @{ ok = $false; detail = "run: $runOut".Trim() }
}

function Test-DirectSendKeys {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        return @{ ok = $true; detail = "direct SendKeys executed (MEDIUM integrity)" }
    } catch {
        return @{ ok = $false; detail = $_.Exception.Message }
    }
}

function Test-WinlogonDesktop {
    $code = @'
using System;
using System.Runtime.InteropServices;
public static class DeskTest {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr OpenDesktop(string name, uint flags, bool inherit, uint access);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool CloseDesktop(IntPtr h);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetThreadDesktop(IntPtr h);
    public const uint ALL = 0x000F01FF;
    public static string Probe() {
        var h = OpenDesktop("Winlogon", 0, false, ALL);
        if (h == IntPtr.Zero) return "OpenDesktop fail err=" + Marshal.GetLastWin32Error();
        bool set = SetThreadDesktop(h);
        int err = Marshal.GetLastWin32Error();
        CloseDesktop(h);
        if (!set) return "SetThreadDesktop fail err=" + err;
        return "Winlogon desktop attach ok";
    }
}
'@
    try {
        Add-Type -TypeDefinition $code -ErrorAction Stop
        $msg = [DeskTest]::Probe()
        $ok = $msg -match 'attach ok'
        return @{ ok = $ok; detail = $msg }
    } catch {
        return @{ ok = $false; detail = $_.Exception.Message }
    }
}

function Test-HodorPipe {
    $pipeScript = Join-Path $PSScriptRoot "unlock-via-pipe.ps1"
    if (-not (Test-Path $pipeScript)) {
        return @{ ok = $false; detail = "unlock-via-pipe.ps1 missing" }
    }
    try {
        $client = New-Object System.IO.Pipes.NamedPipeClientStream(
            ".", "CredentialProviderPipe",
            [System.IO.Pipes.PipeDirection]::InOut
        )
        $client.Connect(500)
        $client.Close()
        return @{ ok = $true; detail = "CredentialProviderPipe reachable (hodor installed)" }
    } catch {
        return @{ ok = $false; detail = "pipe not available: $($_.Exception.Message)" }
    }
}

function Test-UnlockVerify {
    $verifyScript = Join-Path $PSScriptRoot "unlock-verify.ps1"
    if (-not (Test-Path $verifyScript)) {
        return @{ ok = $false; detail = "unlock-verify.ps1 missing" }
    }
    $out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifyScript 2>&1 | Out-String).Trim()
    $ok = $out -match 'WECHAT_OK'
    return @{ ok = $ok; detail = $out }
}

function Test-FullUnlockScript {
    $main = Join-Path $PSScriptRoot "unlock-screen.ps1"
    if (-not (Test-Path $main)) {
        return @{ ok = $false; detail = "unlock-screen.ps1 missing" }
    }
    if (-not $LockScreenMode) {
        return @{ ok = $false; detail = "skip full script (use -LockScreenMode on locked PC)" }
    }
    $out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $main 2>&1 | Out-String).Trim()
    $ok = $out -match 'WECHAT_OK'
    $screenLogs = Get-ChildItem -Path $env:TEMP -Filter "unlock_screen_*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $hint = if ($screenLogs) { " log=$($screenLogs.FullName)" } else { "" }
    return @{ ok = $ok; detail = "$out$hint" }
}

# --- run tests ---
"" | Set-Content -Path $logPath -Encoding UTF8
Write-TestLog "=== unlock method test (PIN matrix) ==="
if ($LockScreenMode) {
    Write-TestLog "LOCK SCREEN MODE: full unlock-screen.ps1 will run"
} else {
    Write-TestLog "Desktop mode: mechanics only; lock PC and re-run with -LockScreenMode for E2E"
}

$r1 = Test-DirectSendKeys
$results += [PSCustomObject]@{ Method = "A_direct_SendKeys"; Ok = $r1.ok; Detail = $r1.detail }
Write-TestLog "A direct SendKeys: $($r1.ok) | $($r1.detail)"

$r2 = Test-SchtasksSendKeys -Name "UserHighest" -RunAs "USER"
$results += [PSCustomObject]@{ Method = "B_schtasks_USER_PIN"; Ok = $r2.ok; Detail = $r2.detail }
Write-TestLog "B schtasks USER PIN: $($r2.ok) | $($r2.detail)"

$r3 = Test-SchtasksSendKeys -Name "SystemHighest" -RunAs "SYSTEM"
$results += [PSCustomObject]@{ Method = "C_schtasks_SYSTEM"; Ok = $r3.ok; Detail = $r3.detail }
Write-TestLog "C schtasks SYSTEM: $($r3.ok) | $($r3.detail)"

$r4 = Test-WinlogonDesktop
$results += [PSCustomObject]@{ Method = "D_winlogon_desktop_USER"; Ok = $r4.ok; Detail = $r4.detail }
Write-TestLog "D Winlogon desktop (user proc): $($r4.ok) | $($r4.detail)"

$r5 = Test-HodorPipe
$results += [PSCustomObject]@{ Method = "E_hodor_pipe"; Ok = $r5.ok; Detail = $r5.detail }
Write-TestLog "E hodor pipe: $($r5.ok) | $($r5.detail)"

$r6 = Test-UnlockVerify
$results += [PSCustomObject]@{ Method = "F_unlock_verify"; Ok = $r6.ok; Detail = $r6.detail }
Write-TestLog "F unlock-verify (desktop=unlocked expected): $($r6.ok) | $($r6.detail)"

$r7 = Test-FullUnlockScript
$results += [PSCustomObject]@{ Method = "G_full_unlock_screen"; Ok = $r7.ok; Detail = $r7.detail }
Write-TestLog "G full unlock-screen.ps1: $($r7.ok) | $($r7.detail)"

# B or E = canonical; C/D fail on lock screen in practice
$winner = $results | Where-Object { $_.Ok -and $_.Method -eq "E_hodor_pipe" } | Select-Object -First 1
if (-not $winner) {
    $winner = $results | Where-Object { $_.Ok -and $_.Method -eq "B_schtasks_USER_PIN" } | Select-Object -First 1
}
if (-not $winner) {
    $winner = $results | Where-Object { $_.Ok -and $_.Method -ne "C_schtasks_SYSTEM" } | Select-Object -First 1
}

if ($winner) {
    Write-TestLog "RECOMMENDED: $($winner.Method)"
    Write-Host "RECOMMENDED: $($winner.Method)" -ForegroundColor Green
} else {
    Write-TestLog "RECOMMENDED: none passed"
    Write-Host "RECOMMENDED: none passed" -ForegroundColor Red
}

Write-TestLog "Lock-screen checklist: (1) PIN dots appear (2) desktop within 10s (3) WECHAT_OK verified (4) check %TEMP%\unlock_debug_*.log"
$results | Format-Table -AutoSize
