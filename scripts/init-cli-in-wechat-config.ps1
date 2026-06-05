# 初始化 cli-in-wechat 配置（微信 → CLI 桥接）
$configDir = Join-Path $env:USERPROFILE ".wx-ai-bridge"
$configFile = Join-Path $configDir "config.json"

$defaultConfig = @{
    defaultTool = "codex"
    maxResponseChunkSize = 2000
    cliTimeout = 300000
    typingInterval = 5000
    allowedUsers = @()
    workDir = "D:\cursor\61"
    tools = @{}
} | ConvertTo-Json -Depth 4

if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

if (Test-Path $configFile) {
    Write-Host "配置已存在，跳过: $configFile" -ForegroundColor Yellow
    Get-Content $configFile
} else {
    Set-Content -Path $configFile -Value $defaultConfig -Encoding UTF8
    Write-Host "已创建配置: $configFile" -ForegroundColor Green
    Get-Content $configFile
}
