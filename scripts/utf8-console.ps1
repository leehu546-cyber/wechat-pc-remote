# Force UTF-8 on stdout/stderr for scripts whose output is read by OpenCode/WeClaw (expects UTF-8).
# Dot-source at the top of any .ps1 that Write-Host Chinese to the user.
param()

if ($PSVersionTable.PSVersion.Major -lt 6) {
    try { chcp 65001 | Out-Null } catch { }
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
$script:OutputEncoding = $utf8
