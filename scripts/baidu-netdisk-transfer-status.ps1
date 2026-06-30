# baidu-netdisk-transfer-status.ps1
# Sediment from WeChat session: open Baidu Netdisk -> transfer tab -> OCR status
param(
    [switch]$SkipWake = $false
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "utf8-console.ps1")

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class BaiduNetdiskWin32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
'@
Add-Type -AssemblyName System.Windows.Forms

function Find-BaiduNetdiskProcess {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowHandle -ne [IntPtr]::Zero -and (
            $_.MainWindowTitle -eq '百度网盘' -or
            $_.MainWindowTitle -like '*百度网盘*'
        )
    } | Select-Object -First 1
}

function Start-BaiduNetdiskIfNeeded {
    $found = Find-BaiduNetdiskProcess
    if ($found) { return $found }

    $candidates = @(
        'F:\baiduwangpan\BaiduNetdisk\BaiduNetdisk.exe',
        "$env:LOCALAPPDATA\BaiduNetdisk\BaiduNetdisk.exe",
        "$env:ProgramFiles\BaiduNetdisk\BaiduNetdisk.exe",
        "${env:ProgramFiles(x86)}\BaiduNetdisk\BaiduNetdisk.exe"
    )
    foreach ($exe in $candidates) {
        if (-not (Test-Path -LiteralPath $exe)) { continue }
        Start-Process -FilePath $exe | Out-Null
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Milliseconds 500
            $found = Find-BaiduNetdiskProcess
            if ($found) { return $found }
        }
    }
    return $null
}

function Focus-BaiduNetdiskWindow {
    param([System.Diagnostics.Process]$Proc)
    [void][BaiduNetdiskWin32]::ShowWindowAsync($Proc.MainWindowHandle, 9)
    Start-Sleep -Milliseconds 300
    [void][BaiduNetdiskWin32]::SetForegroundWindow($Proc.MainWindowHandle)
    Start-Sleep -Milliseconds 500
}

function Open-TransferTab {
    [System.Windows.Forms.SendKeys]::SendWait('^t')
    Start-Sleep -Seconds 2
}

function Get-TransferSummaryFromOcr {
    param([string]$OcrText)

    $lines = @($OcrText -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($lines.Count -eq 0) {
        return '未识别到传输页文字，请确认百度网盘已打开。'
    }

    $joined = ($lines -join ' ')
    $hasTransfer = ($joined -match '传输|下载|上传|已完成|进行中|速度|进度')
    if (-not $hasTransfer) {
        return '网盘已打开，但未识别到传输页内容（可能未切到传输标签）。'
    }

    $parts = @()
    if ($joined -match '下载[^，。]*?(\d+\.?\d*\s*%|\d+\s*/\s*\d+|0\s*%|进度为\s*0)') {
        $parts += "下载：$($Matches[0])"
    } elseif ($joined -match '下载') {
        $parts += '下载区已显示'
    }
    if ($joined -match '已完成\s*(\d+)\s*个') {
        $parts += "已完成 $($Matches[1]) 个"
    }
    if ($joined -match '上传') {
        $parts += '含上传信息'
    }
    if ($parts.Count -eq 0) {
        $snippet = $joined
        if ($snippet.Length -gt 36) { $snippet = $snippet.Substring(0, 36) + '…' }
        return "传输页：$snippet"
    }
    return ($parts -join '，')
}

try {
    if (-not $SkipWake) {
        $wake = Join-Path $PSScriptRoot 'wake-screen.ps1'
        if (Test-Path $wake) {
            & $wake | Out-Null
            Start-Sleep -Milliseconds 400
        }
    }

    $proc = Start-BaiduNetdiskIfNeeded
    if (-not $proc) {
        Write-Host 'WECHAT_FAIL: baidu_netdisk_not_found'
        exit 1
    }

    Focus-BaiduNetdiskWindow -Proc $proc
    Open-TransferTab

    $ocrScript = Join-Path $PSScriptRoot 'screen-ocr.ps1'
    $ocrOut = & $ocrScript -SkipWake 2>&1 | Out-String
    if ($ocrOut -match 'WECHAT_FAIL:') {
        Write-Host ($ocrOut.Trim())
        exit 1
    }

    $ocrText = ''
    if ($ocrOut -match '(?s)--- OCR ---\s*(.+)$') {
        $ocrText = $Matches[1].Trim()
    } else {
        $ocrText = $ocrOut.Trim()
    }

    $summary = Get-TransferSummaryFromOcr -OcrText $ocrText
    Write-Host "WECHAT_OK: baidu transfer checked"
    Write-Host "WECHAT_USER_REPLY: 百度网盘传输：$summary"
}
catch {
    Write-Host "WECHAT_FAIL: $($_.Exception.Message)"
    exit 1
}
