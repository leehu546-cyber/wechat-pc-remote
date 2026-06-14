param(
    [string]$Code = "510300",
    [double]$CostPrice = 4.92,
    [int]$Shares = 100
)

$taskName = "StockAlert-$Code"
$scriptPath = "$PSScriptRoot\stock-hourly.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Code $Code -CostPrice $CostPrice -Shares $Shares"
$trigger = New-ScheduledTaskTrigger -Daily -At "09:30" -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest -Force

Write-Host "✅ 定时任务已创建：$taskName" -ForegroundColor Green
Write-Host "每小时弹出窗口提醒 $Code 成交价" -ForegroundColor Cyan
Write-Host "可在「任务计划程序」中查看或删除" -ForegroundColor DarkGray
