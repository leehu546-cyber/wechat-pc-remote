$path = "D:\cursor\61\scripts\cursor-delegate-task.ps1"
$tokens = $null; $errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errs)
if ($errs) { $errs | ForEach-Object { Write-Error $_.ToString() }; exit 1 }
Write-Output "parse ok"
