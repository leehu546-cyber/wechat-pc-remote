# Helper: type lock-screen password (run ONLY via schtasks as current USER)
$ErrorActionPreference = "Continue"

$configPath = Join-Path $env:USERPROFILE ".weclaw\unlock-screen.json"
if (-not (Test-Path $configPath)) {
    Write-Host "UNLOCK_FAIL: no config"
    exit 1
}

$password = [string](Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).password
if (-not $password) {
    Write-Host "UNLOCK_FAIL: empty password"
    exit 1
}

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

# Lock screen: Space shows/focuses password field; then SendKeys types into secure desktop.
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait(' ')
Start-Sleep -Milliseconds 800

$escaped = Escape-SendKeys $password
[System.Windows.Forms.SendKeys]::SendWait($escaped)
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')

Write-Host "UNLOCK_OK"
