# 向操作日志追加一条记录
# 用法: .\log-step.ps1 -Title "标题" -Category "开发" -Body "操作说明" [-Result "结果"]
param(
    [Parameter(Mandatory)][string]$Title,
    [string]$Category = "操作",
    [string]$Body = "",
    [string]$Result = ""
)

$logFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\docs\操作日志.md"))
$content = [System.IO.File]::ReadAllText($logFile, [System.Text.Encoding]::UTF8)

# 计算下一个序号
$matches = [regex]::Matches($content, '(?m)^### (\d+) \|')
$nextNum = 1
if ($matches.Count -gt 0) {
    $nums = $matches | ForEach-Object { [int]$_.Groups[1].Value }
    $nextNum = ($nums | Measure-Object -Maximum).Maximum + 1
}

$date = Get-Date -Format "yyyy-MM-dd"
$entry = @"

### $($nextNum.ToString('00')) | $Category | $Title

**日期：** $date

**操作：**
``````powershell
$Body
``````

**结果：** $Result

---

"@

# 插入到「待办」章节之前
$marker = "## 待办（下一步）"
if ($content -match [regex]::Escape($marker)) {
    $content = $content -replace [regex]::Escape($marker), ($entry + $marker)
} else {
    $content += $entry
}

[System.IO.File]::WriteAllText($logFile, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "已追加日志 #$($nextNum.ToString('00')): $Title" -ForegroundColor Green
Write-Host "文件: $logFile"
