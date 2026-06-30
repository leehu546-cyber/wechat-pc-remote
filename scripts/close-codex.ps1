# close-codex.ps1 - terminate Cursor / Codex IDE process
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$targets = @("Codex", "Cursor", "cursor")
$killed = $false

foreach ($name in $targets) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        $p.CloseMainWindow() | Out-Null
        if (-not $p.HasExited) {
            $p.Kill() | Out-Null
        }
        $killed = $true
    }
}

if ($killed) {
    Write-Host "WECHAT_OK: codex terminated"
    Write-Host "WECHAT_USER_REPLY: 已关闭 Codex/Cursor。"
} else {
    Write-Host "WECHAT_OK: codex_not_running"
    Write-Host "WECHAT_USER_REPLY: Codex/Cursor 未在运行。"
}
