# keep-awake.ps1 - prevent Modern Standby (S0 Low Power Idle)
$code = @"
using System;
using System.Runtime.InteropServices;
public class PowerWake {
    [DllImport("kernel32.dll")]
    public static extern IntPtr PowerCreateRequest(ref POWER_REQUEST_CONTEXT Context);
    [DllImport("kernel32.dll")]
    public static extern bool PowerSetRequest(IntPtr PowerRequest, uint RequestType);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct POWER_REQUEST_CONTEXT {
        public uint Version; public uint Flags;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string SimpleReasonString;
    }
    public static IntPtr Hold() {
        var ctx = new POWER_REQUEST_CONTEXT { Version = 0, Flags = 1, SimpleReasonString = "WeChat Bridge" };
        var h = PowerCreateRequest(ref ctx);
        if (h != IntPtr.Zero) PowerSetRequest(h, 3);
        return h;
    }
}
"@
Add-Type -TypeDefinition $code
$h = [PowerWake]::Hold()
while ($true) { Start-Sleep -Seconds 60 }