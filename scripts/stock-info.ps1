# Fetch portfolio quote + 5-day kline; output WECHAT_DATA for Agent analysis.
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$configPath = Join-Path $env:USERPROFILE ".weclaw\stock-portfolio.json"
if (-not (Test-Path $configPath)) {
    Write-Host "WECHAT_FAIL: 未配置持仓，请运行 scripts/setup-stock-portfolio.ps1"
    exit 1
}

$cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$code = [string]$cfg.code
$name = [string]$cfg.name
$cost = [double]$cfg.cost
$shares = [int]$cfg.shares
$stopPct = if ($cfg.stop_loss_pct) { [double]$cfg.stop_loss_pct } else { 5.0 }
$takePct = if ($cfg.take_profit_pct) { [double]$cfg.take_profit_pct } else { 5.0 }

$fetchedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$sourcesScript = Join-Path $PSScriptRoot "stock-quote-sources.ps1"
if (-not (Test-Path $sourcesScript)) {
    Write-Host "WECHAT_FAIL: 缺少 stock-quote-sources.ps1"
    exit 1
}
. $sourcesScript

$secid = Get-StockSecId $code

try {
    $merged = Get-StockQuoteMerged -Code $code -TimeoutSec 10
    $price = [double]$merged.Price
    $changePct = [double]$merged.ChangePct
    $high = [double]$merged.High
    $low = [double]$merged.Low
    $preClose = [double]$merged.PreClose
    $change = [math]::Round($price - $preClose, 3)
    $primarySource = [string]$merged.PrimarySource
    $sourceCount = [int]$merged.SourceCount
    $sourcesUsed = [string]$merged.Sources
    $quoteConsistent = [bool]$merged.Consistent
    if ($sourceCount -ge 2 -and $quoteConsistent) {
        $sourceLabel = "$sourceCount 源一致 ($sourcesUsed)"
    } elseif ($sourceCount -ge 2) {
        $spread = [math]::Round([double]$merged.SpreadPct, 2)
        $sourceLabel = "$sourceCount 源分歧 ${spread}% ($sourcesUsed)"
    } else {
        $sourceLabel = $primarySource
    }
} catch {
    Write-Host "WECHAT_FAIL: 无法获取行情 ($($_.Exception.Message))"
    exit 1
}

$volume = 0L
$amount = 0.0

$pl = [math]::Round(($price - $cost) * $shares, 2)
$plPct = if ($cost -ne 0) { [math]::Round(($price - $cost) / $cost * 100, 2) } else { 0 }
$stopLoss = [math]::Round($cost * (1 - $stopPct / 100), 3)
$takeProfit = [math]::Round($cost * (1 + $takePct / 100), 3)
$stopTriggered = $price -le $stopLoss
$takeTriggered = $price -ge $takeProfit
$amplitudePct = if ($preClose -ne 0) { [math]::Round(($high - $low) / $preClose * 100, 2) } else { 0 }

$k5Trend = "flat"
$k5ChangePct = 0.0
$k5High = $high
$k5Low = $low
$k5Closes = @()

try {
    $kUrl = "https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=$secid&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=101&fqt=1&end=20500101&lmt=6"
    $kResp = Invoke-RestMethod -Uri $kUrl -TimeoutSec 12
    $klines = @($kResp.data.klines)
    if ($klines.Count -ge 2) {
        $parsed = @()
        foreach ($line in $klines) {
            $parts = $line -split ','
            if ($parts.Count -ge 3) {
                $c = [double]$parts[2]
                $parsed += $c
            }
        }
        if ($parsed.Count -ge 2) {
            $k5Closes = $parsed
            $first = $parsed[0]
            $last = $parsed[$parsed.Count - 1]
            if ($first -ne 0) {
                $k5ChangePct = [math]::Round(($last - $first) / $first * 100, 2)
            }
            $k5High = ($parsed | Measure-Object -Maximum).Maximum
            $k5Low = ($parsed | Measure-Object -Minimum).Minimum
            if ($k5ChangePct -gt 0.5) { $k5Trend = "up" }
            elseif ($k5ChangePct -lt -0.5) { $k5Trend = "down" }
            else { $k5Trend = "flat" }
        }
    }
} catch {
    # kline optional; quote still valid
}

$volBandLow = [math]::Round([math]::Min($k5Low, $low) * 0.995, 3)
$volBandHigh = [math]::Round([math]::Max($k5High, $high) * 1.005, 3)

# Action label (script-side, avoid Agent rewriting)
if ($stopTriggered) {
    $actionLabel = "观望或减仓"
} elseif ($takeTriggered) {
    $actionLabel = "可考虑部分止盈"
} elseif ($plPct -lt -3 -and $k5Trend -eq "down") {
    $actionLabel = "观望"
} elseif ($plPct -gt 3 -and $k5Trend -eq "up") {
    $actionLabel = "持有"
} else {
    $actionLabel = "持有"
}

$changeSign = if ($changePct -ge 0) { "+" } else { "" }
$plSign = if ($pl -ge 0) { "+" } else { "" }
$riskStatus = if ($stopTriggered -and $takeTriggered) {
    "止损/止盈均已触发"
} elseif ($stopTriggered) {
    "止损已触发"
} elseif ($takeTriggered) {
    "止盈已触发"
} else {
    "止损/止盈均未触发"
}

# Machine-readable block (diagnostics)
Write-Host "WECHAT_DATA: stock_snapshot"
Write-Host "code=$code"
Write-Host "name=$name"
Write-Host "fetched_at=$fetchedAt"
Write-Host "price=$price"
Write-Host "change_pct=$changePct"
Write-Host "pl=$pl"
Write-Host "pl_pct=$plPct"
Write-Host "action_label=$actionLabel"
Write-Host "stop_triggered=$stopTriggered"
Write-Host "take_triggered=$takeTriggered"
Write-Host "k5_trend=$k5Trend"
Write-Host "k5_change_pct=$k5ChangePct"
Write-Host "source=$primarySource"
Write-Host "quote_sources=$sourcesUsed"
Write-Host "quote_source_count=$sourceCount"
Write-Host "quote_consistent=$quoteConsistent"
Write-Host "quote_source_label=$sourceLabel"

# WeChat card (compact lines — user-visible)
Write-Host ""
Write-Host "WECHAT_STOCK_CARD:"
Write-Host "$code $name"
Write-Host ('现价 {0} ({1}{2}%)  盈亏 {3}{4}元 ({3}{5}%)' -f $price, $changeSign, $changePct, $plSign, $pl, $plPct)
Write-Host "建议 $actionLabel  风控 $riskStatus"
Write-Host "来源 $sourceLabel"
Write-Host "抓取 $fetchedAt"
