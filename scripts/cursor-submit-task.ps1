param(
    [Parameter(Mandatory = $true)]
    [string]$Task
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "cursor-common.ps1")

$wakeScript = Join-Path $PSScriptRoot "wake-screen.ps1"
if (Test-Path -LiteralPath $wakeScript) {
    & $wakeScript | Out-Null
    Start-Sleep -Milliseconds 400
}

if (-not (Submit-CursorTaskWithQuotaRetry -Task $Task)) {
    exit 1
}
exit 0
