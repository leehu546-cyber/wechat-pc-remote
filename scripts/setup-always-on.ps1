# Configure PC for 24/7 WeChat local chat bridge
# Run as Administrator for full effect (lid/network settings)

$ErrorActionPreference = "Continue"
$projectRoot = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "=== WeChat Bridge Always-On Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Power: never sleep on AC ---
Write-Host "[1/4] Power settings..." -ForegroundColor Yellow
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 30
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
# DC: allow sleep on battery to save power
powercfg /change standby-timeout-dc 60
powercfg /change monitor-timeout-dc 10
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
# Lid: do nothing on AC, sleep on battery
powercfg -SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg -SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
powercfg -SETACTIVE SCHEME_CURRENT
Write-Host "      AC: never sleep | Lid closed on AC: stay awake" -ForegroundColor Green

# --- 2. Network adapter: disable power saving ---
Write-Host "[2/4] Network adapter power saving..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | ForEach-Object {
        Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
    }
    Write-Host "      Network adapters: wake disabled power-off" -ForegroundColor Green
} else {
    Write-Host "      Skip (need Admin). Right-click -> Run as administrator" -ForegroundColor DarkYellow
}

# --- 3. Scheduled task: auto-start bridge on login ---
Write-Host "[3/4] Auto-start bridge on login..." -ForegroundColor Yellow
$taskName = "WeChatLocalChatBridge"
$bgScript = Join-Path $PSScriptRoot "start-wechat-local-chat-background.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$bgScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "      Task: $taskName" -ForegroundColor Green

# --- 4. Ollama: ensure runs at login (if installed) ---
Write-Host "[4/4] Ollama startup..." -ForegroundColor Yellow
$ollamaFromProcess = Get-Process -Name "ollama app" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Path
$ollamaCandidates = @(
    $ollamaFromProcess,
    "$env:LOCALAPPDATA\Programs\Ollama\Ollama.exe",
    "$env:LOCALAPPDATA\Programs\Ollama\ollama app.exe",
    "F:\ollama\ollama app.exe",
    (Get-Command ollama -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($ollamaCandidates) {
    $ollamaExe = $ollamaCandidates
    $ollamaShortcut = [Environment]::GetFolderPath("Startup") + "\Ollama.lnk"
    if (-not (Test-Path $ollamaShortcut)) {
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($ollamaShortcut)
        $lnk.TargetPath = $ollamaExe
        $lnk.Save()
        Write-Host "      Added Ollama to Startup folder" -ForegroundColor Green
    } else {
        Write-Host "      Ollama already in Startup" -ForegroundColor Green
    }
} else {
    Write-Host "      Ollama not found at default path - keep Ollama app running manually" -ForegroundColor DarkYellow
}

# Start bridge now in background
Write-Host ""
Write-Host "Starting bridge in background..." -ForegroundColor Yellow
& $bgScript
Start-Sleep -Seconds 2
& (Join-Path $PSScriptRoot "status.ps1")

Write-Host "Done. Tips:" -ForegroundColor Cyan
Write-Host "  - Keep PC plugged in for 24/7 use"
Write-Host "  - Log: $env:USERPROFILE\.wechat-local-chat\logs\bridge.log"
Write-Host "  - Remove task: Unregister-ScheduledTask -TaskName $taskName -Confirm:`$false"
Write-Host ""
