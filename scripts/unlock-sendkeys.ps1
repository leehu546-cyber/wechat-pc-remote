# Helper: type PIN on lock screen (run ONLY via schtasks as current USER)
# Sequence: Space -> PIN pad -> per-digit SendWait (no Enter; Win11 auto-submits full PIN)
$ErrorActionPreference = "Continue"

$debugLog = Join-Path $env:TEMP "unlock_debug_$PID.log"
function Log-Unlock {
    param([string]$Msg)
    "$(Get-Date -Format 'HH:mm:ss.fff') $Msg" | Out-File -FilePath $debugLog -Append -Encoding UTF8
}

Log-Unlock "STARTED pid=$PID user=$env:USERNAME"

$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
if (-not (Test-Path $configPath)) {
    Log-Unlock "FAIL: no config"
    Write-Host "UNLOCK_FAIL: no config"
    exit 1
}

$password = [string](Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).password
if (-not $password) {
    Log-Unlock "FAIL: empty password"
    Write-Host "UNLOCK_FAIL: empty password"
    exit 1
}

Log-Unlock "PIN length=$($password.Length)"

function Escape-SendKeys([string]$text) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $text.ToCharArray()) {
        switch ($ch) {
            '+' { [void]$sb.Append('{+}') }
            '^' { [void]$sb.Append('{^}') }
            '%' { [void]$sb.Append('{%}') }
            '~' { [void]$sb.Append('{~}') }
            '(' { [void]$sb.Append('{(}') }
            ')' { [void]$sb.Append('{)}') }
            '{' { [void]$sb.Append('{{}') }
            '}' { [void]$sb.Append('{}}') }
            '[' { [void]$sb.Append('{[}') }
            ']' { [void]$sb.Append('{]}') }
            default { [void]$sb.Append($ch) }
        }
    }
    return $sb.ToString()
}

Add-Type -AssemblyName System.Windows.Forms

# Lock screen: Space switches clock -> PIN pad; then type each digit with short gaps.
Start-Sleep -Seconds 2
Log-Unlock "SendWait Space"
[System.Windows.Forms.SendKeys]::SendWait(' ')
Start-Sleep -Seconds 1

foreach ($ch in $password.ToCharArray()) {
    $key = Escape-SendKeys ([string]$ch)
    Log-Unlock "SendWait digit"
    [System.Windows.Forms.SendKeys]::SendWait($key)
    Start-Sleep -Milliseconds 80
}

Log-Unlock "DONE (no Enter; Win11 PIN auto-submit)"
Write-Host "UNLOCK_OK"
