$wps = New-Object -ComObject Kwps.Application
$wps.Visible = $true
$doc = $wps.Documents.Add()
$sel = $wps.Selection

$txtPath = Join-Path $PSScriptRoot "wpstext.txt"
$text = [System.IO.File]::ReadAllText($txtPath, [System.Text.Encoding]::UTF8)
$sel.TypeText($text)

$path = "D:\wps-test.docx"
try {
    $doc.SaveAs([ref] $path)
    Write-Host "saved"
} catch {
    Write-Host "SaveAs failed: $($_.Exception.Message)"
}
