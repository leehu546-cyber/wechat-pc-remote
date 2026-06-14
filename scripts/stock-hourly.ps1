param(
    [string]$Code = "510300",
    [double]$CostPrice = 4.92,
    [int]$Shares = 100
)

$secid = "1.$Code"
$url = "https://push2.eastmoney.com/api/qt/stock/get?secid=$secid&fields=f43,f44,f45,f46,f47,f48,f60,f169,f170"

$logDir = "$env:USERPROFILE\.stock-logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

try {
    $resp = Invoke-RestMethod -Uri $url -TimeoutSec 10
    $d = $resp.data
    $price = [math]::Round($d.f43 / 1000, 3)
    $change = [math]::Round($d.f169 / 1000, 3)
    $changePct = [math]::Round($d.f170 / 100, 2)
    $high = [math]::Round($d.f44 / 1000, 3)
    $low = [math]::Round($d.f45 / 1000, 3)
    $preClose = [math]::Round($d.f60 / 1000, 3)
    $volume = $d.f47
    $amount = [math]::Round($d.f48 / 1e8, 2)
    $pl = [math]::Round(($price - $CostPrice) * $Shares, 2)
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $logLine = "$now | 现价:$price | 涨跌:$change($changePct%) | 最高:$high | 最低:$low | 昨收:$preClose | 成交量:$volume | 成交额:${amount}亿 | 盈亏:$pl"
    $logLine | Out-File -FilePath "$logDir\$Code.log" -Encoding utf8 -Append

    $msg = "510300 沪深300ETF`n时间: $now`n现价: $price  涨跌: $change ($changePct%)`n最高: $high  最低: $low`n持仓盈亏: $pl 元"

    Add-Type -AssemblyName System.Windows.Forms
    $null = [System.Windows.Forms.MessageBox]::Show($msg, "股票定时提醒 - $Code", 'OK', 'Information')

    Write-Host $logLine
} catch {
    $err = "获取数据失败: $_"
    $err | Out-File -FilePath "$logDir\$Code.log" -Encoding utf8 -Append
    Write-Host $err -ForegroundColor Red
}
