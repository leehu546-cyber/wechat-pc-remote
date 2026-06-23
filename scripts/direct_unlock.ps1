Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait(' ')
Start-Sleep -Milliseconds 1500
$p = '123698745'
for ($i = 0; $i -lt $p.Length; $i++) {
    [System.Windows.Forms.SendKeys]::SendWait($p[$i].ToString())
    Start-Sleep -Milliseconds 80
}
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
