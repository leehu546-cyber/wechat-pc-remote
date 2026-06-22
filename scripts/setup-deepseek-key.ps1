# Save DeepSeek API key for WeClaw router (HTTP, no OpenCode)
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiKey
)

$ErrorActionPreference = "Stop"
$weclawDir = Join-Path $env:USERPROFILE ".weclaw"
$keyPath = Join-Path $weclawDir "deepseek.json"
New-Item -ItemType Directory -Path $weclawDir -Force | Out-Null

if (-not $ApiKey) {
    $secure = Read-Host "DeepSeek API Key (sk-...)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$ApiKey = $ApiKey.Trim()
if (-not $ApiKey) { throw "API key is empty" }

$payload = @{ api_key = $ApiKey } | ConvertTo-Json
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($keyPath, $payload, $utf8NoBom)
Write-Host "Saved $keyPath" -ForegroundColor Green
Write-Host "Run: scripts\init-weclaw-opencode.ps1  then  scripts\restart-weclaw.ps1" -ForegroundColor Cyan
