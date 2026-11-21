# Folder Size Trimmer

[![Version](https://img.shields.io/badge/version-0.1-blue)](https://github.com/netdaemon91/FolderSizeTrimmer)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6)](https://github.com/netdaemon91/FolderSizeTrimmer)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
![GUI](https://img.shields.io/badge/GUI-Windows%20Forms-informational)
[![Last commit](https://img.shields.io/github/last-commit/netdaemon91/FolderSizeTrimmer)](https://github.com/netdaemon91/FolderSizeTrimmer/commits/main)
[![Stars](https://img.shields.io/github/stars/netdaemon91/FolderSizeTrimmer)](https://github.com/netdaemon91/FolderSizeTrimmer/stargazers)

**A lightweight Windows utility that trims a folder to a chosen size by deleting its largest files first.**

Folder Size Trimmer scans a selected directory and all of its regular subdirectories, calculates the total file size, and prepares a deletion plan from **largest to smallest**. The plan stops as soon as the remaining total would be **strictly below** your target size. You can inspect the plan in a simple Windows Forms GUI before deciding whether to delete anything.

> [!CAUTION]
> **Deletion is permanent.** Files are removed directly, **not sent to the Recycle Bin**. Always preview the plan and test on a disposable folder first. Cancelling cannot restore files already removed.

## Features

- **Recursive scan** of files in a selected directory, including hidden files.
- **Largest-first deletion plan**, with consistent ordering when file sizes match.
- **Custom size limit** in decimal GB, accepting either a comma or period (for example, `4,5` or `4.5`).
- **Preview before deletion**, showing file sizes, names, paths, file count, and the projected remaining size.
- **Separate confirmation dialog** before any files are deleted.
- **Progress and cancellation controls** during scanning and deletion.
- **Safety checks:** rejects drive/share roots, skips symbolic links and junctions, and rechecks each file's path, size, and modification time before deletion.
- **Stop on first deletion error** instead of silently choosing additional files.
- **Post-deletion rescan** to verify the actual remaining size.
- **Deletion log** saved to the Windows temporary directory.
- Small **About** dialog with version and author details.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- .NET Windows Forms (included with supported Windows installations)

No external PowerShell modules or installation process are required. This is a **PowerShell GUI**, not a compiled `.exe`.

## Getting started

1. Download the repository using **Code → Download ZIP**, then extract it.
2. Double-click **`Start-FolderSizeTrimmer.cmd`**.
3. Choose the folder you want to analyze.
4. Enter the maximum desired folder size in GB, e.g. `4,5`.
5. Click **Analysieren** to scan the folder and review the proposed deletions.
6. Only if the preview is correct, click **Dateien löschen** and confirm the warning.

You can also launch the GUI directly from PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File ".\FolderSizeTrimmer.ps1"
```

The provided `.cmd` launcher uses the same PowerShell startup options. Review scripts before running them.

## How the size limit works

Suppose a folder contains files sized **8.5 GB, 4.2 GB, 2.8 GB, 1.5 GB, 0.8 GB, and 0.2 GB** (18.0 GB total). With a **5.0 GB** target, the planned deletions are 8.5 GB, then 4.2 GB, then 2.8 GB. The remaining total becomes **2.5 GB**, below the target.

The application uses **decimal gigabytes**: **1 GB = 1,000,000,000 bytes** (not GiB). It does not delete folders, only files. It does **not** attempt to optimize the combination of files for the closest possible remaining size; it strictly follows descending file size.

## Safety and limitations

- Scanning and previewing do **not** delete files.
- Deleted files cannot be recovered through the app or Windows Recycle Bin.
- An interrupted operation leaves previously deleted files deleted.
- Linked directories/files (junctions and symbolic links) are skipped; drive and network-share roots are not accepted.
- Locked, moved, modified, or unreadable files can interrupt the operation.
- Avoid changing the selected folder while it is being scanned or trimmed.
- The displayed sum is based on **logical file lengths**. Actual disk space reclaimed may differ for hard links, sparse files, compression, or filesystem overhead.
- The GUI has not yet been validated in an automated Windows runtime test; use the initial version cautiously.

## Repository structure

```text
FolderSizeTrimmer/
├── FolderSizeTrimmer.ps1       # Windows Forms application
├── Start-FolderSizeTrimmer.cmd # Double-click launcher
├── docs/
│   └── README_DE.txt          # German quick-start guide
└── README.md                  # English project documentation
```

## Author

**Coded by NetDaemon**

- Website: [ntdmn.xyz](https://ntdmn.xyz/)
- GitHub: [@netdaemon91](https://github.com/netdaemon91)

**Version:** 0.1
