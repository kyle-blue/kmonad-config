@echo off
echo KMonad Windows Installer
echo ========================
echo.
echo This will install KMonad as a Windows service.
echo You need Administrator privileges to continue.
echo.
pause

PowerShell -Command "if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) { Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0install.ps1""' -Verb RunAs } else { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; & '%~dp0install.ps1' }"

echo.
echo Installation script completed.
pause