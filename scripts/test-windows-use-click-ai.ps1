# Run Windows-Use one-shot test: click Cursor AI chat input.
$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root ".venv-windows-use\Scripts\python.exe"
$setup = Join-Path $PSScriptRoot "setup-windows-use-deepseek.ps1"
$testPy = Join-Path $PSScriptRoot "test-windows-use-click-ai.py"

if (-not (Test-Path -LiteralPath $python)) {
    Write-Host "WECHAT_FAIL: .venv-windows-use missing"
    exit 1
}

& $setup
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$env:ANONYMIZED_TELEMETRY = "false"
& $python $testPy
exit $LASTEXITCODE
