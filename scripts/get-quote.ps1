param([string]$Code="510300")
$secid = "1.$Code"
$url = "https://push2.eastmoney.com/api/qt/stock/get?secid=$secid&fields=f43,f44,f45,f46,f47,f48,f60,f169,f170"
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
    Write-Output ("{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}" -f $price,$change,$changePct,$high,$low,$preClose,$volume,$amount)
} catch {
    Write-Output "ERROR: $_"
}
