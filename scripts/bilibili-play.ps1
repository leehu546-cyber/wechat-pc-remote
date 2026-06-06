param(
    [Parameter(Mandatory = $true)]
    [string]$bvid
)

$url = "https://www.bilibili.com/video/$bvid"

# Open video in Edge
Start-Process msedge $url

# Wait for page to load
Start-Sleep 5

# Set system volume to max
Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class Volume {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
}
'@
for ($i = 0; $i -lt 50; $i++) {
    [Volume]::keybd_event(0xAF, 0, 0, 0)   # VK_VOLUME_UP down
    [Volume]::keybd_event(0xAF, 0, 2, 0)   # VK_VOLUME_UP up
    Start-Sleep -Milliseconds 10
}

# Focus the video and unmute
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Find Edge window and bring to foreground
$wshell = New-Object -ComObject WScript.Shell
$wshell.AppActivate("bilibili") | Out-Null
Start-Sleep -Milliseconds 500
$wshell.AppActivate("Edge") | Out-Null
Start-Sleep -Milliseconds 500

# Click on video area (center of primary screen) to give it focus
$cursor = [System.Windows.Forms.Cursor]::Position
$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(($screenWidth/2), ($screenHeight/2 - 50))

$mouseDef = @'
[DllImport("user32.dll")]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, int dwExtraInfo);
'@
$mouse = Add-Type -MemberDefinition $mouseDef -Name "Mouse" -Namespace Win32 -PassThru

# Left click on video area
$mouse::mouse_event(0x02, 0, 0, 0, 0)   # MOUSEEVENTF_LEFTDOWN
Start-Sleep -Milliseconds 50
$mouse::mouse_event(0x04, 0, 0, 0, 0)   # MOUSEEVENTF_LEFTUP
Start-Sleep -Milliseconds 300

# Press 'm' to toggle mute/unmute (Bilibili player shortcut)
[System.Windows.Forms.SendKeys]::SendWait("m")
Start-Sleep -Milliseconds 200

# Ensure volume is max (press up a few more times)
for ($i = 0; $i -lt 10; $i++) {
    [Volume]::keybd_event(0xAF, 0, 0, 0)
    [Volume]::keybd_event(0xAF, 0, 2, 0)
    Start-Sleep -Milliseconds 10
}
