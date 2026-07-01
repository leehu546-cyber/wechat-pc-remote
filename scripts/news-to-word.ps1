. (Join-Path $PSScriptRoot "utf8-console.ps1")

$desktop = [Environment]::GetFolderPath("Desktop")
$dateStr = (Get-Date).ToString("yyyy-MM-dd")
$docPath = Join-Path $desktop "今日新闻_$dateStr.docx"

$urls = @(
    "https://www.bing.com/news/search?q=%E4%B8%AD%E5%9B%BD%E6%96%B0%E9%97%BB&setlang=zh-Hans&FORM=HDRSC7",
    "https://www.bing.com/news?setlang=zh-Hans"
)

function Get-NewsTitles {
    param([string]$Content)
    $result = [System.Collections.Generic.List[string]]::new()
    $patterns = @(
        '(?<=<a[^>]*class="title"[^>]*>).*?(?=</a>)',
        '(?<=aria-label=").*?(?=")',
        '(?<=<a[^>]*data-title=").*?(?=")'
    )
    foreach ($p in $patterns) {
        $mcol = [System.Text.RegularExpressions.Regex]::Matches($Content, $p, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        foreach ($m in $mcol) {
            $title = [System.Net.WebUtility]::HtmlDecode($m.Value.Trim())
            if ($title.Length -gt 5 -and $title -notmatch '^\s*$') {
                $result.Add($title)
            }
        }
        if ($result.Count -gt 5) { break }
    }
    if ($result.Count -eq 0) {
        $lines = $Content -split "`n"
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -match '<a[^>]*>(.+?)</a>' -and $trimmed.Length -gt 20 -and $trimmed.Length -lt 200) {
                $cap = $Matches[1]
                if ($cap.Length -gt 5) { $result.Add($cap) }
            }
        }
    }
    return $result
}

$allTitles = [System.Collections.Generic.List[string]]::new()
foreach ($url in $urls) {
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        $titles = Get-NewsTitles -Content $resp.Content
        foreach ($t in $titles) {
            if (-not $allTitles.Contains($t)) { $allTitles.Add($t) }
        }
    } catch { continue }
    if ($allTitles.Count -ge 10) { break }
}

if ($allTitles.Count -lt 3) {
    Write-Host "WECHAT_FAIL: 获取新闻失败，请检查网络连接。"
    exit 1
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

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

$titleText = "今日新闻速览 - $dateStr"
$body = '<w:p><w:r><w:rPr><w:rFonts w:eastAsia="SimSun"/><w:b/><w:sz w:val="36"/></w:rPr><w:t>' + [System.Security.SecurityElement]::Escape($titleText) + '</w:t></w:r></w:p>'
$body += '<w:p><w:r><w:br/></w:r></w:p>'

$i = 1
foreach ($line in $allTitles) {
    $text = "$i. $line"
    $body += '<w:p><w:r><w:rPr><w:rFonts w:eastAsia="SimSun"/><w:sz w:val="22"/></w:rPr><w:t>' + [System.Security.SecurityElement]::Escape($text) + '</w:t></w:r></w:p>'
    $body += '<w:p><w:r><w:br/></w:r></w:p>'
    $i++
    if ($i -gt 50) { break }
}

$docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>' + $body + '</w:body></w:document>'

$e3 = $zip.CreateEntry("word/document.xml")
$w3 = New-Object System.IO.StreamWriter($e3.Open())
$w3.Write($docXml)
$w3.Close()

$zip.Dispose()
[System.IO.File]::WriteAllBytes($docPath, $ms.ToArray())
$ms.Dispose()

Start-Process -FilePath $docPath

Write-Host "WECHAT_USER_REPLY: OK，今日新闻Word文件已生成在桌面并打开。"
