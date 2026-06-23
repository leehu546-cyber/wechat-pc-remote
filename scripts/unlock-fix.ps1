# Fix: SYSTEM-level SendKeys via Winlogon desktop switch
$ErrorActionPreference = "Continue"
$debugLog = "D:\cursor\61\.opencode\unlock_fix_$PID.log"
function Log { param($m) "$(Get-Date -Format 'HH:mm:ss.fff') $m" | Out-File $debugLog -Append -Encoding UTF8 }
Log "STARTED pid=$pid user=$env:USERNAME"

$userHome = "C:\Users\21179"
$configPath = Join-Path $userHome ".weclaw\unlock-screen.json"
$password = [string](Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).password
Log "PIN length=$($password.Length)"

Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinlogonSend {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr OpenWindowStation(string lpszWinSta, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetProcessWindowStation(IntPtr hWinSta);
    public const uint DESKTOP_ALL = 0x000F01FF;
    public const uint WINSTA_ALL = 0x0000037F;
}
'@

$hSta = [WinlogonSend]::OpenWindowStation("WinSta0", $false, [WinlogonSend]::WINSTA_ALL)
if ($hSta -eq [IntPtr]::Zero) {
    Log "OpenWindowStation WinSta0 FAIL err=$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
} else {
    Log "OpenWindowStation WinSta0 OK"
    $setSta = [WinlogonSend]::SetProcessWindowStation($hSta)
    Log "SetProcessWindowStation WinSta0 = $setSta"
}

# Create child process on Winlogon desktop via WMI (SYSTEM has TCB privilege)
$innerLog = "D:\cursor\61\.opencode\inner_$PID.log"
$innerScript = @'
$log = "@@INNERLOG@@"
function il { param($m) "$(Get-Date -Format 'HH:mm:ss.fff') $m" | Out-File $log -Append -Encoding UTF8 }
il "INNER STARTED"

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class WinMsg {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")]
    public static extern uint GetClassNameW(IntPtr hWnd, StringBuilder classname, int count);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    public const uint WM_CHAR = 0x0102;
    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_KEYUP = 0x0101;
    public const uint WM_LBUTTONDOWN = 0x0201;
    public const uint WM_LBUTTONUP = 0x0202;
}
"@

il "Native loaded"
$p = "@@PASSWORD@@"
il "pwd len=$($p.Length)"

# Enumerate all windows on this desktop
$windows = [System.Collections.ArrayList]::new()
$proc = [WinMsg+EnumWindowsProc]{
    param($hWnd, $lParam)
    $sb1 = New-Object StringBuilder 256
    $sb2 = New-Object StringBuilder 256
    [WinMsg]::GetWindowTextW($hWnd, $sb1, 256) | Out-Null
    [WinMsg]::GetClassNameW($hWnd, $sb2, 256) | Out-Null
    $vis = [WinMsg]::IsWindowVisible($hWnd)
    $pid = 0
    [WinMsg]::GetWindowThreadProcessId($hWnd, [ref]$pid) | Out-Null
    if ($vis) {
        [void]$windows.Add([PSCustomObject]@{h=$hWnd;cls=$sb2.ToString();txt=$sb1.ToString();pid=$pid})
    }
    return $true
}
[WinMsg]::EnumWindows($proc, [IntPtr]0) | Out-Null
il "found $($windows.Count) visible windows"
foreach ($w in $windows) {
    il "  h=0x$($w.h.ToString('x8')) cls='$($w.cls)' txt='$($w.txt)' pid=$($w.pid)"
}

# Find a suitable target: LogonUI, LockApp, or any visible top-level
$target = [IntPtr]0
# Try LogonUI class windows
foreach ($w in $windows) {
    $c = $w.cls.ToLower()
    if ($c -match "logon|credential|corewindow|lockapp") { $target = $w.h; il "target=$($w.cls)"; break }
}
if ($target -eq [IntPtr]0 -and $windows.Count -gt 0) {
    # Use the first visible window that is not the desktop
    foreach ($w in $windows) {
        if ($w.cls -ne "Progman" -and $w.cls -ne "#32769") { $target = $w.h; il "target fallback=$($w.cls)"; break }
    }
}

if ($target -eq [IntPtr]0) {
    il "NO TARGET WINDOW FOUND - trying desktop"
    # Last resort: try the desktop window
    $target = [WinMsg]::FindWindow("Progman", $null)
}
il "FINAL target hWnd=0x$($target.ToString('x8'))"

# Post Space
Start-Sleep -Seconds 1
[WinMsg]::PostMessage($target, 0x0100, [IntPtr]0x20, [IntPtr]0) | Out-Null
[WinMsg]::PostMessage($target, 0x0101, [IntPtr]0x20, [IntPtr]0xC0200001) | Out-Null
il "Space posted"
Start-Sleep -Seconds 1

# Post digits
foreach ($ch in $p.ToCharArray()) {
    $vk = [int][char]$ch
    [WinMsg]::PostMessage($target, 0x0100, [IntPtr]$vk, [IntPtr]0) | Out-Null
    [WinMsg]::PostMessage($target, 0x0101, [IntPtr]$vk, [IntPtr]0xC0200001) | Out-Null
    il "posted $ch"
    Start-Sleep -Milliseconds 100
}
Start-Sleep -Milliseconds 800
[WinMsg]::PostMessage($target, 0x0100, [IntPtr]0x0D, [IntPtr]0) | Out-Null
[WinMsg]::PostMessage($target, 0x0101, [IntPtr]0x0D, [IntPtr]0x1C000001) | Out-Null
il "Enter posted"
il "INNER DONE"
'@ -replace '@@PASSWORD@@', $password -replace '@@INNERLOG@@', $innerLog

$tmpFile = "$env:TEMP\_unlock_winlogon_$PID.ps1"
Set-Content -Path $tmpFile -Value $innerScript -Encoding UTF8
Log "Inner script created: $tmpFile"

$startup = ([System.Management.ManagementClass] "Win32_ProcessStartup").CreateInstance()
$startup["DesktopName"] = "WinSta0\Winlogon"
$startup["CreateFlags"] = 0x00000010
$command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tmpFile`""
$result = ([System.Management.ManagementClass] "Win32_Process").Create($command, $null, $startup)
Log "WMI result=$($result.returnValue) PID=$($result.processId)"

Start-Sleep -Seconds 12
Remove-Item $tmpFile -Force -ErrorAction Ignore
Log "DONE"
