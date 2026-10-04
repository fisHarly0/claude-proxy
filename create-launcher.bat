@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0new-launcher.ps1" %*
set "LAUNCH_EXIT=%errorlevel%"
if not defined CLAUDE_PROXY_NO_PAUSE pause
exit /b %LAUNCH_EXIT%
