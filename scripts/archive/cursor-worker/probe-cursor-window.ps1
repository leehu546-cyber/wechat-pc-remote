Add-Type @'
using System; using System.Runtime.InteropServices;
public struct RECT { public int Left, Top, Right, Bottom; }
public class W { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); }
'@
$p = Get-Process -Name Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if (-not $p) { Write-Output "Cursor not found"; exit 1 }
$r = New-Object RECT
[void][W]::GetWindowRect($p.MainWindowHandle, [ref]$r)
$w = $r.Right - $r.Left
$h = $r.Bottom - $r.Top
Write-Output "window=$($r.Left),$($r.Top),$($r.Right),$($r.Bottom) size=${w}x${h}"
foreach ($ratio in @(@(0.32,0.915), @(0.47,0.94), @(0.58,0.915), @(0.65,0.905))) {
    $x = $r.Left + [int]($w * $ratio[0])
    $y = $r.Top + [int]($h * $ratio[1])
    Write-Output "ratio $($ratio[0]),$($ratio[1]) -> pixel $x,$y"
}
