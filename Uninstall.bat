@echo off
title BackupExternal - Uninstaller
setlocal
cd /d "%~dp0"
echo Launching BackupExternal Uninstaller...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
pause
