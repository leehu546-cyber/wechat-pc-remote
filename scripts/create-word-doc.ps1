Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

$desktop = [Environment]::GetFolderPath("Desktop")
$docPath = Join-Path $desktop "gmyy.docx"

$ms = New-Object System.IO.MemoryStream
$zip = [System.IO.Compression.ZipArchive]::new($ms, [System.IO.Compression.ZipArchiveMode]::Create, $false)

$rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
$e1 = $zip.CreateEntry("_rels/.rels")
$w1 = New-Object System.IO.StreamWriter($e1.Open())
$w1.Write($rels)
$w1.Close()

$cts = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
$e2 = $zip.CreateEntry("[Content_Types].xml")
$w2 = New-Object System.IO.StreamWriter($e2.Open())
$w2.Write($cts)
$w2.Close()

$body = ''
$body += '<w:p><w:r><w:rPr><w:rFonts w:eastAsia="SimSun"/><w:b/><w:sz w:val="36"/></w:rPr><w:t>' + [char]0x611F + [char]0x5192 + [char]0x662F + [char]0x4EC0 + [char]0x4E48 + [char]0x5F15 + [char]0x8D77 + [char]0x7684 + '</w:t></w:r></w:p>'

$body += '<w:p><w:r><w:br/></w:r></w:p>'

$body += '<w:p><w:r><w:rPr><w:rFonts w:eastAsia="SimSun"/><w:sz w:val="22"/></w:rPr><w:t>'
$body += [char]0x611F + [char]0x5192 + [char]0x662F + [char]0x7531 + [char]0x75C5 + [char]0x6BD2 + [char]0x611F + [char]0x67D3 + [char]0x5F15 + [char]0x8D77 + [char]0x7684 + [char]0x4E0A + [char]0x547C + [char]0x5438 + [char]0x9053 + [char]0x75BE + [char]0x75C5
$body += [char]0x3002 + [char]0x4E3B + [char]0x8981 + [char]0x5206 + [char]0x4E3A + [char]0x666E + [char]0x901A + [char]0x611F + [char]0x5192 + [char]0x548C + [char]0x6D41 + [char]0x884C + [char]0x6027 + [char]0x611F + [char]0x5192
$body += [char]0x3002 + [char]0x666E + [char]0x901A + [char]0x611F + [char]0x5192 + [char]0x591A + [char]0x7531 + [char]0x9F3B + [char]0x75C5 + [char]0x6BD2 + [char]0x3001 + [char]0x51A0 + [char]0x72B6 + [char]0x75C5 + [char]0x6BD2 + [char]0x7B49 + [char]0x5F15 + [char]0x8D77
$body += [char]0x3002 + [char]0x6D41 + [char]0x611F + [char]0x7531 + [char]0x6D41 + [char]0x611F + [char]0x75C5 + [char]0x6BD2 + [char]0x5F15 + [char]0x53D1 + [char]0x3002
$body += '</w:t></w:r></w:p>'

$texts = @(
    (1, 26, [char]0x4E00 + [char]0x3001 + [char]0x611F + [char]0x5192 + [char]0x7684 + [char]0x75C5 + [char]0x539F + [char]0x4F53),
    (0, 22, [char]0x666E + [char]0x901A + [char]0x611F + [char]0x5192 + [char]0x75C5 + [char]0x6BD2 + [char]0xFF1A + [char]0x7EA6 + '50%' + [char]0x7531 + [char]0x9F3B + [char]0x75C5 + [char]0x6BD2 + [char]0x5F15 + [char]0x8D77),
    (0, 22, [char]0x6D41 + [char]0x611F + [char]0x75C5 + [char]0x6BD2 + [char]0xFF1A + [char]0x53EF + [char]0x5F15 + [char]0x8D77 + [char]0x9AD8 + [char]0x70ED + [char]0x3001 + [char]0x808C + [char]0x8089 + [char]0x9178 + [char]0x75DB + [char]0x7B49),
    (1, 26, [char]0x4E8C + [char]0x3001 + [char]0x4F20 + [char]0x64AD + [char]0x9014 + [char]0x5F84),
    (0, 22, [char]0x98DE + [char]0x6CAB + [char]0x4F20 + [char]0x64AD + [char]0x3001 + [char]0x63A5 + [char]0x89E6 + [char]0x4F20 + [char]0x64AD + [char]0x3001 + [char]0x5BC6 + [char]0x95ED + [char]0x73AF + [char]0x5883),
    (0, 22, [char]0x513F + [char]0x7AE5 + [char]0x3001 + [char]0x8001 + [char]0x5E74 + [char]0x4EBA + [char]0x3001 + [char]0x514D + [char]0x75AB + [char]0x529B + [char]0x4F4E + [char]0x4E0B + [char]0x8005 + [char]0x66F4 + [char]0x5BB9 + [char]0x6613 + [char]0x611F + [char]0x67D3),
    (1, 26, [char]0x4E09 + [char]0x3001 + [char]0x8BF1 + [char]0x53D1 + [char]0x56E0 + [char]0x7D20),
    (0, 22, [char]0x51B7 + [char]0x7A7A + [char]0x6C14 + [char]0x3001 + [char]0x5E72 + [char]0x71E5 + [char]0x73AF + [char]0x5883 + [char]0x53EF + [char]0x524A + [char]0x5F31 + [char]0x547C + [char]0x5438 + [char]0x9053 + [char]0x9632 + [char]0x5FA1),
    (0, 22, [char]0x7B2E + [char]0x52B3 + [char]0x3001 + [char]0x8425 + [char]0x517B + [char]0x4E0D + [char]0x826F + [char]0x3001 + [char]0x5BC6 + [char]0x5207 + [char]0x63A5 + [char]0x89E6 + [char]0x611F + [char]0x67D3 + [char]0x6E90 + [char]0x589E + [char]0x52A0 + [char]0x98CE + [char]0x9669),
    (1, 26, [char]0x56DB + [char]0x3001 + [char]0x9884 + [char]0x9632 + [char]0x4E0E + [char]0x6CE8 + [char]0x610F + [char]0x4E8B + [char]0x9879),
    (0, 22, [char]0x52E4 + [char]0x6D17 + [char]0x624B + [char]0x3001 + [char]0x4FDD + [char]0x6301 + [char]0x8FD0 + [char]0x52A8 + [char]0x3001 + [char]0x5B9A + [char]0x671F + [char]0x5F00 + [char]0x7A97 + [char]0x901A + [char]0x98CE),
    (0, 22, [char]0x6D41 + [char]0x611F + [char]0x9AD8 + [char]0x53D1 + [char]0x5B63 + [char]0x907F + [char]0x514D + [char]0x4EBA + [char]0x7FA4 + [char]0x5BC6 + [char]0x96C6 + [char]0x573A + [char]0x6240)
)

foreach ($t in $texts) {
    $body += '<w:p><w:r><w:rPr><w:rFonts w:eastAsia="SimSun"/>'
    if ($t[0] -eq 1) { $body += '<w:b/>' }
    $body += '<w:sz w:val="' + $t[1] + '"/></w:rPr><w:t>' + $t[2] + '</w:t></w:r></w:p>'
}

$docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>' + $body + '</w:body></w:document>'

$e3 = $zip.CreateEntry("word/document.xml")
$w3 = New-Object System.IO.StreamWriter($e3.Open())
$w3.Write($docXml)
$w3.Close()

$zip.Dispose()
[System.IO.File]::WriteAllBytes($docPath, $ms.ToArray())
$ms.Dispose()

Write-Host "OK: $docPath"
