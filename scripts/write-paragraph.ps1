Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

$desktop = [Environment]::GetFolderPath("Desktop")
$docPath = Join-Path $desktop "test.docx"

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

# Read text content from a separate file
$textPath = Join-Path ([System.IO.Path]::GetTempPath()) "para.txt"
$text = [System.IO.File]::ReadAllText($textPath, [System.Text.Encoding]::UTF8)

$body = '<w:p><w:r><w:rPr><w:rFonts w:eastAsia="SimSun"/><w:sz w:val="24"/></w:rPr><w:t>' + [System.Security.SecurityElement]::Escape($text) + '</w:t></w:r></w:p>'

$docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>' + $body + '</w:body></w:document>'

$e3 = $zip.CreateEntry("word/document.xml")
$w3 = New-Object System.IO.StreamWriter($e3.Open())
$w3.Write($docXml)
$w3.Close()

$zip.Dispose()
[System.IO.File]::WriteAllBytes($docPath, $ms.ToArray())
$ms.Dispose()

Write-Host "OK: $docPath"
