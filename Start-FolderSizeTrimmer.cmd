@echo off
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0FolderSizeTrimmer.ps1"
if errorlevel 1 (
  echo.
  echo Folder Size Trimmer konnte nicht gestartet werden.
  pause
)
