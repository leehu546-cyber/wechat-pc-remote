# WeChat iLink DIRECT bypass for Clash Nyanpasu — rule + global + TUN mode
# Run after subscription update: D:\cursor\61\scripts\setup-clash-ilink-direct.ps1
$ErrorActionPreference = "Stop"

$nyanpasuDir = Join-Path $env:APPDATA "Clash Nyanpasu\config"
$nyanpasuConfig = Join-Path $nyanpasuDir "nyanpasu-config.yaml"
$clashConfig = Join-Path $nyanpasuDir "clash-config.yaml"
$guardOverrides = Join-Path $nyanpasuDir "clash-guard-overrides.yaml"
$profilesYaml = Join-Path $nyanpasuDir "profiles.yaml"
$ipListFile = Join-Path $nyanpasuDir "weclaw-ilink-ip.yaml"
$mergeProfile = Join-Path $nyanpasuDir "profiles\weclaw-ilink-bypass.yaml"
$mergeUid = "weclawIlinkBypass"
$repoIpTemplate = Join-Path $PSScriptRoot "weclaw-ilink-ip.yaml"

$bypass = "ilinkai.weixin.qq.com;*.weixin.qq.com;aewebpodproxy.weixin.qq.com"
$dnsFilters = @(
    "ilinkai.weixin.qq.com"
    "+.weixin.qq.com"
    "aewebpodproxy.weixin.qq.com"
    "*.weixin.qq.com"
)
$prependRules = @(
    "DOMAIN,ilinkai.weixin.qq.com,DIRECT"
    "DOMAIN,aewebpodproxy.weixin.qq.com,DIRECT"
    "DOMAIN-SUFFIX,weixin.qq.com,DIRECT"
)

function Test-PublicIP([string]$IP) {
    return $IP -match '^\d{1,3}(\.\d{1,3}){3}$' -and
        $IP -notmatch '^(127\.|0\.|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|223\.5\.5\.|119\.29\.29\.|223\.6\.6\.6)'
}

function Resolve-IlinkIPs {
    $ips = [System.Collections.Generic.HashSet[string]]::new()
    [void]$ips.Add("43.163.179.90") # historical from weclaw.log

    foreach ($server in @("223.5.5.5", "119.29.29.29")) {
        try {
            $inAddresses = $false
            foreach ($line in (nslookup ilinkai.weixin.qq.com $server 2>&1)) {
                $text = "$line"
                if ($text -match 'Addresses?:\s*(\d{1,3}(?:\.\d{1,3}){3})') {
                    $ip = $matches[1]
                    if (Test-PublicIP $ip) { [void]$ips.Add($ip) }
                    $inAddresses = $true
                    continue
                }
                if ($inAddresses -and $text -match '^\s+(\d{1,3}(?:\.\d{1,3}){3})') {
                    $ip = $matches[1]
                    if (Test-PublicIP $ip) { [void]$ips.Add($ip) }
                }
                if ($text -match 'Aliases?:') { $inAddresses = $false }
            }
        } catch { }
    }

    try {
        Resolve-DnsName ilinkai.weixin.qq.com -Type A -DnsOnly -Server 223.5.5.5 -ErrorAction Stop |
            ForEach-Object { if ($_.IPAddress -and (Test-PublicIP $_.IPAddress)) { [void]$ips.Add($_.IPAddress) } }
    } catch { }

    return @($ips) | Sort-Object
}

# Tencent CDN ranges used by ilinkai (covers IP rotation in global+TUN mode)
$extraCidrs = @(
    "43.163.0.0/16"
    "36.155.0.0/16"
    "120.204.0.0/16"
    "183.192.0.0/16"
)

function Write-IplinkIpYaml {
    param([string[]]$IPs, [string]$Path)
    $lines = @(
        "# WeClaw iLink server IPs — bypass TUN in global mode"
        "# Refresh: D:\cursor\61\scripts\setup-clash-ilink-direct.ps1"
        "payload:"
    )
    foreach ($ip in $IPs) {
        $lines += "  - IP-CIDR,$ip/32,no-resolve"
    }
    foreach ($cidr in $extraCidrs) {
        $lines += "  - IP-CIDR,$cidr,no-resolve"
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($Path, ($lines -join "`n") + "`n", $utf8)
}

function Write-GuardOverrides {
    param([string[]]$IPs, [string]$Path)
    $routeLines = @()
    foreach ($ip in $IPs) { $routeLines += "    - $ip/32" }
    foreach ($cidr in $extraCidrs) { $routeLines += "    - $cidr" }
    $yaml = @"
# WeClaw / WeChat iLink bypass — persists across subscription reload
# Global mode: tun.route-exclude-address bypasses proxy; rule mode: prepend-rules DIRECT

dns:
  fake-ip-filter:
    - ilinkai.weixin.qq.com
    - '+.weixin.qq.com'
    - aewebpodproxy.weixin.qq.com
    - '*.weixin.qq.com'
  nameserver-policy:
    '+.weixin.qq.com':
      - 223.5.5.5
      - 119.29.29.29
    'ilinkai.weixin.qq.com':
      - 223.5.5.5
      - 119.29.29.29

tun:
  route-exclude-address:
$($routeLines -join "`n")
  route-exclude-address-set:
    - weclaw-ilink-ip

rule-providers:
  weclaw-ilink-ip:
    type: file
    behavior: ipcidr
    format: yaml
    path: ./weclaw-ilink-ip.yaml

prepend-rules:
  - DOMAIN,ilinkai.weixin.qq.com,DIRECT
  - DOMAIN,aewebpodproxy.weixin.qq.com,DIRECT
  - DOMAIN-SUFFIX,weixin.qq.com,DIRECT

sniffer:
  skip-domain:
    - '+.weixin.qq.com'
    - ilinkai.weixin.qq.com
"@
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($Path, $yaml.TrimEnd() + "`n", $utf8)
}

function Update-ClashConfig {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $lines = Get-Content $Path -Encoding UTF8
    $out = @()
    $seenDns = @{}
    $seenRules = @{}
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        if ($line -eq '  fake-ip-filter:') {
            $out += $line
            $i++
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s+- ') {
                $item = $lines[$i].TrimStart().Substring(2)
                if (-not $seenDns.ContainsKey($item)) {
                    $seenDns[$item] = $true
                    $out += $lines[$i]
                }
                $i++
            }
            foreach ($f in $dnsFilters) {
                $entry = "  - $f"
                if (-not $seenDns.ContainsKey($f)) {
                    $out += $entry
                    $seenDns[$f] = $true
                }
            }
            continue
        }
        if ($line -eq 'rules:') {
            $out += $line
            foreach ($rule in $prependRules) {
                $entry = "- $rule"
                if (-not $seenRules.ContainsKey($rule)) {
                    $out += $entry
                    $seenRules[$rule] = $true
                }
            }
            $i++
            while ($i -lt $lines.Count -and $lines[$i] -match '^- ') {
                $rule = $lines[$i].Substring(2)
                if ($rule -match '^DOMAIN.*weixin\.qq\.com|^DOMAIN.*ilinkai') {
                    $i++
                    continue
                }
                if (-not $seenRules.ContainsKey($rule)) {
                    $out += $lines[$i]
                    $seenRules[$rule] = $true
                }
                $i++
            }
            continue
        }
        $out += $line
        $i++
    }
    $out | Set-Content $Path -Encoding UTF8
}

function Ensure-MergeProfileChain {
    param([string]$ProfilesPath, [string]$RemoteUid, [string]$MergeUid)
    if (-not (Test-Path $ProfilesPath)) { return }
    $text = Get-Content $ProfilesPath -Raw -Encoding UTF8
    if ($text -notmatch "uid:\s*$MergeUid") {
        $mergeItem = @"
- uid: $MergeUid
  type: merge
  name: WeClaw iLink Bypass
  file: weclaw-ilink-bypass.yaml
  desc: WeChat iLink DIRECT for global/TUN mode
"@
        $text = $text.TrimEnd() + "`n$mergeItem"
    }
    $chainBlock = @"
chain:
- $RemoteUid
- $MergeUid
"@
    if ($text -match 'chain:\s*null') {
        $text = $text -replace 'chain:\s*null', $chainBlock
    } elseif ($text -notmatch "uid:\s*$MergeUid") {
        # chain exists but merge not in chain — user may have custom chain; only add item
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($ProfilesPath, $text, $utf8)
}

Write-Host "=== WeChat iLink bypass (global + TUN) ===" -ForegroundColor Cyan

$ips = Resolve-IlinkIPs
Write-Host "Resolved IPs: $($ips -join ', ')" -ForegroundColor DarkGray

Write-IplinkIpYaml -IPs $ips -Path $ipListFile
Copy-Item $ipListFile $repoIpTemplate -Force -ErrorAction SilentlyContinue
Write-GuardOverrides -IPs $ips -Path $guardOverrides
Write-GuardOverrides -IPs $ips -Path $mergeProfile

if (Test-Path $nyanpasuConfig) {
    $lines = Get-Content $nyanpasuConfig -Encoding UTF8
    $out = foreach ($line in $lines) {
        if ($line -match '^system_proxy_bypass:') { "system_proxy_bypass: '$bypass'" } else { $line }
    }
    $out | Set-Content $nyanpasuConfig -Encoding UTF8
    Write-Host "[ok] system_proxy_bypass" -ForegroundColor Green
}

Update-ClashConfig -Path $clashConfig
Write-Host "[ok] clash-config.yaml (deduped rules + dns)" -ForegroundColor Green

Write-Host "[ok] clash-guard-overrides.yaml" -ForegroundColor Green
Write-Host "[ok] weclaw-ilink-ip.yaml ($($ips.Count) IPs)" -ForegroundColor Green

Ensure-MergeProfileChain -ProfilesPath $profilesYaml -RemoteUid "rRA15xPaMFSb" -MergeUid $mergeUid
Write-Host "[ok] profiles.yaml merge chain" -ForegroundColor Green

# Sync Windows system proxy bypass (used when system proxy enabled)
try {
    $bypassReg = "$bypass;<local>"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" `
        -Name ProxyOverride -Value $bypassReg -ErrorAction Stop
    Write-Host "[ok] Windows ProxyOverride registry" -ForegroundColor Green
} catch {
    Write-Warning "ProxyOverride registry: $_"
}

# Touch clash-config to nudge Nyanpasu reload on next open
try {
    if (Test-Path $clashConfig) {
        (Get-Item $clashConfig).LastWriteTime = Get-Date
    }
} catch { }

# Try Mihomo external-controller reload
$secret = "4151d0ff-5828-4e88-9cee-9f933daa8e0f"
$reloaded = $false
foreach ($port in @(17650, 9090)) {
    try {
        $h = @{ Authorization = "Bearer $secret" }
        Invoke-RestMethod -Uri "http://127.0.0.1:${port}/configs" -Headers $h -Method PUT `
            -Body '{"payload":"reload"}' -ContentType "application/json" -TimeoutSec 5 | Out-Null
        Write-Host "[ok] Clash API reload on port $port" -ForegroundColor Green
        $reloaded = $true
        break
    } catch { }
}
if (-not $reloaded) {
    Write-Host "[..] Clash API reload skipped — please reload profile in Nyanpasu UI" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next: restart weclaw if needed — D:\cursor\61\scripts\restart-weclaw.ps1" -ForegroundColor Cyan
