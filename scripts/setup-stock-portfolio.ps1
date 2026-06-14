# One-time: create ~/.weclaw/stock-portfolio.json for wechat-stock-info skill
param(
    [string]$Code = "510300",
    [string]$Name = "沪深300ETF",
    [double]$Cost = 4.92,
    [int]$Shares = 100,
    [double]$StopLossPct = 5,
    [double]$TakeProfitPct = 5
)

$configPath = Join-Path $env:USERPROFILE ".weclaw\stock-portfolio.json"
$dir = Split-Path $configPath -Parent
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$obj = @{
    code            = $Code
    name            = $Name
    cost            = $Cost
    shares          = $Shares
    stop_loss_pct   = $StopLossPct
    take_profit_pct = $TakeProfitPct
}
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($configPath, ($obj | ConvertTo-Json), $utf8Bom)

Write-Host "[ok] Saved to $configPath (not in git)" -ForegroundColor Green
Write-Host "Test: powershell -File scripts\stock-info.ps1" -ForegroundColor Cyan
