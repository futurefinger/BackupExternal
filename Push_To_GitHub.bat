@echo off
title Push BackupExternal to GitHub
cd /d "%~dp0"
echo =====================================================================
echo                Pushing BackupExternal to GitHub
echo =====================================================================
echo Remote: https://github.com/futurefinger/BackupExternal.git
echo.
git push -u origin main
echo.
if %errorlevel% equ 0 (
    echo [SUCCESS] Repository pushed to GitHub successfully!
) else (
    echo [NOTICE] If prompted, please complete GitHub sign-in above.
)
echo.
pause
