@echo off
REM ============================================================
REM  setup.bat - Claude Proxy 一键启动（小白模式）
REM  双击即可：
REM    1) 放开 PowerShell 执行策略（仅当前用户）
REM    2) 启动 claude-proxy.ps1
REM       首次会自动检测并安装 Node.js / Claude Code / Git
REM       使用 OpenAI 协议 provider 时会自动装 Python + LiteLLM
REM       API key 第一次会弹出让你粘贴，存到 .env，下次不再问
REM
REM  也可以传参，例如：
REM    setup.bat -Provider mimo
REM    setup.bat -List
REM ============================================================

chcp 65001 >nul
setlocal

echo.
echo  ====== Claude Proxy 启动器 ======
echo.

REM 切到 .bat 所在目录，保证能找到 claude-proxy.ps1 和 .env
cd /d "%~dp0"

REM 一次性放开当前用户的执行策略（已经放开过则无副作用）
powershell -NoProfile -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -notin 'RemoteSigned','Unrestricted','Bypass') { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force }"

REM 启动主脚本，参数透传
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-proxy.ps1" %*

echo.
echo  ====== Claude 已退出 ======
pause
