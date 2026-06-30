# 本地一键：百度网盘传输状态（无需微信）
# 用法: .\scripts\quick-baidu-netdisk.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot "baidu-netdisk-transfer-status.ps1") @args
