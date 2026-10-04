@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
if not "%~1"=="" goto legacy
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launcher-gui.ps1"
if errorlevel 1 (
  echo Unable to open the launcher. Please extract the full ZIP and try again.
  pause
)
exit /b %errorlevel%
:legacy
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-proxy.ps1" %*
set "PROXY_EXIT=%errorlevel%"
if not "%PROXY_EXIT%"=="0" echo Launch failed. Try: setup.bat -Doctor
if not defined CLAUDE_PROXY_NO_PAUSE pause
exit /b %PROXY_EXIT%
