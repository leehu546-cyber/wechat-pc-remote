# Desktop shortcut: one-click wake display
$ErrorActionPreference = "Stop"

$scriptsRoot = $PSScriptRoot
$bat = Join-Path $scriptsRoot "wake-now.bat"
if (-not (Test-Path $bat)) {
    Write-Error "Missing: $bat"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$lnkPath = Join-Path $desktop "WakeScreen.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($lnkPath)
$shortcut.TargetPath = $bat
$shortcut.WorkingDirectory = $scriptsRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "One-click wake display"
$shortcut.Save()

# Chinese name copy for user preference
$lnkCn = Join-Path $desktop ([char]0x4E00 + [char]0x952E + [char]0x4EAE + [char]0x5C4F + ".lnk")
if ($lnkCn -ne $lnkPath) {
    Copy-Item -LiteralPath $lnkPath -Destination $lnkCn -Force
}

Write-Host "Shortcuts on desktop:" -ForegroundColor Green
Write-Host "  $lnkPath"
if (Test-Path -LiteralPath $lnkCn) { Write-Host "  $lnkCn" }
Write-Host "Double-click or right-click -> Pin to taskbar" -ForegroundColor Cyan
