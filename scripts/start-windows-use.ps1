# start-windows-use.ps1 — launch Windows-Use CLI from project venv
$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$venvPython = Join-Path $root ".venv-windows-use\Scripts\python.exe"
$cli = Join-Path $root ".venv-windows-use\Scripts\windows-use.exe"

if (-not (Test-Path -LiteralPath $cli)) {
    Write-Host "WECHAT_FAIL: windows-use not installed. Run: uv pip install --python .venv-windows-use\Scripts\python.exe windows-use==0.8.1 mistralai==1.9.11"
    exit 1
}

# Optional: disable telemetry
if (-not $env:ANONYMIZED_TELEMETRY) {
    $env:ANONYMIZED_TELEMETRY = "false"
}

Write-Host "Windows-Use CLI (.venv-windows-use)"
Write-Host "DeepSeek example: set DEEPSEEK_API_KEY then run with -p deepseek -m deepseek-chat"
Write-Host ""

& $cli @args
