@echo off
:: Right-click -> Run as administrator (once)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-wake-mobile.ps1"
pause
