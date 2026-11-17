# ==============================================================================
# Install.ps1 - Universal Windows Installer for BackupExternal
# Installs on any Windows 7 / 8 / 10 / 11 / Server machine.
# ==============================================================================

param (
    [switch]$Silent,
    [string]$SourcePath = "",
    [string]$DestinationFolderName = "",
    [string]$ExternalVolumeLabel = ""
)

$Host.UI.RawUI.WindowTitle = "BackupExternal - Windows Setup"
Clear-Host

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                  BACKUPEXTERNAL - WINDOWS SETUP WIZARD                         " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " This installer will configure automated and 1-click external drive backups" -ForegroundColor White
Write-Host " with voice alerts, auto-drive detection, and schedule catch-up on any Windows PC." -ForegroundColor White
Write-Host ""

# Determine Installation Target Directory
$installRoot = if ([System.Environment]::OSVersion.Version.Major -ge 6) {
    Join-Path $env:LOCALAPPDATA "BackupExternal"
} else {
    "C:\BackupExternal"
}

$scriptSourceDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$srcFolder = Join-Path $scriptSourceDir "src"

# Auto-detect default candidate source path
$detectedSource = "E:\"
if (-not (Test-Path -LiteralPath "E:\")) {
    if (Test-Path -LiteralPath "D:\") {
        $detectedSource = "D:\"
    } else {
        $detectedSource = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
    }
}

# Auto-detect default candidate destination folder
$detectedDestName = "Rakesh_Malik_Cyber_PC_Backup"

# Auto-detect candidate external volume label
$detectedLabel = "My Passport"
try {
    $usbVol = Get-Volume -ErrorAction SilentlyContinue | Where-Object { 
        $_.FileSystemLabel -match "Passport|Backup|External" -and $_.DriveLetter 
    } | Select-Object -First 1
    if ($usbVol) {
        $detectedLabel = $usbVol.FileSystemLabel
    }
} catch {}

# Interactive Configuration Prompt (if not silent)
if (-not $Silent) {
    Write-Host " [?] Enter Source Drive / Folder to backup:" -ForegroundColor Yellow
    Write-Host "     [Press Enter for default: $detectedSource] : " -NoNewline -ForegroundColor Gray
    $inputSource = Read-Host
    if (-not [string]::IsNullOrWhiteSpace($inputSource)) {
        $detectedSource = $inputSource.Trim('"')
    }

    Write-Host ""
    Write-Host " [?] Enter Destination Folder Name on External Drive:" -ForegroundColor Yellow
    Write-Host "     [Press Enter for default: $detectedDestName] : " -NoNewline -ForegroundColor Gray
    $inputDestName = Read-Host
    if (-not [string]::IsNullOrWhiteSpace($inputDestName)) {
        $detectedDestName = $inputDestName.Trim('"')
    }

    Write-Host ""
    Write-Host " [?] Enter External Drive Label (or press Enter to auto-detect any USB drive):" -ForegroundColor Yellow
    Write-Host "     [Press Enter for: $detectedLabel] : " -NoNewline -ForegroundColor Gray
    $inputLabel = Read-Host
    if (-not [string]::IsNullOrWhiteSpace($inputLabel)) {
        $detectedLabel = $inputLabel.Trim('"')
    }
    Write-Host ""
} else {
    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) { $detectedSource = $SourcePath }
    if (-not [string]::IsNullOrWhiteSpace($DestinationFolderName)) { $detectedDestName = $DestinationFolderName }
    if (-not [string]::IsNullOrWhiteSpace($ExternalVolumeLabel)) { $detectedLabel = $ExternalVolumeLabel }
}

Write-Host " -------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " Installing files to: $installRoot ..." -ForegroundColor Green

# 1. Create Directories & Copy Engine Files
if (-not (Test-Path -LiteralPath $installRoot)) {
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
}
$targetSrcDir = Join-Path $installRoot "src"
if (-not (Test-Path -LiteralPath $targetSrcDir)) {
    New-Item -ItemType Directory -Path $targetSrcDir -Force | Out-Null
}

Copy-Item -Path (Join-Path $srcFolder "BackupEngine.ps1") -Destination (Join-Path $targetSrcDir "BackupEngine.ps1") -Force
Copy-Item -Path (Join-Path $srcFolder "RunBackup.bat") -Destination (Join-Path $targetSrcDir "RunBackup.bat") -Force

# 2. Write customized config.json
$configObj = [PSCustomObject]@{
    SourcePath            = $detectedSource
    DestinationFolderName = $detectedDestName
    ExternalVolumeLabel   = $detectedLabel
    ScheduleTimes         = @("17:30", "19:00")
    SyncAtLogon           = $true
    CatchUpMissedRuns     = $true
    EnableVoiceAlerts     = $true
    EnablePopups          = $true
    RobocopyThreads       = 16
    ExcludedDirectories   = @('$RECYCLE.BIN', 'System Volume Information', 'Backup_Logs')
    ExcludedFiles         = @('desktop.ini')
}

$configPath = Join-Path $targetSrcDir "config.json"
$configObj | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Force

Write-Host " [OK] Engine and configuration deployed." -ForegroundColor Green

# 3. Create Desktop Shortcuts
$desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
if (-not (Test-Path -LiteralPath $desktopPath)) {
    $desktopPath = Join-Path $env:USERPROFILE "Desktop"
}

try {
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut((Join-Path $desktopPath "Daily Work Backup (Click to Run).lnk"))
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File `"$targetSrcDir\BackupEngine.ps1`""
    $shortcut.WorkingDirectory = $targetSrcDir
    $shortcut.IconLocation = "%SystemRoot%\System32\imageres.dll, 27"
    $shortcut.Description = "1-Click Backup from $detectedSource to External Drive"
    $shortcut.Save()

    # Also place direct .bat launcher on desktop
    Copy-Item -Path (Join-Path $targetSrcDir "RunBackup.bat") -Destination (Join-Path $desktopPath "Daily Work Backup (Click to Run).bat") -Force

    Write-Host " [OK] Desktop icons created:" -ForegroundColor Green
    Write-Host "      - Daily Work Backup (Click to Run).lnk" -ForegroundColor White
    Write-Host "      - Daily Work Backup (Click to Run).bat" -ForegroundColor White
} catch {
    Write-Warning "Could not create Desktop shortcuts: $_"
}

# 4. Register Windows Task Scheduler Task
try {
    $taskName = "Daily_Work_Backup_Auto"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetSrcDir\BackupEngine.ps1`" -Silent"
    
    $triggers = @(
        (New-ScheduledTaskTrigger -Daily -At 5:30PM),
        (New-ScheduledTaskTrigger -Daily -At 7:00PM),
        (New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME")
    )
    
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Force | Out-Null

    Write-Host " [OK] Windows Scheduled Task '$taskName' registered successfully." -ForegroundColor Green
    Write-Host "      - Scheduled Times: 5:30 PM & 7:00 PM daily" -ForegroundColor Gray
    Write-Host "      - Trigger at User Log-in enabled" -ForegroundColor Gray
    Write-Host "      - Catch up missed runs enabled (StartWhenAvailable = True)" -ForegroundColor Gray
} catch {
    Write-Warning "Scheduled Task registration failed (Administrator rights may be required for global task): $_"
}

# 5. Test Voice Capability
try {
    $voice = New-Object -ComObject SAPI.SpVoice
    $voice.Speak("Setup completed successfully. Backup system is ready to protect your files.", 1) | Out-Null
} catch {}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "                     INSTALLATION COMPLETE!                                     " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host " Source:           $detectedSource" -ForegroundColor White
Write-Host " Destination:      [External Drive]\$detectedDestName" -ForegroundColor White
Write-Host " Schedule:         5:30 PM, 7:00 PM, and User Log-in" -ForegroundColor White
Write-Host " Desktop Shortcut: Daily Work Backup (Click to Run)" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""

if (-not $Silent) {
    Read-Host "Press [Enter] to exit installer..."
}
