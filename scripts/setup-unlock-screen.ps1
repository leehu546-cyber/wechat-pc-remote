# One-time: create ~/.weclaw/unlock-screen.json for wechat-screen-unlock skill
param(
    [string]$Password
)

$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
$dir = Split-Path $configPath -Parent
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

if (-not $Password) {
    $secure = Read-Host "Windows lock-screen PIN/password" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $Password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

@{ password = $Password } | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
Write-Host "[ok] Saved to $configPath (not in git)" -ForegroundColor Green
Write-Host "Test: powershell -File scripts\unlock-screen.ps1" -ForegroundColor Cyan
