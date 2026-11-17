@echo off
title BackupExternal - Installer
setlocal
cd /d "%~dp0"
echo Launching BackupExternal Setup Wizard...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
pause
