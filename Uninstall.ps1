# ==============================================================================
# Uninstall.ps1 - Uninstaller for BackupExternal
# ==============================================================================

param (
    [switch]$Silent
)

$Host.UI.RawUI.WindowTitle = "BackupExternal - Uninstaller"
Clear-Host

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                  BACKUPEXTERNAL - UNINSTALL WIZARD                             " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Remove Scheduled Task
try {
    $taskName = "Daily_Work_Backup_Auto"
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host " [OK] Scheduled task '$taskName' removed." -ForegroundColor Green
    }
} catch {
    Write-Warning "Could not remove scheduled task: $_"
}

# Also check for legacy task name
try {
    $legacyTask = Get-ScheduledTask -TaskName "Daily_Work_Backup_Rakesh_Malik" -ErrorAction SilentlyContinue
    if ($legacyTask) {
        Unregister-ScheduledTask -TaskName "Daily_Work_Backup_Rakesh_Malik" -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host " [OK] Legacy task removed." -ForegroundColor Green
    }
} catch {}

# 2. Remove Desktop Shortcuts
$desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
if (-not (Test-Path -LiteralPath $desktopPath)) {
    $desktopPath = Join-Path $env:USERPROFILE "Desktop"
}

$lnk = Join-Path $desktopPath "Daily Work Backup (Click to Run).lnk"
$bat = Join-Path $desktopPath "Daily Work Backup (Click to Run).bat"

if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath $bat) { Remove-Item -LiteralPath $bat -Force -ErrorAction SilentlyContinue }
Write-Host " [OK] Desktop shortcuts removed." -ForegroundColor Green

# 3. Clean up installation directory if requested
$installRoot = Join-Path $env:LOCALAPPDATA "BackupExternal"
if (Test-Path -LiteralPath $installRoot) {
    if (-not $Silent) {
        Write-Host ""
        $choice = Read-Host "Do you want to delete installation files from $installRoot? (Y/N) [Default: Y]"
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match "^[Yy]") {
            Remove-Item -LiteralPath $installRoot -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host " [OK] Installation folder removed." -ForegroundColor Green
        }
    } else {
        Remove-Item -LiteralPath $installRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "               BACKUPEXTERNAL SUCCESSFULLY UNINSTALLED                          " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""

if (-not $Silent) {
    Read-Host "Press [Enter] to exit..."
}
