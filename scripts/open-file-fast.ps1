param(
    [string]$Path,
    [ValidateSet("any", "word", "markdown", "text")]
    [string]$Kind = "any"
)

$ErrorActionPreference = "Stop"

$workspace = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$desktop = [Environment]::GetFolderPath("Desktop")

$extensions = switch ($Kind) {
    "word" { @(".docx", ".doc", ".rtf") }
    "markdown" { @(".md", ".markdown") }
    "text" { @(".txt", ".md", ".markdown") }
    default { @(".docx", ".doc", ".rtf", ".md", ".markdown", ".txt", ".pdf") }
}

function Resolve-OpenTarget {
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Candidate)
    if (Test-Path -LiteralPath $expanded -PathType Leaf) {
        return (Resolve-Path -LiteralPath $expanded).Path
    }

    $workspaceCandidate = Join-Path $workspace $expanded
    if (Test-Path -LiteralPath $workspaceCandidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $workspaceCandidate).Path
    }

    $desktopCandidate = Join-Path $desktop $expanded
    if (Test-Path -LiteralPath $desktopCandidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $desktopCandidate).Path
    }

    return $null
}

$target = Resolve-OpenTarget $Path

if (-not $target) {
    $roots = @(
        $desktop
        $workspace
        (Join-Path $workspace "docs")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $target = Get-ChildItem -LiteralPath $roots -File -ErrorAction SilentlyContinue |
        Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $target) {
    Write-Host "WECHAT_ERROR: file_not_found"
    exit 1
}

Start-Process -FilePath $target
Write-Host "WECHAT_OK: opened $target"

