param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

$expanded = [Environment]::ExpandEnvironmentVariables($Path)
if (-not (Test-Path -LiteralPath $expanded -PathType Leaf)) {
    Write-Host "WECHAT_FAIL: file_not_found"
    Write-Host "WECHAT_USER_REPLY: 没做成：找不到要复制的文件。"
    exit 1
}

$source = (Resolve-Path -LiteralPath $expanded).Path
$desktop = [Environment]::GetFolderPath("Desktop")
if (-not (Test-Path -LiteralPath $desktop)) {
    Write-Host "WECHAT_FAIL: desktop_missing"
    Write-Host "WECHAT_USER_REPLY: 没做成：找不到桌面目录。"
    exit 1
}

$name = Split-Path -Leaf $source
$dest = Join-Path $desktop $name
if (Test-Path -LiteralPath $dest) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $ext = [System.IO.Path]::GetExtension($name)
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $dest = Join-Path $desktop ($base + "_" + $ts + $ext)
}

Copy-Item -LiteralPath $source -Destination $dest -Force
Write-Host "WECHAT_OK: copied to desktop"
Write-Host "WECHAT_USER_REPLY: 已放到桌面：$(Split-Path -Leaf $dest)"
