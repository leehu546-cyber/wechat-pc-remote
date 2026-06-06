# keep-awake.ps1 - bridge lifecycle daemon: block S0ix + keep SYSTEM awake (network/iLink)
# ES_SYSTEM only — display may be off (turn-off-screen / timeout); wake-screen.ps1 handles亮屏.
# Started by start-weclaw.ps1 (singleton). Do not run multiple instances.
param(
    [int]$RefreshSec = 45
)

$ErrorActionPreference = "Continue"

# ES_CONTINUOUS | ES_SYSTEM_REQUIRED  (NOT ES_DISPLAY — allows monitor off while LAN stays up)
$ES_PIN = [uint32]2147483649
# PowerRequestExecutionRequired
$POWER_EXEC_REQUIRED = [uint32]3

$code = @"
using System;
using System.Runtime.InteropServices;
public class BridgeKeepAwake {
    [DllImport("kernel32.dll")]
    public static extern IntPtr PowerCreateRequest(ref POWER_REQUEST_CONTEXT Context);
    [DllImport("kernel32.dll")]
    public static extern bool PowerSetRequest(IntPtr PowerRequest, uint RequestType);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct POWER_REQUEST_CONTEXT {
        public uint Version; public uint Flags;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string SimpleReasonString;
    }
    public static IntPtr HoldExecutionRequired() {
        var ctx = new POWER_REQUEST_CONTEXT { Version = 0, Flags = 1, SimpleReasonString = "WeChat Bridge" };
        var h = PowerCreateRequest(ref ctx);
        if (h != IntPtr.Zero) PowerSetRequest(h, 3);
        return h;
    }
}
"@

Add-Type -TypeDefinition $code -ErrorAction Stop
[void][BridgeKeepAwake]::HoldExecutionRequired()

while ($true) {
    [void][BridgeKeepAwake]::SetThreadExecutionState($ES_PIN)
    Start-Sleep -Seconds $RefreshSec
}
