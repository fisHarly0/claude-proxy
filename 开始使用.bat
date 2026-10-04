@echo off
setlocal DisableDelayedExpansion
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launcher-gui.ps1"
if errorlevel 1 (
  echo Unable to open the launcher. Please extract the full ZIP and try again.
  pause
)
