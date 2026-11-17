# 🛡️ BackupExternal - Universal Windows External Backup System

> **Robust, Automated, and Voice-Guided Daily Work Backup for Any Windows PC to External Drives.**

[![Platform](https://img.shields.io/badge/Platform-Windows%207%20%7C%208%20%7C%2010%20%7C%2011-blue.svg)](https://microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero%20(Pure%20Native%20Windows)-brightgreen.svg)]()

---

## 🌟 Key Capabilities

1. **Zero Third-Party Prerequisites**:
   - Built 100% on native Windows components: **PowerShell 5.1+**, **Robocopy**, **WScript.Shell**, **SAPI Text-to-Speech**, and **Windows Task Scheduler**.
   - No Python, Node.js, or external runtimes needed. Works out of the box on any fresh Windows install.

2. **Smart External Drive Detection**:
   - Automatically scans and finds your external hard drive / USB drive even if Windows shifts the drive letter (D:, E:, F:, G:, H:, etc.).
   - Matches by **Volume Label** (e.g. `My Passport`), **Storage Bus Type** (`USB`), or existing destination folder.

3. **Spoken Voice Alerts & Top-Most Pop-ups**:
   - **Drive Missing Alert**: If you click the backup shortcut and the drive is not plugged in, the system speaks:
     > *"Attention Officer! External backup drive is not connected. Please attach your external drive to continue with backup."*
     Simultaneously pops up a focused, top-most window with **[Retry]** and **[Cancel]** buttons.
   - **On Drive Connect**:
     > *"External drive detected. Starting backup now. Please wait."*
   - **On Success**:
     > *"Backup completed successfully! Officer, all files have been safely backed up to your external drive. You can now safely unplug and carry away your external drive."*
     Displays complete statistics (files, size, elapsed time).

4. **Physical Write Buffer Flushing (`Write-VolumeCache`)**:
   - Flushes all pending write caches to disk before notifying success.
   - Guarantees you can safely disconnect and carry away your external drive without file corruption.

5. **Automated Multi-Time Daily Scheduling**:
   - Automatically registers daily schedules:
     - **5:30 PM** (before departure)
     - **7:00 PM** (evening run)
     - **At User Log-in** (morning startup sync)
   - **`StartWhenAvailable = True`**: If your PC was turned off when a scheduled backup was due, Windows automatically catches up and runs the backup as soon as the computer starts up.

6. **1-Click Desktop Shortcut**:
   - Creates a dedicated icon: **`Daily Work Backup (Click to Run)`** right on your Desktop.

---

## 🚀 Quick Start & Installation

### Option 1: 1-Click Setup (Recommended)
1. Download or clone this repository to any Windows PC:
   ```cmd
   git clone https://github.com/futurefinger/BackupExternal.git
   cd BackupExternal
   ```
2. Double-click **`Install.bat`**.
3. Follow the simple on-screen prompts:
   - Source Drive / Folder (Default: `E:\` or your work folder)
   - Destination Folder Name on External Drive (Default: `Rakesh_Malik_Cyber_PC_Backup`)
   - External Drive Volume Label (e.g., `My Passport` or press Enter to auto-detect any USB drive).
4. Done! Desktop shortcuts and automated schedules are configured instantly.

### Option 2: Silent / Automated Setup
Run in PowerShell:
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -Silent -SourcePath "E:\" -DestinationFolderName "External_PC_Backup"
```

---

## ⚙️ Configuration (`src/config.json`)

You can edit `src/config.json` at any time to tailor settings:

```json
{
  "SourcePath": "E:\\",
  "DestinationFolderName": "Rakesh_Malik_Cyber_PC_Backup",
  "ExternalVolumeLabel": "My Passport",
  "ScheduleTimes": [
    "17:30",
    "19:00"
  ],
  "SyncAtLogon": true,
  "CatchUpMissedRuns": true,
  "EnableVoiceAlerts": true,
  "EnablePopups": true,
  "RobocopyThreads": 16,
  "ExcludedDirectories": [
    "$RECYCLE.BIN",
    "System Volume Information",
    "Backup_Logs"
  ],
  "ExcludedFiles": [
    "desktop.ini"
  ]
}
```

---

## 🗑️ Uninstallation

To cleanly remove BackupExternal from any computer:
1. Double-click **`Uninstall.bat`**.
2. It removes the scheduled tasks, desktop icons, and uninstalls all program files.

---

## 📂 Project Structure

```text
BackupExternal/
│
├── Install.bat             # 1-Click Setup Launcher
├── Install.ps1             # PowerShell Setup Wizard (Config & Task Scheduler)
├── Uninstall.bat           # 1-Click Uninstaller
├── Uninstall.ps1           # PowerShell Uninstaller
├── README.md               # Documentation & User Guide
├── .gitignore              # Git Ignore Rules
│
└── src/
    ├── BackupEngine.ps1    # Core multi-threaded backup & voice engine
    ├── RunBackup.bat       # Direct desktop execution script
    └── config.json         # Configurable backup preferences
```

---

## 🇮🇳 हिंदी सारांश (For Police & Cyber Cell Officers)

- **ऑटोमेटिक ड्राइव डिटेक्शन**: यह सॉफ्टवेयर एक्सटर्नल हार्ड ड्राइव को खुद पहचानता है (चाहे ड्राइव लेटर F:, G:, H: कुछ भी हो)।
- **वॉइस अलर्ट**: अगर एक्सटर्नल ड्राइव नहीं लगी होगी, तो यह बोलकर (Voice) और स्क्रीन पर अलर्ट विंडो दिखाकर बताएगा: *"Attention Officer! External backup drive is not connected..."*। जैसे ही आप ड्राइव लगाएंगे और [Retry] दबाएंगे, बैकअप शुरू हो जाएगा।
- **बैकअप सफलता व ड्राइव निकालने का अलर्ट**: बैकअप पूरा होने पर वॉइस से बोलेगा कि सभी फाइलें सुरक्षित कॉपी हो चुकी हैं और अब आप ड्राइव निकालकर अपने साथ ले जा सकते हैं।
- **डेस्कटॉप 1-क्लिक आइकन**: डेस्कटॉप पर मौजूद **`Daily Work Backup (Click to Run)`** को डबल-क्लिक करके कभी भी बैकअप कर सकते हैं।

---

## 📜 License

MIT License. Developed for Delhi Police Cyber Cell & Law Enforcement Workspaces.
