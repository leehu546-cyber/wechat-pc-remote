Add-Type @'
using System; using System.Runtime.InteropServices;
public struct RECT { public int Left, Top, Right, Bottom; }
public class W {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int n);
}
'@
Add-Type -AssemblyName System.Windows.Forms
$p = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq '百度网盘' -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if (-not $p) { Write-Output 'NO_WINDOW'; exit 1 }
[W]::ShowWindowAsync($p.MainWindowHandle, 9) | Out-Null
Start-Sleep -Milliseconds 300
[W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500
# Alt+T or open transfer - try common shortcuts
[System.Windows.Forms.SendKeys]::SendWait('^t')
Start-Sleep -Seconds 2
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\screen-ocr.ps1') -SkipWake 2>&1 | Select-Object -Last 40
