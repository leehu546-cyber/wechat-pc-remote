param(
    [Parameter(Mandatory = $true)]
    [string]$App,

    [Parameter(Mandatory = $true)]
    [string]$Target,

    [Parameter(Mandatory = $false)]
    [string]$Text = "",

    [switch]$Send = $false,
    [switch]$Verify = $false,
    [switch]$ClickOnly = $false,
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\desktop-interaction.json"
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}
public class DesktopInteractWin32 {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
'@
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

function Write-Fail {
    param([string]$Reason)
    Write-Host "WECHAT_FAIL: $Reason"
    exit 1
}

function Get-Profile {
    param([object]$Config, [string]$Name)
    $props = @($Config.apps.PSObject.Properties)
    foreach ($prop in $props) {
        if ($prop.Name -ieq $Name) {
            return @{ Name = $prop.Name; Value = $prop.Value }
        }
    }
    return $null
}

function Get-TargetProfile {
    param([object]$Profile, [string]$Name)
    $props = @($Profile.targets.PSObject.Properties)
    foreach ($prop in $props) {
        if ($prop.Name -ieq $Name) {
            return @{ Name = $prop.Name; Value = $prop.Value }
        }
    }
    return $null
}

function Find-AppWindow {
    param([object]$Profile)

    $processNames = @($Profile.process | Where-Object { $_ })
    $titleParts = @($Profile.title | Where-Object { $_ })

    $matches = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        if ($_.MainWindowHandle -eq [IntPtr]::Zero) { return $false }

        $byProcess = $false
        foreach ($name in $processNames) {
            if ($_.ProcessName -ieq $name) {
                $byProcess = $true
                break
            }
        }

        $byTitle = $false
        foreach ($part in $titleParts) {
            if ($_.MainWindowTitle -like "*$part*") {
                $byTitle = $true
                break
            }
        }

        return ($byProcess -or $byTitle)
    }

    return $matches | Sort-Object StartTime -Descending | Select-Object -First 1
}

function Start-AppFromProfile {
    param([object]$Profile)

    if ($Profile.start_com) {
        $com = New-Object -ComObject $Profile.start_com
        $com.Visible = $true
        if ($Profile.start_com_document -and $com.Documents) {
            $null = $com.Documents.Add()
        }
        Start-Sleep -Seconds 2
        return
    }

    if ($Profile.start) {
        if ($Profile.start_args) {
            Start-Process -FilePath $Profile.start -ArgumentList $Profile.start_args
        } else {
            Start-Process -FilePath $Profile.start
        }
        Start-Sleep -Seconds 3
        return
    }

    Write-Fail "app_window_not_found $App"
}

function Wait-AppWindow {
    param([object]$Profile, [int]$Seconds = 15)
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $proc = Find-AppWindow -Profile $Profile
        if ($proc) { return $proc }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Save-VerificationScreenshot {
    $dir = Join-Path $env:TEMP "desktop_interaction_verify"
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $bounds = [System.Drawing.Rectangle]::Empty
    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $bounds = [System.Drawing.Rectangle]::Union($bounds, $screen.Bounds)
    }

    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
    $graphics.Dispose()

    $path = Join-Path $dir ("desktop_interact_{0:yyyyMMdd_HHmmss}.png" -f (Get-Date))
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    return $path
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    Write-Fail "config_not_found $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$profileEntry = Get-Profile -Config $config -Name $App
if (-not $profileEntry) {
    Write-Fail "app_profile_not_found $App"
}
$profile = $profileEntry.Value

$targetEntry = Get-TargetProfile -Profile $profile -Name $Target
if (-not $targetEntry) {
    Write-Fail "target_profile_missing $Target"
}
$targetProfile = $targetEntry.Value

$proc = Find-AppWindow -Profile $profile
if (-not $proc) {
    Start-AppFromProfile -Profile $profile
    $proc = Wait-AppWindow -Profile $profile
}
if (-not $proc) {
    Write-Fail "app_window_not_found $App"
}

[DesktopInteractWin32]::ShowWindowAsync($proc.MainWindowHandle, 9) | Out-Null
Start-Sleep -Milliseconds 250
[DesktopInteractWin32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 400

$rect = New-Object RECT
if (-not [DesktopInteractWin32]::GetWindowRect($proc.MainWindowHandle, [ref]$rect)) {
    Write-Fail "window_rect_unavailable $App"
}

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
    Write-Fail "invalid_window_rect $App"
}
if ($rect.Left -lt -10000 -or $rect.Top -lt -10000 -or $width -lt 200 -or $height -lt 100) {
    Write-Fail "window_rect_offscreen_or_too_small $App"
}

$xRatio = [double]$targetProfile.x_ratio
$yRatio = [double]$targetProfile.y_ratio
$clickCount = 1
if ($null -ne $targetProfile.click_count) {
    $clickCount = [int]$targetProfile.click_count
    if ($clickCount -lt 1) { $clickCount = 1 }
}
$x = $rect.Left + [int]($width * $xRatio)
$y = $rect.Top + [int]($height * $yRatio)

[DesktopInteractWin32]::SetCursorPos($x, $y) | Out-Null
Start-Sleep -Milliseconds 100
for ($i = 0; $i -lt $clickCount; $i++) {
    [DesktopInteractWin32]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [DesktopInteractWin32]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
    if ($i -lt ($clickCount - 1)) { Start-Sleep -Milliseconds 120 }
}
Start-Sleep -Milliseconds 250

if (-not $ClickOnly) {
    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-Fail "text_required"
    }
    Set-Clipboard -Value $Text
    [System.Windows.Forms.SendKeys]::SendWait("^v")
    Start-Sleep -Milliseconds 500

    if ($Send) {
        $sendKey = [string]$targetProfile.send_key
        if (-not $sendKey) { $sendKey = "{ENTER}" }
        [System.Windows.Forms.SendKeys]::SendWait($sendKey)
        Start-Sleep -Milliseconds 500
    }
}

Write-Host "WECHAT_OK: typed text into $($profileEntry.Name)/$($targetEntry.Name)"
Write-Host "WECHAT_OK: click $x,$y window=$($rect.Left),$($rect.Top),$($rect.Right),$($rect.Bottom)"

if ($Verify) {
    $shot = Save-VerificationScreenshot
    Write-Host "WECHAT_ARTIFACT: $shot"
    Write-Host "WECHAT_OK: verification screenshot saved"
}

exit 0
