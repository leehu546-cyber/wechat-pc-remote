# Multi-source A-share/ETF quote fetchers for stock-info.ps1
# Providers: East Money push2, Sina hq.sinajs.cn, Tencent qt.gtimg.cn

. (Join-Path $PSScriptRoot "utf8-console.ps1")
function Get-StockMarketPrefix {
    param([string]$Code)
    $c = $Code.Trim()
    if ($c.StartsWith('6') -or $c.StartsWith('5') -or $c.StartsWith('9')) { return 'sh' }
    return 'sz'
}

function Get-StockSecId {
    param([string]$Code)
    $prefix = Get-StockMarketPrefix $Code
    if ($prefix -eq 'sh') { return "1.$Code" }
    return "0.$Code"
}

function New-StockQuoteResult {
    param(
        [string]$Source,
        [double]$Price,
        [double]$PreClose,
        [double]$High,
        [double]$Low,
        [double]$ChangePct,
        [string]$Name = ''
    )
    return [PSCustomObject]@{
        Source    = $Source
        Price     = [math]::Round($Price, 3)
        PreClose  = [math]::Round($PreClose, 3)
        High      = [math]::Round($High, 3)
        Low       = [math]::Round($Low, 3)
        ChangePct = [math]::Round($ChangePct, 2)
        Name      = $Name
    }
}

function Get-StockQuoteEastMoney {
    param([string]$SecId, [int]$TimeoutSec = 10)
    $url = "https://push2.eastmoney.com/api/qt/stock/get?secid=$SecId&fields=f43,f44,f45,f60,f169,f170"
    $resp = Invoke-RestMethod -Uri $url -TimeoutSec $TimeoutSec
    $d = $resp.data
    if (-not $d -or -not $d.f43) { throw 'empty eastmoney data' }
    $price = [double]$d.f43 / 1000
    $preClose = [double]$d.f60 / 1000
    $high = [double]$d.f44 / 1000
    $low = [double]$d.f45 / 1000
    $changePct = [double]$d.f170 / 100
    return New-StockQuoteResult -Source 'eastmoney' -Price $price -PreClose $preClose -High $high -Low $low -ChangePct $changePct
}

function Get-StockQuoteSina {
    param([string]$MarketPrefix, [string]$Code, [int]$TimeoutSec = 10)
    $symbol = "$MarketPrefix$Code"
    $url = "https://hq.sinajs.cn/list=$symbol"
    $resp = Invoke-WebRequest -Uri $url -TimeoutSec $TimeoutSec -Headers @{ Referer = 'https://finance.sina.com.cn' }
    $raw = [string]$resp.Content
    if ($raw -notmatch '="([^"]*)"') { throw 'invalid sina response' }
    $fields = $Matches[1] -split ','
    if ($fields.Count -lt 6 -or [string]::IsNullOrWhiteSpace($fields[3])) { throw 'empty sina quote' }
    $price = [double]$fields[3]
    $preClose = [double]$fields[2]
    $high = [double]$fields[4]
    $low = [double]$fields[5]
    if ($preClose -eq 0) { throw 'invalid sina pre_close' }
    $changePct = [math]::Round(($price - $preClose) / $preClose * 100, 2)
    return New-StockQuoteResult -Source 'sina' -Price $price -PreClose $preClose -High $high -Low $low -ChangePct $changePct -Name $fields[0]
}

function Get-StockQuoteTencent {
    param([string]$MarketPrefix, [string]$Code, [int]$TimeoutSec = 10)
    $symbol = "$MarketPrefix$Code"
    $url = "https://qt.gtimg.cn/q=$symbol"
    $resp = Invoke-WebRequest -Uri $url -TimeoutSec $TimeoutSec
    $raw = [string]$resp.Content
    if ($raw -notmatch '="([^"]*)"') { throw 'invalid tencent response' }
    $fields = $Matches[1] -split '~'
    if ($fields.Count -lt 35 -or [string]::IsNullOrWhiteSpace($fields[3])) { throw 'empty tencent quote' }
    $price = [double]$fields[3]
    $preClose = [double]$fields[4]
    $high = [double]$fields[33]
    $low = [double]$fields[34]
    if ($preClose -eq 0) { throw 'invalid tencent pre_close' }
    $changePct = [math]::Round(($price - $preClose) / $preClose * 100, 2)
    return New-StockQuoteResult -Source 'tencent' -Price $price -PreClose $preClose -High $high -Low $low -ChangePct $changePct -Name $fields[1]
}

function Get-StockQuotesParallel {
    param(
        [string]$Code,
        [int]$TimeoutSec = 10
    )

    $sourcesPath = Join-Path $PSScriptRoot 'stock-quote-sources.ps1'
    $market = Get-StockMarketPrefix $Code
    $secId = Get-StockSecId $Code
    $quoteList = @()
    $errorList = @()

    $pool = [runspacefactory]::CreateRunspacePool(1, 3)
    $pool.Open()
    $handles = @()

    $taskScript = @'
param($SourcePath, $Fetcher, $Arg1, $Arg2, $TimeoutSec)
. $SourcePath
switch ($Fetcher) {
    'eastmoney' { return Get-StockQuoteEastMoney -SecId $Arg1 -TimeoutSec $TimeoutSec }
    'sina'      { return Get-StockQuoteSina -MarketPrefix $Arg1 -Code $Arg2 -TimeoutSec $TimeoutSec }
    'tencent'   { return Get-StockQuoteTencent -MarketPrefix $Arg1 -Code $Arg2 -TimeoutSec $TimeoutSec }
}
'@

    $tasks = @(
        @{ Name = 'eastmoney'; Fetcher = 'eastmoney'; Arg1 = $secId; Arg2 = $Code },
        @{ Name = 'sina'; Fetcher = 'sina'; Arg1 = $market; Arg2 = $Code },
        @{ Name = 'tencent'; Fetcher = 'tencent'; Arg1 = $market; Arg2 = $Code }
    )

    try {
        foreach ($task in $tasks) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($taskScript).
                AddArgument($sourcesPath).
                AddArgument($task.Fetcher).
                AddArgument($task.Arg1).
                AddArgument($task.Arg2).
                AddArgument($TimeoutSec)
            $handles += [PSCustomObject]@{
                Name  = $task.Name
                PS    = $ps
                Async = $ps.BeginInvoke()
            }
        }

        $deadline = (Get-Date).AddSeconds($TimeoutSec + 3)
        foreach ($h in $handles) {
            $remainingMs = [math]::Max(100, ($deadline - (Get-Date)).TotalMilliseconds)
            while (-not $h.Async.IsCompleted) {
                if ((Get-Date) -ge $deadline) { break }
                Start-Sleep -Milliseconds 100
            }
            if (-not $h.Async.IsCompleted) {
                try { $h.PS.Stop() } catch { }
                $errorList += "$($h.Name): timeout"
                continue
            }
            try {
                $out = $h.PS.EndInvoke($h.Async)
                if ($out) { $quoteList += $out }
                else { $errorList += "$($h.Name): empty" }
            } catch {
                $errorList += "$($h.Name): $($_.Exception.Message)"
            }
        }
    } finally {
        foreach ($h in $handles) {
            if ($h.PS) { $h.PS.Dispose() }
        }
        $pool.Close()
        $pool.Dispose()
    }

    return [PSCustomObject]@{
        Quotes = $quoteList
        Errors = $errorList
    }
}

function Merge-StockQuotes {
    param(
        [object[]]$Quotes,
        [double]$MaxPriceDiffPct = 0.5
    )

    if (-not $Quotes -or $Quotes.Count -eq 0) {
        throw 'all quote sources failed'
    }

    $priority = @{ eastmoney = 0; sina = 1; tencent = 2 }
    $sorted = @($Quotes | Sort-Object { $priority[$_.Source] })
    $prices = @($Quotes | ForEach-Object { [double]$_.Price })
    $minP = ($prices | Measure-Object -Minimum).Minimum
    $maxP = ($prices | Measure-Object -Maximum).Maximum
    $spreadPct = if ($minP -ne 0) { [math]::Round(($maxP - $minP) / $minP * 100, 2) } else { 0 }
    $consistent = ($Quotes.Count -eq 1) -or ($spreadPct -le $MaxPriceDiffPct)

    $primary = $sorted[0]
    $sourceNames = @($Quotes | ForEach-Object { $_.Source }) -join '+'

    return [PSCustomObject]@{
        Price         = $primary.Price
        PreClose      = $primary.PreClose
        High          = $primary.High
        Low           = $primary.Low
        ChangePct     = $primary.ChangePct
        PrimarySource = $primary.Source
        SourceCount   = $Quotes.Count
        Sources       = $sourceNames
        Consistent    = $consistent
        SpreadPct     = $spreadPct
        AllQuotes     = $Quotes
    }
}

function Get-StockQuoteMerged {
    param(
        [string]$Code,
        [int]$TimeoutSec = 10
    )

    $batch = Get-StockQuotesParallel -Code $Code -TimeoutSec $TimeoutSec
    if ($batch.Quotes.Count -eq 0) {
        $detail = ($batch.Errors -join '; ')
        throw "all sources failed: $detail"
    }
    return Merge-StockQuotes -Quotes $batch.Quotes
}
