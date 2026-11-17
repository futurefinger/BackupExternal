@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BackupEngine.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Backup encountered an issue (Exit Code: %errorlevel%)
    pause
)
