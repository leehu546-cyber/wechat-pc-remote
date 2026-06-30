# windows-use-task.ps1 — GUI step worker for WeClaw planner (vision + action)
param(
    [Parameter(Mandatory = $true)]
    [string]$Goal
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$python = Join-Path $root ".venv-windows-use\Scripts\python.exe"
$runner = Join-Path $root "scripts\run-windows-use-task.py"

if (-not (Test-Path -LiteralPath $python)) {
    Write-Host "WECHAT_FAIL: windows-use venv missing"
    Write-Host "WECHAT_USER_REPLY: 没做成：Windows-Use 未安装。"
    exit 1
}

$env:WECLAW_GUI_TASK = $Goal
& $python $runner $Goal
exit $LASTEXITCODE
