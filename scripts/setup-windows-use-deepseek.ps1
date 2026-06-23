# Configure Windows-Use CLI with DeepSeek (OpenCode auth or DEEPSEEK_API_KEY).
$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root ".venv-windows-use\Scripts\python.exe"
$setupPy = Join-Path $PSScriptRoot "setup-windows-use-deepseek.py"

if (-not (Test-Path -LiteralPath $python)) {
    Write-Host "WECHAT_FAIL: .venv-windows-use missing. Install windows-use first."
    exit 1
}

& $python $setupPy
exit $LASTEXITCODE
