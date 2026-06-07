# Install or verify PsyChip/hodor Credential Provider pipe for WeClaw unlock.
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$NoElevate
)

$ErrorActionPreference = "Stop"

$repo = "https://github.com/PsyChip/hodor.git"
$expectedCommit = "98bfbbb2c3bb74be1b4c86dfae36821535d2ea22"
$expectedDllHash = "F9477A7F1C47A01188FCA5EF4AD5E1E3AA320946C05225619701C731076534C7"
$expectedExeHash = "D699AEB8B6EAA343D575D24BAB12278CA20FD86A39A759967AA982B5ADEB4A8C"
$installDir = Join-Path $env:USERPROFILE ".weclaw\hodor"
$guid = "{E0A8C5B2-9F3D-4E7A-B1C6-8D2F5A3E9B70}"

function Test-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-HodorFiles {
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path (Split-Path $installDir -Parent) -Force | Out-Null
        git clone --depth 1 $repo $installDir
    }

    $commit = (& git -C $installDir rev-parse HEAD).Trim()
    if ($commit -ne $expectedCommit) {
        throw "hodor commit mismatch: $commit"
    }

    $dll = Join-Path $installDir "UnlockProvider.dll"
    $exe = Join-Path $installDir "test_unlock.exe"
    if (-not (Test-Path $dll) -or -not (Test-Path $exe)) {
        throw "hodor binary files missing in $installDir"
    }
    $dllHash = (Get-FileHash $dll -Algorithm SHA256).Hash
    $exeHash = (Get-FileHash $exe -Algorithm SHA256).Hash
    if ($dllHash -ne $expectedDllHash) { throw "UnlockProvider.dll hash mismatch: $dllHash" }
    if ($exeHash -ne $expectedExeHash) { throw "test_unlock.exe hash mismatch: $exeHash" }

    $manifest = [ordered]@{
        source       = $repo
        commit       = $commit
        installed_at = (Get-Date).ToString("s")
        files        = @(
            [ordered]@{ path = $dll; sha256 = $dllHash },
            [ordered]@{ path = $exe; sha256 = $exeHash }
        )
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $installDir "weclaw-hodor-manifest.json") -Encoding UTF8
}

function Test-HodorRegistered {
    $cp = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\$guid"
    $clsid = "HKLM:\SOFTWARE\Classes\CLSID\$guid\InprocServer32"
    $dllDest = "C:\Windows\System32\UnlockProvider.dll"
    $dllHash = if (Test-Path $dllDest) { (Get-FileHash $dllDest -Algorithm SHA256).Hash } else { "" }
    return [pscustomobject]@{
        CredentialProvider = Test-Path $cp
        InprocServer       = (Get-ItemProperty $clsid -ErrorAction SilentlyContinue)."(default)"
        DllExists          = Test-Path $dllDest
        DllHash            = $dllHash
        DllHashOK          = $dllHash -eq $expectedDllHash
    }
}

function Test-HodorPipe {
    try {
        $client = [System.IO.Pipes.NamedPipeClientStream]::new(".", "CredentialProviderPipe", [System.IO.Pipes.PipeDirection]::InOut)
        $client.Connect(500)
        $client.Dispose()
        return "reachable"
    } catch {
        return "not reachable now: $($_.Exception.Message)"
    }
}

Ensure-HodorFiles

if ($Install -or $Uninstall) {
    if (-not (Test-Admin)) {
        if ($NoElevate) { throw "Administrator rights required" }
        $script = if ($Install) { Join-Path $installDir "register.bat" } else { Join-Path $installDir "unregister.bat" }
        $p = Start-Process -FilePath $script -Verb RunAs -Wait -PassThru
        Write-Host "elevated script exit code: $($p.ExitCode)"
    } else {
        Push-Location $installDir
        try {
            if ($Install) { & .\register.bat } else { & .\unregister.bat }
        } finally {
            Pop-Location
        }
    }
}

$status = Test-HodorRegistered
$pipe = Test-HodorPipe
$status | Format-List
Write-Host "Pipe: $pipe"
Write-Host "Install dir: $installDir"
