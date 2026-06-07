# Unlock via PsyChip/hodor Credential Provider named pipe (optional; admin install once).
# Protocol: UNLOCK:domain\username:password -> OK | ERR:*
param(
    [int]$ConnectTimeoutMs = 5000
)

$ErrorActionPreference = "Continue"

$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
if (-not (Test-Path $configPath)) {
    Write-Host "PIPE_FAIL: no config"
    exit 1
}

try {
    $password = [string](Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).password
} catch {
    Write-Host "PIPE_FAIL: read config"
    exit 1
}

if (-not $password) {
    Write-Host "PIPE_FAIL: empty password"
    exit 1
}

$pipeName = "CredentialProviderPipe"
$user = ".\$env:USERNAME"
$command = "UNLOCK:${user}:${password}"
$client = $null

try {
    $client = New-Object System.IO.Pipes.NamedPipeClientStream(
        ".", $pipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        [System.IO.Pipes.PipeOptions]::None
    )
    $client.Connect($ConnectTimeoutMs)
    try { $client.ReadMode = [System.IO.Pipes.PipeTransmissionMode]::Message } catch { }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($command)
    $client.Write($bytes, 0, $bytes.Length)
    $client.Flush()

    $buffer = New-Object byte[] 512
    $read = $client.Read($buffer, 0, $buffer.Length)
    $response = ""
    if ($read -gt 0) {
        $response = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read).Trim()
    }

    if ($response -eq "OK") {
        Write-Host "PIPE_OK"
        exit 0
    }
    if ($response) {
        Write-Host "PIPE_FAIL: $response"
    } else {
        Write-Host "PIPE_FAIL: empty response"
    }
    exit 1
} catch {
    Write-Host "PIPE_FAIL: $($_.Exception.Message)"
    exit 1
} finally {
    if ($client) {
        try { $client.Dispose() } catch { }
    }
}
