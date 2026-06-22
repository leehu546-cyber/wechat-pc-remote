# Ensure OpenCode uses paid DeepSeek API (not opencode/*-free Zen cloud)
$ErrorActionPreference = "Stop"

Write-Host "=== OpenCode + DeepSeek paid API setup ===" -ForegroundColor Cyan

$authPath = Join-Path $env:USERPROFILE ".local\share\opencode\auth.json"
if (Test-Path $authPath) {
    Write-Host "[ok] OpenCode auth already exists: $authPath" -ForegroundColor Green
    Write-Host "If models fail with 401/429 on opencode/*-free, ensure opencode.json model is deepseek/deepseek-v4-flash" -ForegroundColor DarkGray
} else {
    Write-Host "OpenCode auth not found. Run interactive login:" -ForegroundColor Yellow
    Write-Host "  opencode auth login" -ForegroundColor White
    Write-Host "Select DeepSeek provider and paste your platform.deepseek.com API key." -ForegroundColor DarkGray
}

$projectOpencode = Join-Path (Split-Path $PSScriptRoot -Parent) "opencode.json"
if (Test-Path $projectOpencode) {
    $j = Get-Content $projectOpencode -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($j.model -ne "deepseek/deepseek-v4-flash") {
        $j.model = "deepseek/deepseek-v4-flash"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($projectOpencode, ($j | ConvertTo-Json -Depth 5), $utf8NoBom)
        Write-Host "[ok] Set project opencode.json model -> deepseek/deepseek-v4-flash" -ForegroundColor Green
    } else {
        Write-Host "[ok] project opencode.json model = deepseek/deepseek-v4-flash" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Then run:" -ForegroundColor Cyan
Write-Host "  scripts\init-weclaw-opencode.ps1"
Write-Host "  scripts\restart-weclaw.ps1"
