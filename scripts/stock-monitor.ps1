param(
    [string]$Code = "510300",
    [double]$CostPrice = 4.92,
    [double]$StopLoss = 0,
    [double]$TakeProfit = 0,
    [int]$Shares = 100,
    [switch]$Loop,
    [int]$Interval = 60
)

$secid = "1.$Code"
$baseUrl = "https://push2.eastmoney.com/api/qt/stock/get"

if ($StopLoss -eq 0) { $StopLoss = $CostPrice * 0.95 }
if ($TakeProfit -eq 0) { $TakeProfit = $CostPrice * 1.05 }

function Get-Quote {
    try {
        $url = "$baseUrl`?secid=$secid&fields=f43,f44,f45,f46,f47,f48,f60,f169,f170,f161"
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

        $profitLoss = [math]::Round(($price - $CostPrice) * $Shares, 2)
        $profitLossPct = [math]::Round(($price - $CostPrice) / $CostPrice * 100, 2)

        return [PSCustomObject]@{
            Price       = $price
            Change      = $change
            ChangePct   = $changePct
            High        = $high
            Low         = $low
            PreClose    = $preClose
            Volume      = $volume
            Amount      = $amount
            PL          = $profitLoss
            PLPct       = $profitLossPct
            Time        = Get-Date -Format "HH:mm:ss"
        }
    } catch {
        return $null
    }
}

function Show-Alert {
    param([string]$Msg)
    $title = "股票预警 - $Code"
    $null = [System.Windows.Forms.MessageBox]::Show($Msg, $title, 'OK', 'Warning')
    Write-Host "`n⚠ $Msg" -ForegroundColor Red
}

# Load WinForms for popup
Add-Type -AssemblyName System.Windows.Forms

do {
    $q = Get-Quote
    if ($q) {
        $color = if ($q.Change -ge 0) { "Green" } else { "Red" }
        Write-Host "`n[$($q.Time)] $Code 沪深300ETF" -ForegroundColor Cyan
        Write-Host "现价: $($q.Price) 涨跌: $($q.Change) ($($q.ChangePct)%)" -ForegroundColor $color
        Write-Host "最高: $($q.High)  最低: $($q.Low)  昨收: $($q.PreClose)"
        Write-Host "成交量: $($q.Volume)  成交额: $($q.Amount)亿"
        Write-Host "盈亏: $($q.PL)元 ($($q.PLPct)%)  成本: $CostPrice x ${Shares}股" -ForegroundColor $(if ($q.PL -ge 0) { "Green" } else { "Red" })

        if ($q.Price -le $StopLoss) {
            Show-Alert "🚨 止损触发！当前价 $($q.Price) ≤ 止损价 $StopLoss`n亏损 $($q.PL)元 ($($q.PLPct)%)"
        } elseif ($q.Price -ge $TakeProfit) {
            Show-Alert "✅ 止盈触发！当前价 $($q.Price) ≥ 止盈价 $TakeProfit`n盈利 $($q.PL)元 ($($q.PLPct)%)"
        }

        if (-not $Loop) { break }
        Write-Host "--- ${Interval}秒后刷新 ---" -ForegroundColor DarkGray
        Start-Sleep -Seconds $Interval
    } else {
        Write-Host "获取数据失败，重试中..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
} while ($Loop)
