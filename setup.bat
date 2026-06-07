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
echo  首次使用需联网安装依赖（Node / Claude Code，OpenAI 类 provider 还需 Python+LiteLLM）。
echo  整个过程可能需要 5-10 分钟，期间窗口可能看起来没动静，这是正常的，请勿关闭窗口。
echo  （默认的 DeepSeek 走直连，无需 Python/LiteLLM，会快很多。）
echo.

REM 切到 .bat 所在目录，保证能找到 claude-proxy.ps1 和 .env
cd /d "%~dp0"

REM 一次性放开当前用户的执行策略（已经放开过则无副作用）
powershell -NoProfile -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -notin 'RemoteSigned','Unrestricted','Bypass') { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force }"

REM 启动主脚本，参数透传
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-proxy.ps1" %*
set "PROXY_EXIT=%errorlevel%"

echo.
if not "%PROXY_EXIT%"=="0" (
  echo  [提示] 启动似乎未正常完成（退出码 %PROXY_EXIT%）。
  echo         若提示"禁止运行脚本/无法加载脚本"，多半是被组策略限制，
  echo         请在 PowerShell 运行: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned 后重试。
  echo.
)
echo  ====== Claude 已退出 ======
pause
