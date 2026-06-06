# keep-awake.ps1 — 保持系统活跃，阻止 Modern Standby (S0 Low Power Idle)
# 由 start-weclaw.ps1 启动，与 weclaw 同生命周期
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PowerWake {
    [DllImport("kernel32.dll")]
    public static extern IntPtr PowerCreateRequest(ref POWER_REQUEST_CONTEXT Context);
    [DllImport("kernel32.dll")]
    public static extern bool PowerSetRequest(IntPtr PowerRequest, POWER_REQUEST_TYPE RequestType);    
    public enum POWER_REQUEST_TYPE {
        PowerRequestExecutionRequired = 3
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct POWER_REQUEST_CONTEXT {
        public uint Version;
        public uint Flags;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string SimpleReasonString;
    }
    public static IntPtr Hold() {
        var ctx = new POWER_REQUEST_CONTEXT { Version = 0, Flags = 1, SimpleReasonString = "WeChat Bridge" };
        var h = PowerCreateRequest(ref ctx);
        if (h != IntPtr.Zero) PowerSetRequest(h, POWER_REQUEST_TYPE.PowerRequestExecutionRequired);
        return h;
    }
}
"@
$h = [PowerWake]::Hold()
# 保持运行，直到进程被杀死
while ($true) { Start-Sleep -Seconds 60 }
