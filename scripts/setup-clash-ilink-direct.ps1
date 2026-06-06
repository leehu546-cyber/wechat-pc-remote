# Add WeChat iLink DIRECT bypass for Clash Nyanpasu (fixes GetUpdates error over VPN proxy)
$ErrorActionPreference = "Stop"

$nyanpasuDir = Join-Path $env:APPDATA "Clash Nyanpasu\config"
$nyanpasuConfig = Join-Path $nyanpasuDir "nyanpasu-config.yaml"
$clashConfig = Join-Path $nyanpasuDir "clash-config.yaml"

$bypass = "ilinkai.weixin.qq.com;*.weixin.qq.com"
$dnsLines = @("  - ilinkai.weixin.qq.com", "  - '+.weixin.qq.com'")
$ruleLines = @("- DOMAIN,ilinkai.weixin.qq.com,DIRECT", "- DOMAIN-SUFFIX,weixin.qq.com,DIRECT")

Write-Host "=== Clash iLink DIRECT setup ===" -ForegroundColor Cyan

if (Test-Path $nyanpasuConfig) {
    $lines = Get-Content $nyanpasuConfig -Encoding UTF8
    $out = @()
    foreach ($line in $lines) {
        if ($line -match '^system_proxy_bypass:') {
            $out += "system_proxy_bypass: '$bypass'"
        } else {
            $out += $line
        }
    }
    $out | Set-Content $nyanpasuConfig -Encoding UTF8
    Write-Host "[ok] system_proxy_bypass: $bypass" -ForegroundColor Green
}

if (Test-Path $clashConfig) {
    $lines = Get-Content $clashConfig -Encoding UTF8
    $out = @()
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        if ($line -eq '  fake-ip-filter:' -and ($out -notcontains '  - ilinkai.weixin.qq.com')) {
            $out += $line
            $i++
            foreach ($dns in $dnsLines) { $out += $dns }
            continue
        }
        if ($line -eq 'rules:' -and ($out -notcontains '- DOMAIN,ilinkai.weixin.qq.com,DIRECT')) {
            $out += $line
            foreach ($rule in $ruleLines) { $out += $rule }
            $i++
            continue
        }
        $out += $line
        $i++
    }
    $out | Set-Content $clashConfig -Encoding UTF8
    Write-Host "[ok] clash-config: DIRECT rules + fake-ip-filter" -ForegroundColor Green
}

Write-Host ""
Write-Host "Reload Clash Nyanpasu profile, then: D:\cursor\61\scripts\restart-weclaw.ps1" -ForegroundColor Cyan
