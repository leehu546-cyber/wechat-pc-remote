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

# Optional: PsyChip/hodor Credential Provider (https://github.com/PsyChip/hodor)
try {
    $client = New-Object System.IO.Pipes.NamedPipeClientStream(
        ".", "CredentialProviderPipe",
        [System.IO.Pipes.PipeDirection]::InOut
    )
    $client.Connect(500)
    $client.Close()
    Write-Host "[ok] hodor pipe CredentialProviderPipe is reachable — unlock-screen.ps1 will prefer pipe" -ForegroundColor Green
} catch {
    Write-Host "[info] hodor pipe not installed — unlock-screen.ps1 will use schtasks PIN SendKeys fallback" -ForegroundColor Yellow
    Write-Host "       Install hodor (admin, one-time) for reliable PIN-only unlock: https://github.com/PsyChip/hodor" -ForegroundColor DarkGray
}

Write-Host "Test: powershell -File scripts\unlock-screen.ps1" -ForegroundColor Cyan
Write-Host "Matrix: powershell -File scripts\test-unlock-methods.ps1 [-LockScreenMode]" -ForegroundColor Cyan
