# screen-ocr.ps1 - wake display, capture screen, Windows built-in OCR, print text for Agent
param(
    [switch]$SkipWake = $false,
    [int]$MaxChars = 3500
)

$ErrorActionPreference = "Stop"
$wakeScript = Join-Path $PSScriptRoot "wake-screen.ps1"

if (-not $SkipWake -and (Test-Path $wakeScript)) {
    & $wakeScript | Out-Null
    Start-Sleep -Milliseconds 500
}

function Test-BitmapMostlyBlack([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width
    $h = $bmp.Height
    if ($w -lt 8 -or $h -lt 8) { return $true }
    $sum = 0L
    $samples = 0
    $stepX = [Math]::Max(1, [int]($w / 16))
    $stepY = [Math]::Max(1, [int]($h / 16))
    for ($y = 0; $y -lt $h; $y += $stepY) {
        for ($x = 0; $x -lt $w; $x += $stepX) {
            $c = $bmp.GetPixel($x, $y)
            $sum += $c.R + $c.G + $c.B
            $samples++
        }
    }
    if ($samples -eq 0) { return $true }
    return ($sum / (3.0 * $samples)) -lt 12
}

function Initialize-WinRtOcr {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Foundation, ContentType = WindowsRuntime]
    $null = [Windows.Storage.FileAccessMode, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]

    $script:WinRtAwaiter = [WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq 'GetAwaiter' -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        } | Select-Object -First 1

    if (-not $script:WinRtAwaiter) {
        throw 'WinRT GetAwaiter not found'
    }
}

function Invoke-WinRtAsync {
    param(
        [object]$AsyncOp,
        [Type]$ResultType
    )
    $awaiter = $script:WinRtAwaiter.MakeGenericMethod($ResultType).Invoke($null, @($AsyncOp))
    return $awaiter.GetResult()
}

function Get-OcrTextFromImagePath {
    param([string]$ImagePath)

    Initialize-WinRtOcr

    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if (-not $engine) {
        $langs = @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag }) -join ', '
        throw "OCR engine unavailable (install OCR language pack). Available: $langs"
    }

    $path = (Resolve-Path -LiteralPath $ImagePath).Path
    $file = Invoke-WinRtAsync ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
    $stream = Invoke-WinRtAsync ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Invoke-WinRtAsync ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Invoke-WinRtAsync ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Invoke-WinRtAsync ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])

    $lines = @($result.Lines | ForEach-Object { $_.Text } | Where-Object { $_ })
    return ($lines -join "`n")
}

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing

    $bounds = [System.Drawing.Rectangle]::Empty
    foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
        $bounds = [System.Drawing.Rectangle]::Union($bounds, $s.Bounds)
    }

    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
    $g.Dispose()

    if (Test-BitmapMostlyBlack $bitmap) {
        $bitmap.Dispose()
        Write-Host "WECHAT_FAIL: display off or black screen; wake display first"
        exit 1
    }

    $tmp = Join-Path $env:TEMP ("weclaw_ocr_{0:yyyyMMdd_HHmmss}.png" -f (Get-Date))
    $bitmap.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()

    try {
        $text = Get-OcrTextFromImagePath -ImagePath $tmp
    }
    finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }

    if (-not $text -or -not $text.Trim()) {
        Write-Host "WECHAT_OK: no text recognized (empty or wrong language pack)"
        exit 0
    }

    $text = $text.Trim()
    $lineCount = ($text -split "`n").Count
    $truncated = $false
    if ($text.Length -gt $MaxChars) {
        $text = $text.Substring(0, $MaxChars) + "`n...(truncated)"
        $truncated = $true
    }

    $suffix = ''
    if ($truncated) { $suffix = ', truncated' }
    Write-Host "WECHAT_OK: OCR $lineCount lines$suffix"
    Write-Host "--- OCR ---"
    Write-Host $text
}
catch {
    Write-Host "WECHAT_FAIL: $($_.Exception.Message)"
    exit 1
}
