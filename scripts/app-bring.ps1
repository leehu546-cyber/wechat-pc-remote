Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@

$procs = Get-Process | Where-Object { $_.MainWindowTitle -like '*gmyy*' -or $_.MainWindowTitle -like '*Word*' -or $_.ProcessName -like '*WORD*' } | Sort-Object StartTime -Descending
if ($procs) {
    foreach ($p in $procs) {
        if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
            [Win32]::ShowWindowAsync($p.MainWindowHandle, 9) | Out-Null
            [Win32]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
            Write-Host "OK: $($p.ProcessName) - $($p.MainWindowTitle)"
            exit
        }
    }
    Write-Host "no handle"
} else {
    Write-Host "no process"
}
