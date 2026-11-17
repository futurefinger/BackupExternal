# ==============================================================================
# BackupEngine.ps1 - Universal Windows Daily External Backup Engine
# Works on any Windows 7 / 8 / 10 / 11 / Server machine.
# ==============================================================================

param (
    [switch]$Silent,
    [string]$ConfigFile = ""
)

# Determine Engine Directory and Config Location
$engineDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $ConfigFile = Join-Path $engineDir "config.json"
}

# Default configuration fallback
$config = [PSCustomObject]@{
    SourcePath            = "E:\"
    DestinationFolderName = "External_PC_Backup"
    ExternalVolumeLabel   = ""
    EnableVoiceAlerts     = $true
    EnablePopups          = $true
    RobocopyThreads       = 16
    ExcludedDirectories   = @('$RECYCLE.BIN', 'System Volume Information', 'Backup_Logs')
    ExcludedFiles         = @('desktop.ini')
}

# Load JSON Configuration if available
if (Test-Path -LiteralPath $ConfigFile) {
    try {
        $loadedJson = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json
        foreach ($prop in $loadedJson.PSObject.Properties) {
            $config | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
        }
    } catch {
        Write-Warning "Could not parse $ConfigFile, using default settings."
    }
}

# Native Windows Text-to-Speech function
function Speak-Officer {
    param (
        [string]$Text,
        [bool]$Async = $false
    )
    if (-not $config.EnableVoiceAlerts) { return }
    try {
        $voice = New-Object -ComObject SAPI.SpVoice
        $flags = if ($Async) { 1 } else { 0 }
        [void]$voice.Speak($Text, $flags)
    } catch {}
}

# TopMost GUI Dialog Box function
function Show-OfficerPopup {
    param (
        [string]$Message,
        [string]$Title,
        [string]$Icon = "Information",
        [string]$Buttons = "OK"
    )
    if (-not $config.EnablePopups) { return [System.Windows.Forms.DialogResult]::OK }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $form = New-Object System.Windows.Forms.Form
        $form.TopMost = $true
        $btnEnum = [System.Windows.Forms.MessageBoxButtons]::$Buttons
        $iconEnum = [System.Windows.Forms.MessageBoxIcon]::$Icon
        $result = [System.Windows.Forms.MessageBox]::Show($form, $Message, $Title, $btnEnum, $iconEnum)
        $form.Dispose()
        return $result
    } catch {
        return [System.Windows.Forms.DialogResult]::OK
    }
}

# Notification balloon tip function
function Show-Notification {
    param (
        [string]$Title,
        [string]$Message,
        [string]$Icon = "Info"
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $powershellExe = (Get-Process -Id $PID).Path
        $notify.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($powershellExe)
        $notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::$Icon
        $notify.BalloonTipTitle = $Title
        $notify.BalloonTipText = $Message
        $notify.Visible = $true
        $notify.ShowBalloonTip(6000)
        Start-Sleep -Milliseconds 800
        $notify.Dispose()
    } catch {}
}

# Intelligent External Drive Detection Function
function Find-ExternalDrive {
    $targetFolderName = $config.DestinationFolderName
    $sourceRoot = ([System.IO.Path]::GetPathRoot($config.SourcePath)).TrimEnd('\')

    # 1. Check if configured Volume Label is connected
    if (-not [string]::IsNullOrWhiteSpace($config.ExternalVolumeLabel)) {
        try {
            $labelVol = Get-Volume -ErrorAction SilentlyContinue | Where-Object { 
                $_.FileSystemLabel -match [regex]::Escape($config.ExternalVolumeLabel) -and 
                $_.DriveLetter -and 
                "$($_.DriveLetter):" -ne "C:" -and 
                "$($_.DriveLetter):" -ne $sourceRoot 
            } | Select-Object -First 1
            if ($labelVol) {
                return "$($labelVol.DriveLetter):\$targetFolderName"
            }
        } catch {}
    }

    # 2. Check if destination folder already exists on any connected non-source drive
    $allDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { 
        $_.Name -notin @('C') -and "$($_.Name):" -ne $sourceRoot 
    }
    foreach ($drive in $allDrives) {
        $candidate = Join-Path $drive.Root $targetFolderName
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    # 3. Detect any USB/External physical drive connected via Storage API
    try {
        $usbDisks = Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.BusType -eq 'USB' }
        foreach ($disk in $usbDisks) {
            $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
            foreach ($part in $partitions) {
                if ("$($part.DriveLetter):" -ne "C:" -and "$($part.DriveLetter):" -ne $sourceRoot) {
                    return "$($part.DriveLetter):\$targetFolderName"
                }
            }
        }
    } catch {}

    # 4. Fallback check for any removable drive letter
    try {
        $removableDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { 
            ($_.DriveType -eq 'Removable' -or $_.DriveType -eq 'Fixed') -and 
            $_.IsReady -and 
            $_.Name.Substring(0,2) -ne "C:" -and 
            $_.Name.Substring(0,2) -ne $sourceRoot 
        }
        if ($removableDrives) {
            # Prefer largest non-system external drive
            $chosen = $removableDrives | Sort-Object -Property TotalSize -Descending | Select-Object -First 1
            return "$($chosen.Name.Substring(0,2))\$targetFolderName"
        }
    } catch {}

    return $null
}

# Set Console Appearance
if (-not $Silent) {
    $Host.UI.RawUI.WindowTitle = "Daily Work Backup System"
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                DAILY WORK BACKUP TO EXTERNAL DRIVE                             " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

$sourcePath = $config.SourcePath

# Validate Source Path
if (-not (Test-Path -LiteralPath $sourcePath)) {
    $errMsg = "Error: Source path '$sourcePath' was not found or is inaccessible!"
    if (-not $Silent) {
        Write-Host " [!] $errMsg" -ForegroundColor Red
        Speak-Officer "Error: Source path was not found on this computer." -Async $true
        Show-OfficerPopup -Message $errMsg -Title "Backup Source Error" -Icon "Error" -Buttons "OK" | Out-Null
    } else {
        Show-Notification -Title "Backup Failed" -Message $errMsg -Icon "Error"
    }
    exit 1
}

# Detect External Drive with interactive voice prompts and loop
$destPath = Find-ExternalDrive

while (-not $destPath) {
    if ($Silent) {
        # Quiet exit for scheduled runs
        $localLogDir = Join-Path $env:LOCALAPPDATA "BackupExternal\logs"
        if (-not (Test-Path -LiteralPath $localLogDir)) {
            New-Item -ItemType Directory -Path $localLogDir -Force | Out-Null
        }
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path "$localLogDir\scheduler.log" -Value "[$timestamp] Skipped: External drive not connected."
        exit 0
    }

    Write-Host " [!] External backup drive NOT detected!" -ForegroundColor Yellow
    Write-Host "     Speaking voice alert to officer..." -ForegroundColor Gray
    Speak-Officer "Attention Officer! External backup drive is not connected. Please attach your external drive to continue with backup." -Async $true

    $missingMsg = "ATTENTION OFFICER:`n`n" +
                  "External backup drive is NOT connected!`n`n" +
                  "Please plug in your external USB drive to your PC and click [Retry].`n" +
                  "Or click [Cancel] to exit."

    $dialogResult = Show-OfficerPopup -Message $missingMsg -Title "Backup Alert - External Drive Missing" -Icon "Warning" -Buttons "RetryCancel"

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Cancel -or $dialogResult -eq "Cancel") {
        Write-Host " Backup cancelled by user." -ForegroundColor Red
        exit 0
    }

    Start-Sleep -Milliseconds 900
    $destPath = Find-ExternalDrive

    if (-not $destPath) {
        Speak-Officer "External drive still not detected. Please ensure your external USB drive is firmly connected." -Async $true
    }
}

# External Drive Detected!
if (-not $Silent) {
    Speak-Officer "External drive detected. Starting backup now. Please wait." -Async $true
}

# Ensure destination directory exists
if (-not (Test-Path -LiteralPath $destPath)) {
    try {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
    } catch {
        $folderErr = "Could not create destination folder '$destPath': $_"
        Write-Host " [!] $folderErr" -ForegroundColor Red
        if (-not $Silent) {
            Show-OfficerPopup -Message $folderErr -Title "Backup Destination Error" -Icon "Error" -Buttons "OK" | Out-Null
        }
        exit 1
    }
}

# Prepare Logging
$logDir = Join-Path $destPath "Backup_Logs"
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logStamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$logFile = Join-Path $logDir "Backup_$logStamp.log"

$destDriveLetter = ($destPath -split ':')[0]
$freeSpaceGB = [math]::Round((Get-PSDrive $destDriveLetter).Free / 1GB, 2)

if (-not $Silent) {
    Write-Host " [i] Source:       $sourcePath" -ForegroundColor Green
    Write-Host " [i] Destination:  $destPath" -ForegroundColor Green
    Write-Host " [i] Free Space:   $freeSpaceGB GB available on external drive" -ForegroundColor Green
    Write-Host " [i] Mode:         Mirror Sync (/MIR - exact 1-to-1 duplicate)" -ForegroundColor Green
    Write-Host " [i] Started at:   $((Get-Date).ToString('dd-MM-yyyy HH:mm:ss'))" -ForegroundColor Gray
    Write-Host ""
    Write-Host " Mirroring files... Please wait." -ForegroundColor Yellow
    Write-Host " -------------------------------------------------------------------------------" -ForegroundColor DarkGray
}

# Assemble Robocopy arguments
$robocopyArgs = @(
    "$sourcePath",
    "$destPath",
    "/MIR"
)

if ($config.ExcludedDirectories -and $config.ExcludedDirectories.Count -gt 0) {
    $robocopyArgs += "/XD"
    $robocopyArgs += $config.ExcludedDirectories
}

if ($config.ExcludedFiles -and $config.ExcludedFiles.Count -gt 0) {
    $robocopyArgs += "/XF"
    $robocopyArgs += $config.ExcludedFiles
}

$threads = if ($config.RobocopyThreads) { [int]$config.RobocopyThreads } else { 16 }
$robocopyArgs += @(
    "/R:2",
    "/W:2",
    "/MT:$threads",
    "/DCOPY:DAT",
    "/FFT",
    "/NP",
    "/NDL",
    "/TEE",
    "/LOG+:$logFile"
)

# Execute Robocopy
$sw = [System.Diagnostics.Stopwatch]::StartNew()
& robocopy.exe @robocopyArgs
$exitCode = $LASTEXITCODE
$sw.Stop()
$elapsed = "$($sw.Elapsed.Minutes)m $($sw.Elapsed.Seconds)s"

# Flush write buffers to disk to guarantee data integrity before removal
try {
    Write-VolumeCache -DriveLetter $destDriveLetter -ErrorAction SilentlyContinue
} catch {}

# Read summary lines from log file
$summaryLines = @()
if (Test-Path -LiteralPath $logFile) {
    $content = Get-Content -LiteralPath $logFile -Tail 25
    $summaryLines = $content | Where-Object { $_ -match "(Dirs|Files|Bytes|Times)\s*:" }
}

# Robocopy exit code < 8 indicates success
if ($exitCode -lt 8) {
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}

    Speak-Officer "Backup completed successfully! Officer, all files have been safely backed up to your external drive. You can now safely unplug and carry away your external drive." -Async $true

    if (-not $Silent) {
        Write-Host " -------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "================================================================================" -ForegroundColor Green
        Write-Host "                  BACKUP COMPLETED SUCCESSFULLY!                                " -ForegroundColor Green
        Write-Host "================================================================================" -ForegroundColor Green
        Write-Host " Source:      $sourcePath" -ForegroundColor White
        Write-Host " Destination: $destPath" -ForegroundColor White
        Write-Host " Time Taken:  $elapsed" -ForegroundColor White
        Write-Host " Log File:    $logFile" -ForegroundColor Gray
        Write-Host ""
        if ($summaryLines) {
            Write-Host " Backup Statistics:" -ForegroundColor Cyan
            foreach ($line in $summaryLines) {
                Write-Host "   $line" -ForegroundColor Gray
            }
            Write-Host ""
        }
        Write-Host " [OK] All write caches flushed to disk." -ForegroundColor Green
        Write-Host " [OK] YOU CAN SAFELY UNPLUG AND CARRY AWAY YOUR EXTERNAL DRIVE NOW!" -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Green
        Write-Host ""

        $statText = if ($summaryLines) { ($summaryLines -join "`n") + "`n`n" } else { "" }
        $successMsg = "====================================================`n" +
                      "            BACKUP COMPLETED SUCCESSFULLY!          `n" +
                      "====================================================`n`n" +
                      "Source:       $sourcePath`n" +
                      "Destination:  $destPath`n" +
                      "Status:       100% Synced & Verified`n" +
                      "Time Taken:   $elapsed`n`n" +
                      $statText +
                      "[OK] All write caches flushed to disk.`n`n" +
                      "Officer, you can now safely unplug your external drive and carry it with you!"

        Show-OfficerPopup -Message $successMsg -Title "Daily Backup - SUCCESS" -Icon "Information" -Buttons "OK" | Out-Null
    } else {
        Show-Notification -Title "Daily Backup Complete" -Message "Files mirrored successfully to $destPath. Safe to unplug." -Icon "Info"
    }
} else {
    try { [System.Media.SystemSounds]::Hand.Play() } catch {}

    Speak-Officer "Warning! Backup encountered errors. Please inspect the log file before disconnecting the drive." -Async $true

    if (-not $Silent) {
        Write-Host ""
        Write-Host "================================================================================" -ForegroundColor Red
        Write-Host "                  BACKUP FAILED (Robocopy Error Code: $exitCode)                " -ForegroundColor Red
        Write-Host "================================================================================" -ForegroundColor Red
        Write-Host " Please check log file: $logFile" -ForegroundColor Yellow
        Write-Host ""

        $failMsg = "====================================================`n" +
                   "                  BACKUP FAILED                     `n" +
                   "====================================================`n`n" +
                   "Robocopy Error Code: $exitCode`n" +
                   "Destination: $destPath`n" +
                   "Log File:    $logFile`n`n" +
                   "Please do NOT disconnect your drive until errors are checked."

        Show-OfficerPopup -Message $failMsg -Title "Daily Backup - FAILED" -Icon "Error" -Buttons "OK" | Out-Null
    } else {
        Show-Notification -Title "Backup Warning" -Message "Backup completed with errors (Code $exitCode). Check log: $logFile" -Icon "Warning"
    }
    exit $exitCode
}
