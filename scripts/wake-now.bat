@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0wake-screen.ps1"
if errorlevel 1 (
    msg "%COMPUTERNAME%" Wake display failed. Check wake-screen.ps1
    exit /b 1
)
exit /b 0
