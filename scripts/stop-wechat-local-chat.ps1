# Stop legacy wechat-local-chat bridge and optional OpenCode serve
$ErrorActionPreference = "SilentlyContinue"

$pidFile = Join-Path $env:USERPROFILE ".wechat-local-chat\bridge.pid"
if (Test-Path $pidFile) {
    $bpid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($bpid -and (Get-Process -Id $bpid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $bpid -Force
        Write-Host "Stopped wechat-local-chat bridge pid=$bpid"
    }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

$servePidFile = Join-Path $env:USERPROFILE ".wechat-local-chat\opencode-serve.pid"
if (Test-Path $servePidFile) {
    $spid = Get-Content $servePidFile -ErrorAction SilentlyContinue
    if ($spid -and (Get-Process -Id $spid -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $spid -Force
        Write-Host "Stopped opencode-serve pid=$spid"
    }
    Remove-Item $servePidFile -Force -ErrorAction SilentlyContinue
}

foreach ($task in @("WeChatLocalChatBridge", "WeChatOpenCodeServe")) {
    if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false
        Write-Host "Removed scheduled task: $task"
    }
}
