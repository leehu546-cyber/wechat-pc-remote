# close-screen.ps1 - alias for turn-off-screen.ps1 (single canonical关屏入口)
# Kept for backward compatibility; delegates to the Agent-safe implementation.
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$canonical = Join-Path $scriptDir "turn-off-screen.ps1"
if (-not (Test-Path $canonical)) {
    Write-Host "WECHAT_FAIL: turn-off-screen.ps1 not found"
    exit 1
}
& $canonical @args
exit $LASTEXITCODE
