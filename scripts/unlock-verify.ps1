# Verify workstation is unlocked (not just schtasks SUCCESS). Used by unlock-screen.ps1 only.
param(
    [int]$WaitSeconds = 3,
    [int]$Retries = 4,
    [int]$RetryIntervalMs = 1500
)

$ErrorActionPreference = "Continue"

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class UnlockVerify {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    public static bool IsWorkstationUnlocked() {
        IntPtr tray = FindWindow("Shell_TrayWnd", null);
        if (tray != IntPtr.Zero) return true;
        IntPtr fg = GetForegroundWindow();
        if (fg == IntPtr.Zero) return false;
        var sb = new StringBuilder(256);
        GetClassName(fg, sb, sb.Capacity);
        string cls = sb.ToString();
        if (cls.IndexOf("LockApp", StringComparison.OrdinalIgnoreCase) >= 0) return false;
        if (cls.IndexOf("LogonUI", StringComparison.OrdinalIgnoreCase) >= 0) return false;
        if (cls.IndexOf("Windows.UI.Core.CoreWindow", StringComparison.OrdinalIgnoreCase) >= 0
            && cls.IndexOf("Lock", StringComparison.OrdinalIgnoreCase) >= 0) return false;
        return false;
    }
}
"@

function Test-LockScreenProcess {
    $names = @('LogonUI', 'LockApp')
    foreach ($n in $names) {
        if (Get-Process -Name $n -ErrorAction SilentlyContinue) {
            return $true
        }
    }
    return $false
}

function Test-WorkstationUnlocked {
    if ([UnlockVerify]::IsWorkstationUnlocked()) { return $true }
    if (-not (Test-LockScreenProcess)) {
        # No lock UI and no taskbar yet — treat as transitional unlocked if foreground is not lock class
        return $false
    }
    return $false
}

Start-Sleep -Seconds $WaitSeconds

for ($i = 0; $i -lt $Retries; $i++) {
    if (Test-WorkstationUnlocked) {
        Write-Host "WECHAT_OK: unlocked"
        exit 0
    }
    if ($i -lt ($Retries - 1)) {
        Start-Sleep -Milliseconds $RetryIntervalMs
    }
}

Write-Host "WECHAT_FAIL: PIN not accepted"
exit 1
