# ============================================================
#  claude-proxy.ps1
#  把 Claude Code 路由到任意 AI 提供商（Anthropic / OpenAI 格式均支持）
#
#  对于只提供 OpenAI 格式的 provider（如 DeepSeek、Moonshot 等），
#  脚本会自动启动 LiteLLM 做协议转换，无需手动操作。
#
#  用法：
#    .\claude-proxy.ps1                              # 使用默认 provider
#    .\claude-proxy.ps1 -Provider deepseek           # 自动启动 LiteLLM 转换
#    .\claude-proxy.ps1 -Provider mimo               # 直连（Anthropic 格式）
#    .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx" -Protocol openai
#    .\claude-proxy.ps1 -List                        # 列出所有可用 provider
#    .\claude-proxy.ps1 -Provider mimo -Model mimo-v2-flash  # 覆盖模型
#    .\claude-proxy.ps1 -SharedConfig                 # 用 ~/.claude 共享配置
#    .\claude-proxy.ps1 -WorkDir "C:\my\project"     # 指定工作目录
#
#  环境变量是进程级别的，不会污染你的全局 `claude` 命令。
# ============================================================


# =================== 命令行参数 ===================

param(
    [string]$Provider,        # provider 名称（对应下面 $PROVIDERS 的 key）
    [string]$BaseUrl,         # 自定义 provider 的 API 端点
    [string]$ApiKey,          # 自定义 provider 的 API key
    [string]$Model,           # 自定义 provider 的模型名，或覆盖已有 provider 的默认模型
    [string]$SmallFastModel,  # 用于小型快速任务的模型（可选，默认跟主模型一样）
    [string]$Protocol,        # 自定义 provider 的协议：anthropic 或 openai（默认 anthropic）
    [switch]$SharedConfig,    # 加此开关则使用 ~/.claude 共享配置，否则每个 provider 隔离
    [switch]$List,            # 列出所有已注册 provider
    [string]$WorkDir,         # 启动后的工作目录
    [int]$LiteLlmPort = 0,    # LiteLLM 代理端口（0 = 自动选端口）
    [switch]$SkipChecks,      # 跳过前置依赖检查（Node/Claude/Git/Python）
    [switch]$Update,          # 强制立即检查并应用更新（忽略 12 小时节流）
    [switch]$SkipUpdate,      # 跳过本次自动更新检查
    [int]$RelaunchCount = 0   # 【内部参数】自动重开会话的次数计数器，防死循环，用户无需手动传
)


# 顶层捕获脚本真实的绑定参数与剩余参数。
# 注意：在【函数内部】读 $PSBoundParameters / $args 拿到的是那个函数自己的参数，
# 不是主脚本的。所以重启自身时必须用这里捕获的脚本级副本来重建命令行。
$ScriptBoundParameters = $PSBoundParameters
$ScriptExtraArgs       = $args


# =================== 自动更新配置 ===================
# 版本号：发布新版时手动 +1，同时更新仓库根目录的 VERSION 文件。
$SCRIPT_VERSION = "1.1.0"
$UPDATE_REPO    = "fisHarly0/claude-proxy"   # GitHub owner/repo
$UPDATE_BRANCH  = "master"


# =================== PROVIDER 注册表 ===================
# 在这里添加你的 provider。每个条目需要：
#   baseUrl   - API 端点
#   apiKey    - 你的 API key
#   model     - 默认模型名
#   smallFast - 小型快速任务用的模型（可选，不填则跟 model 一样）
#   label     - 显示名称（仅用于 banner 展示）
#   protocol  - 协议类型：
#               "anthropic" = 原生 Anthropic 格式，直连无需转换
#               "openai"    = OpenAI 格式，脚本会自动启动 LiteLLM 做协议转换
#
# 添加新 provider：复制一个块，填入你的值即可。

$PROVIDERS = @{

    # ══════════════════════════════════════════════
    #  Anthropic 格式（直连，无需 LiteLLM）
    # ══════════════════════════════════════════════

    "mimo" = @{
        baseUrl   = "https://token-plan-cn.xiaomimimo.com/anthropic"
        apiKey    = "PASTE_YOUR_MIMO_KEY_HERE"    # ← 在这里粘贴你的 MiMo API key
        model     = "mimo-v2.5-pro"
        smallFast = "mimo-v2.5-pro"
        label     = "Xiaomi MiMo"
        protocol  = "anthropic"
    }

    # "openrouter" = @{
    #     baseUrl   = "https://openrouter.ai/api/v1/anthropic"
    #     apiKey    = "sk-or-your-key"
    #     model     = "anthropic/claude-sonnet-4"
    #     smallFast = "anthropic/claude-sonnet-4"
    #     label     = "OpenRouter"
    #     protocol  = "anthropic"
    # }

    # ══════════════════════════════════════════════
    #  OpenAI 格式（自动通过 LiteLLM 转换）
    #  首次使用会自动安装 LiteLLM（pip install litellm）
    # ══════════════════════════════════════════════

    # "gemini" = @{
    #     baseUrl   = "https://generativelanguage.googleapis.com/v1beta/openai"
    #     apiKey    = "PASTE_YOUR_GEMINI_KEY_HERE"
    #     model     = "gemini-2.5-pro"
    #     smallFast = "gemini-2.5-flash"
    #     label     = "Google Gemini"
    #     protocol  = "openai"
    # }

    # "deepseek" = @{
    #     baseUrl   = "https://api.deepseek.com/v1"
    #     apiKey    = "sk-your-deepseek-key"
    #     model     = "deepseek-chat"
    #     smallFast = "deepseek-chat"
    #     label     = "DeepSeek"
    #     protocol  = "openai"
    # }

    # "moonshot" = @{
    #     baseUrl   = "https://api.moonshot.cn/v1"
    #     apiKey    = "sk-your-moonshot-key"
    #     model     = "moonshot-v1-128k"
    #     smallFast = "moonshot-v1-8k"
    #     label     = "Moonshot (Kimi)"
    #     protocol  = "openai"
    # }

    # "zhipu" = @{
    #     baseUrl   = "https://open.bigmodel.cn/api/paas/v4"
    #     apiKey    = "your-zhipu-key"
    #     model     = "glm-4-plus"
    #     smallFast = "glm-4-flash"
    #     label     = "智谱 GLM"
    #     protocol  = "openai"
    # }

    # "qwen" = @{
    #     baseUrl   = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    #     apiKey    = "sk-your-qwen-key"
    #     model     = "qwen-max"
    #     smallFast = "qwen-turbo"
    #     label     = "通义千问"
    #     protocol  = "openai"
    # }

    # "baichuan" = @{
    #     baseUrl   = "https://api.baichuan-ai.com/v1"
    #     apiKey    = "sk-your-baichuan-key"
    #     model     = "Baichuan4"
    #     smallFast = "Baichuan3-Turbo"
    #     label     = "百川智能"
    #     protocol  = "openai"
    # }

    # "local-openai" = @{
    #     baseUrl   = "http://localhost:11434/v1"
    #     apiKey    = "not-needed"
    #     model     = "llama3"
    #     smallFast = "llama3"
    #     label     = "本地 OpenAI 兼容 (Ollama 等)"
    #     protocol  = "openai"
    # }

    # ══════════════════════════════════════════════
    #  自定义第三方（取消注释后填入你的信息）
    # ══════════════════════════════════════════════

    # "my-provider" = @{
    #     baseUrl   = "https://your-api-endpoint.com/v1"   # ← 填你的 API 地址
    #     apiKey    = "PASTE_YOUR_MY-PROVIDER_KEY_HERE"     # ← 填 key 或留占位符，首次运行会提示
    #     model     = "your-model-name"                     # ← 填模型名
    #     smallFast = "your-model-name"                     # ← 小型快速模型（可与上面相同）
    #     label     = "我的 Provider"                        # ← 显示名称，随便写
    #     protocol  = "anthropic"                           # ← anthropic 或 openai
    # }
}

# 不传 -Provider 时使用哪个
$DEFAULT_PROVIDER = "mimo"

# ── 外置自定义 provider（providers.local.ps1）──
# 在脚本同目录放一个 providers.local.ps1，里面定义 $LocalProviders 哈希表即可。
# 这些 provider 会自动合并进 $PROVIDERS，且【自动更新覆盖主脚本时不会动这个文件】。
# 可选 $LocalDefaultProvider 覆盖默认 provider。模板见 providers.local.example.ps1。
$localProviderFile = if ($PSScriptRoot) { Join-Path $PSScriptRoot "providers.local.ps1" } else { Join-Path (Get-Location) "providers.local.ps1" }
if (Test-Path $localProviderFile) {
    try {
        . $localProviderFile
        if ($LocalProviders -is [hashtable]) {
            foreach ($k in $LocalProviders.Keys) { $PROVIDERS[$k] = $LocalProviders[$k] }
        }
        if ($LocalDefaultProvider) { $DEFAULT_PROVIDER = $LocalDefaultProvider }
    } catch {
        Write-Host "  [警告] 加载 providers.local.ps1 失败：$($_.Exception.Message)" -ForegroundColor Yellow
    }
}


# =================== 辅助函数 ===================

# ── 前置依赖检查（小白模式）──

# 检查某个命令是否在 PATH 中可用
function Test-Command {
    param([string]$Name)
    $null = Get-Command $Name -ErrorAction SilentlyContinue
    return $?
}

# 刷新当前会话的 PATH（winget/npm install 之后新装的命令需要这一步才能被找到）
function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

# 根据脚本本次的真实参数，重建一份命令行参数数组（用于重启自身）。
# $Exclude 里的参数会被剔除（之后由调用方按需重新追加）。
function Build-RelaunchArgs {
    param([string[]]$Exclude = @())
    $a = @()
    foreach ($kv in $ScriptBoundParameters.GetEnumerator()) {
        if ($Exclude -contains $kv.Key) { continue }
        if ($kv.Value -is [System.Management.Automation.SwitchParameter]) {
            if ($kv.Value.IsPresent) { $a += "-$($kv.Key)" }
        } else {
            $a += "-$($kv.Key)"
            $a += "$($kv.Value)"
        }
    }
    if ($ScriptExtraArgs) { $a += $ScriptExtraArgs }
    return ,$a   # 用逗号包一层，确保始终返回数组（哪怕只有一个元素）
}

# 自动新开一个 PowerShell 会话重跑脚本，让刚装好的 winget/npm 程序进 PATH。
# 原理：winget/npm 把路径写进注册表的 Machine/User PATH，但当前进程的 PATH 是启动时的快照，
# Refresh-Path 重读注册表对多数情况够用；少数情况（尤其 winget 装 Node）必须全新进程才能拿到。
# 全新 powershell.exe 启动时会重新读注册表 PATH，所以能看到新程序——这就是这里要做的事。
# 用 $RelaunchCount 上限防死循环（最多重开 3 次，足够覆盖 Node 一次 + claude 一次的最坏情况）。
function Invoke-Relaunch {
    param([string]$Reason)

    if ($RelaunchCount -ge 3) { return $false }   # 重开够多次仍不行，交回手动提示
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { return $false }

    Write-Host ""
    Write-Host "  [环境] $Reason" -ForegroundColor Cyan
    Write-Host "  [环境] 自动新开一个会话让 PATH 生效并继续（无需手动操作）..." -ForegroundColor Cyan
    Write-Host ""

    try {
        # 重开后不再重复检查更新（节流通常已挡住，这里再保险一层），并递增重开计数
        $relaunch = Build-RelaunchArgs -Exclude @('RelaunchCount', 'SkipUpdate')
        $relaunch += "-RelaunchCount"
        $relaunch += ([string]($RelaunchCount + 1))
        $relaunch += "-SkipUpdate"
        Start-Sleep -Seconds 1
        & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @relaunch
        exit $LASTEXITCODE
    } catch {
        return $false   # 启动新进程失败，交回手动提示
    }
}

# 通过 winget 安装一个包
function Install-WithWinget {
    param([string]$PackageId, [string]$DisplayName)

    if (-not (Test-Command "winget")) {
        Write-Host "  [跳过] 未检测到 winget，无法自动安装 $DisplayName" -ForegroundColor Yellow
        Write-Host "         winget 是 Win10/11 自带的包管理器，可在 Microsoft Store 搜索 'App Installer' 安装" -ForegroundColor Gray
        return $false
    }

    Write-Host "  [安装] 通过 winget 安装 $DisplayName ($PackageId)..." -ForegroundColor Yellow
    winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [错误] $DisplayName 安装失败（winget 退出码 $LASTEXITCODE）" -ForegroundColor Red
        return $false
    }
    Refresh-Path
    Write-Host "  [完成] $DisplayName 已安装" -ForegroundColor Green
    return $true
}

# 确保 Node.js 已安装（Claude Code 的前置）
function Ensure-Node {
    if (Test-Command "node") { return $true }
    Write-Host ""
    Write-Host "  [前置] 未检测到 Node.js（Claude Code 依赖）" -ForegroundColor Cyan
    if (-not (Install-WithWinget "OpenJS.NodeJS.LTS" "Node.js LTS")) {
        Write-Host "  [手动] 请从 https://nodejs.org/ 下载 LTS 版本安装后重新运行此脚本" -ForegroundColor Red
        return $false
    }
    if (-not (Test-Command "node")) {
        # 先尝试自动新开会话（Invoke-Relaunch 成功会直接 exit，不会返回到这里）
        Invoke-Relaunch -Reason "Node.js 已安装，需要一个新会话让 PATH 生效" | Out-Null
        # 走到这说明已重开过多次仍不行，退回手动提示
        Write-Host "  [警告] Node.js 已安装但当前 PowerShell 会话仍找不到 'node' 命令" -ForegroundColor Yellow
        Write-Host "         请关闭此窗口、新开一个 PowerShell 后重新运行 setup.bat / 脚本" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# 确保 Claude Code CLI 已安装
function Ensure-ClaudeCode {
    if (Test-Command "claude") { return $true }
    Write-Host ""
    Write-Host "  [前置] 未检测到 'claude' 命令（Claude Code CLI）" -ForegroundColor Cyan
    if (-not (Ensure-Node)) { return $false }

    Write-Host "  [安装] 通过 npm 安装 Claude Code..." -ForegroundColor Yellow
    Write-Host "         npm install -g @anthropic-ai/claude-code" -ForegroundColor Gray
    npm install -g "@anthropic-ai/claude-code"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [错误] Claude Code 安装失败" -ForegroundColor Red
        Write-Host "         可手动运行: npm install -g @anthropic-ai/claude-code" -ForegroundColor Red
        return $false
    }
    Refresh-Path
    if (-not (Test-Command "claude")) {
        Invoke-Relaunch -Reason "Claude Code 已安装，需要一个新会话让 PATH 生效" | Out-Null
        Write-Host "  [警告] Claude Code 已安装但当前会话仍找不到 'claude' 命令" -ForegroundColor Yellow
        Write-Host "         请关闭此窗口、新开 PowerShell 后重新运行" -ForegroundColor Yellow
        return $false
    }
    Write-Host "  [完成] Claude Code 已安装" -ForegroundColor Green
    return $true
}

# 确保 Git 已安装（非阻塞——Claude Code 处理代码时会用到，但本脚本本身不强依赖）
function Ensure-Git {
    if (Test-Command "git") { return $true }
    Write-Host ""
    Write-Host "  [前置] 未检测到 Git（推荐安装，Claude Code 处理项目代码时会用到）" -ForegroundColor Cyan
    Install-WithWinget "Git.Git" "Git" | Out-Null
    return $true   # 不阻塞启动
}

# 确保 Python 已安装（仅 OpenAI 协议的 provider 需要，给 LiteLLM 用）
function Ensure-Python {
    if (Test-Python) { return $true }
    Write-Host ""
    Write-Host "  [前置] 未检测到 Python（LiteLLM 依赖）" -ForegroundColor Cyan
    if (-not (Install-WithWinget "Python.Python.3.12" "Python 3.12")) {
        Write-Host "  [手动] 请从 https://www.python.org/downloads/ 下载安装后重新运行" -ForegroundColor Red
        return $false
    }
    if (-not (Test-Python)) {
        Invoke-Relaunch -Reason "Python 已安装，需要一个新会话让 PATH 生效" | Out-Null
        Write-Host "  [警告] Python 已安装但当前会话仍找不到 'python' 命令" -ForegroundColor Yellow
        Write-Host "         请关闭此窗口、新开 PowerShell 后重新运行" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# ── 自动更新（多镜像顺序尝试，连不上则静默跳过）──

# 国内直连 raw.githubusercontent.com 常失败，按可达性顺序尝试多个镜像。
function Get-UpdateMirrors {
    param([string]$File)
    $repo = $UPDATE_REPO
    $br   = $UPDATE_BRANCH
    return @(
        "https://cdn.jsdelivr.net/gh/$repo@$br/$File",                              # jsdelivr CDN（国内快，但有缓存延迟）
        "https://gh-proxy.com/https://raw.githubusercontent.com/$repo/$br/$File",   # ghproxy 镜像
        "https://raw.kkgithub.com/$repo/$br/$File",                                 # kkgithub 镜像
        "https://raw.githubusercontent.com/$repo/$br/$File"                         # GitHub 官方（兜底）
    )
}

# 依次尝试各镜像下载某个文件，第一个成功就返回 @{ Content; Url }，全失败返回 $null。
function Fetch-FromMirrors {
    param([string]$File, [int]$TimeoutSec = 6)
    foreach ($url in (Get-UpdateMirrors -File $File)) {
        try {
            $resp = Invoke-WebRequest -Uri $url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
            if ($resp.StatusCode -eq 200 -and $resp.Content) {
                return @{ Content = $resp.Content; Url = $url }
            }
        } catch { continue }
    }
    return $null
}

# 自更新主流程：拉远端 VERSION 比对，更新则下载校验后替换并用新版重启。
# 任何环节失败都静默降级为"继续用当前版本"，绝不阻塞启动。
function Invoke-SelfUpdate {
    param([switch]$Force)

    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { return }
    $dir    = Split-Path -Parent $scriptPath
    $marker = Join-Path $dir ".update-check"

    # 节流：每 12 小时最多联网检查一次（-Update / -Force 忽略节流）
    if (-not $Force -and (Test-Path $marker)) {
        try {
            $lastTime = [datetime]::Parse((Get-Content $marker -Raw -ErrorAction Stop).Trim())
            if (((Get-Date) - $lastTime).TotalHours -lt 12) { return }
        } catch {}
    }

    # 拉远端版本号
    $verRes = Fetch-FromMirrors -File "VERSION" -TimeoutSec 5
    # 无论成败都记录检查时间，避免每次双击都联网
    try { (Get-Date).ToString("o") | Set-Content -Path $marker -Encoding ascii -ErrorAction SilentlyContinue } catch {}
    if (-not $verRes) { return }   # 全部镜像连不上，静默用本地版

    $remoteVer = ($verRes.Content -replace '[^\d\.]', '').Trim()
    if (-not $remoteVer) { return }
    try {
        $rv = [version]$remoteVer
        $lv = [version]$SCRIPT_VERSION
    } catch { return }
    if ($rv -le $lv) { return }   # 已是最新

    Write-Host ""
    Write-Host "  [更新] 发现新版本 v$remoteVer（当前 v$SCRIPT_VERSION），正在下载..." -ForegroundColor Cyan

    # 字节级下载到临时文件：不经过 IWR 的文本解码（避免中文乱码），并原样保留 UTF-8 BOM。
    # PS5.1 用 -File 加载含中文的 .ps1 必须有 BOM，否则按 GBK 解码会乱码崩溃，所以这里绝不能丢 BOM。
    $tmpNew = "$scriptPath.new"
    Remove-Item $tmpNew -ErrorAction SilentlyContinue
    $okDl = $false
    foreach ($url in (Get-UpdateMirrors -File "claude-proxy.ps1")) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmpNew -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop
            if ((Test-Path $tmpNew) -and (Get-Item $tmpNew).Length -gt 0) { $okDl = $true; break }
        } catch { Remove-Item $tmpNew -ErrorAction SilentlyContinue; continue }
    }
    if (-not $okDl) {
        Write-Host "  [更新] 下载失败，继续使用当前版本" -ForegroundColor Yellow
        return
    }

    # 校验：.NET 按 BOM/UTF-8 正确读取，检查内容完整（含版本标记）+ 语法可解析，
    # 防止下到半截 / 错误页面 / 被劫持的内容写坏脚本。
    $newContent = [System.IO.File]::ReadAllText($tmpNew)
    if ([string]::IsNullOrWhiteSpace($newContent) -or $newContent -notmatch '\$SCRIPT_VERSION') {
        Write-Host "  [更新] 下载内容校验失败，已跳过" -ForegroundColor Yellow
        Remove-Item $tmpNew -ErrorAction SilentlyContinue
        return
    }
    $parseErr = $null
    [void][System.Management.Automation.PSParser]::Tokenize($newContent, [ref]$parseErr)
    if ($parseErr -and $parseErr.Count -gt 0) {
        Write-Host "  [更新] 新版脚本语法校验未通过，已跳过" -ForegroundColor Yellow
        Remove-Item $tmpNew -ErrorAction SilentlyContinue
        return
    }

    # 备份旧版 + 用下载的原始字节替换自身（保留 BOM）。PowerShell 启动时已把脚本读入内存，
    # 覆盖磁盘上的 .ps1 不影响当前进程，所以可以安全替换自身。
    try {
        Copy-Item $scriptPath "$scriptPath.bak" -Force -ErrorAction SilentlyContinue
        Copy-Item $tmpNew $scriptPath -Force
        Remove-Item $tmpNew -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  [更新] 写入失败（可能无写权限），继续使用当前版本" -ForegroundColor Yellow
        return
    }

    Write-Host "  [更新] 已更新到 v$remoteVer，正在以新版本重启..." -ForegroundColor Green
    Write-Host ""

    # 用新版本重新执行（带 -SkipUpdate 防止死循环）；重启失败则回退继续当前会话
    try {
        $relaunch = Build-RelaunchArgs -Exclude @('SkipUpdate', 'Update')
        $relaunch += "-SkipUpdate"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @relaunch
        exit $LASTEXITCODE
    } catch {
        Write-Host "  [更新] 自动重启失败，本次仍用当前版本运行（下次启动即新版）" -ForegroundColor Yellow
    }
}

# ── .env 文件读写（保存 API key，下次免输入）──

function Get-DotEnvPath {
    if ($PSScriptRoot) { return (Join-Path $PSScriptRoot ".env") }
    return (Join-Path (Get-Location) ".env")
}

function Load-DotEnv {
    $envFile = Get-DotEnvPath
    $result = @{}
    if (-not (Test-Path $envFile)) { return $result }
    foreach ($line in Get-Content $envFile) {
        # 跳过空行和注释
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
            $name  = $matches[1].Trim() -replace '^﻿', ''
            $value = $matches[2]
            if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            $result[$name] = $value
        }
    }
    return $result
}

function Save-DotEnv {
    param([string]$Key, [string]$Value)
    $envFile = Get-DotEnvPath
    $existing = Load-DotEnv
    $existing[$Key] = $Value
    $lines = @("# claude-proxy 本地配置（含 API key，不要提交到 git）")
    foreach ($k in ($existing.Keys | Sort-Object)) {
        $lines += "$k=$($existing[$k])"
    }
    # 用无 BOM 的 UTF-8 写出
    [System.IO.File]::WriteAllLines($envFile, $lines, [System.Text.UTF8Encoding]::new($false))
}

# 解析某个 provider 的真实 API key：
#   1) 脚本里已经填好（非占位符） → 直接用
#   2) .env 或系统环境变量里有 <PROVIDER>_API_KEY → 用
#   3) 都没有 → 交互式提示用户粘贴，存到 .env
function Resolve-ApiKey {
    param([string]$ProviderName, [string]$CurrentValue)

    if ($CurrentValue -and $CurrentValue -notmatch '^PASTE_YOUR_.*_HERE$') {
        return $CurrentValue
    }

    $envVar = "$($ProviderName.ToUpper())_API_KEY"

    $dotenv = Load-DotEnv
    if ($dotenv.ContainsKey($envVar) -and -not [string]::IsNullOrWhiteSpace($dotenv[$envVar])) {
        return $dotenv[$envVar]
    }

    $sysVal = [System.Environment]::GetEnvironmentVariable($envVar)
    if (-not [string]::IsNullOrWhiteSpace($sysVal)) {
        return $sysVal
    }

    Write-Host ""
    Write-Host "  ════ 首次配置：需要 $ProviderName 的 API key ════" -ForegroundColor Cyan
    Write-Host "  请粘贴你的 $ProviderName API key 后回车（输入会显示但保存在本机）：" -ForegroundColor Yellow
    $key = Read-Host
    if ([string]::IsNullOrWhiteSpace($key)) {
        return $null
    }
    $key = $key.Trim()
    Save-DotEnv -Key $envVar -Value $key
    Write-Host "  [完成] 已保存到 $(Get-DotEnvPath)（下次不会再问）" -ForegroundColor Green
    Write-Host ""
    return $key
}


# 列出所有已注册的 provider
function Show-Providers {
    Write-Host ""
    Write-Host "  可用 Provider：" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($name in $PROVIDERS.Keys | Sort-Object) {
        $p = $PROVIDERS[$name]
        $default = if ($name -eq $DEFAULT_PROVIDER) { " (默认)" } else { "" }
        $proto = if ($p.protocol -eq "openai") { " [OpenAI, 自动转换]" } else { " [Anthropic, 直连]" }
        Write-Host "   $name$default" -ForegroundColor Yellow -NoNewline
        Write-Host "  →  $($p.label)  [$($p.model)]$proto" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  自定义 Provider（临时使用，无需注册）：" -ForegroundColor Cyan
    Write-Host '   .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx" -Protocol openai' -ForegroundColor Gray
    Write-Host ""
}

# 显示用法帮助
function Show-Usage {
    Write-Host ""
    Write-Host "  用法：" -ForegroundColor Cyan
    Write-Host '   .\claude-proxy.ps1                              # 使用默认 provider' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider deepseek           # OpenAI 格式，自动 LiteLLM 转换' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider mimo               # Anthropic 格式，直连' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -List                        # 列出所有 provider' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx" -Protocol openai' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider mimo -Model mimo-v2-flash  # 覆盖模型' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -SharedConfig                 # 用 ~/.claude 共享配置' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -WorkDir "C:\my\project"     # 指定工作目录' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Update                      # 强制立即检查并更新脚本' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -SkipUpdate                  # 跳过本次自动更新检查' -ForegroundColor Gray
    Write-Host ""
}

# 检查 Python / pip 是否可用
function Test-Python {
    try {
        $ver = python --version 2>&1
        if ($ver -match "Python") { return $true }
    } catch {}
    try {
        $ver = python3 --version 2>&1
        if ($ver -match "Python") { return $true }
    } catch {}
    return $false
}

# 检查 LiteLLM 是否已安装
function Test-LiteLlm {
    try {
        $result = python -c "import litellm; print('ok')" 2>&1
        if ($result -match "ok") { return $true }
    } catch {}
    return $false
}

# 安装 LiteLLM
function Install-LiteLlm {
    Write-Host "  [信息] 正在安装 LiteLLM..." -ForegroundColor Yellow
    Write-Host "         pip install litellm" -ForegroundColor Gray
    Write-Host ""
    pip install litellm
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  [错误] LiteLLM 安装失败" -ForegroundColor Red
        Write-Host "         请手动运行: pip install litellm" -ForegroundColor Red
        Write-Host ""
        return $false
    }
    return $true
}

# 找一个空闲端口
function Get-FreePort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}

# 启动 LiteLLM 代理（后台进程），返回进程对象和端口
function Start-LiteLlmProxy {
    param(
        [string]$TargetBaseUrl,
        [string]$TargetApiKey,
        [string]$TargetModel,
        [int]$Port
    )

    if ($Port -eq 0) {
        $Port = Get-FreePort
    }

    # 构造 LiteLLM 启令
    # LiteLLM 会在本地启动一个 OpenAI 兼容的代理，
    # 然后我们通过它转发请求到目标 provider
    $litellmArgs = @(
        "-m", "litellm",
        "--host", "127.0.0.1",
        "--port", $Port,
        "--model", "openai/$TargetModel",
        "--api_base", $TargetBaseUrl,
        "--api_key", $TargetApiKey
    )

    Write-Host "  [信息] 正在启动 LiteLLM 协议转换代理..." -ForegroundColor Yellow
    Write-Host "         端口: $Port" -ForegroundColor Gray
    Write-Host "         目标: $TargetBaseUrl → $TargetModel" -ForegroundColor Gray
    Write-Host ""

    # 启动后台进程
    $process = Start-Process -FilePath "python" -ArgumentList $litellmArgs `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput "$env:TEMP\litellm-$Port-stdout.log" `
        -RedirectStandardError "$env:TEMP\litellm-$Port-stderr.log"

    # 等待 LiteLLM 启动（最多等 15 秒）
    $maxWait = 15
    $waited = 0
    $ready = $false
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $ready = $true
                break
            }
        } catch {
            # 还没启动好，继续等
        }
        # 检查进程是否已退出（启动失败）
        if ($process.HasExited) {
            break
        }
    }

    if (-not $ready) {
        # 检查进程是否还活着
        if ($process.HasExited) {
            Write-Host "  [错误] LiteLLM 启动失败" -ForegroundColor Red
            $stderr = Get-Content "$env:TEMP\litellm-$Port-stderr.log" -ErrorAction SilentlyContinue
            if ($stderr) {
                Write-Host "         错误日志:" -ForegroundColor Red
                Write-Host "         $($stderr | Select-Object -Last 5 | Out-String)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [警告] LiteLLM 启动超时（${maxWait}秒），但进程仍在运行" -ForegroundColor Yellow
            Write-Host "         尝试继续连接..." -ForegroundColor Yellow
            $ready = $true
        }
    }

    if ($ready) {
        Write-Host "  [信息] LiteLLM 代理已就绪 (http://127.0.0.1:$Port)" -ForegroundColor Green
        Write-Host ""
    }

    return @{
        Process = $process
        Port    = $Port
        Ready   = $ready
    }
}

# 停止 LiteLLM 代理
function Stop-LiteLlmProxy {
    param([System.Diagnostics.Process]$Process, [int]$Port)

    if ($Process -and -not $Process.HasExited) {
        Write-Host ""
        Write-Host "  [信息] 正在停止 LiteLLM 代理..." -ForegroundColor Yellow
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
    # 清理日志文件
    Remove-Item "$env:TEMP\litellm-$Port-stdout.log" -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\litellm-$Port-stderr.log" -ErrorAction SilentlyContinue
}


# =================== 主逻辑 ===================

# 处理 -List 参数：列出 provider 后退出
if ($List) {
    Show-Providers
    exit 0
}

# 处理 -h 帮助参数
if (-not $Provider -and -not $BaseUrl -and $args -contains "-h") {
    Show-Usage
    Show-Providers
    exit 0
}

# 设置控制台 UTF-8 编码（避免中文路径乱码）
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# ── 自动更新（多镜像，连不上则静默跳过；-Update 强制，-SkipUpdate 跳过）──
if ($Update) {
    Invoke-SelfUpdate -Force
} elseif (-not $SkipUpdate) {
    Invoke-SelfUpdate
}

# ── 前置依赖检查（小白模式，加 -SkipChecks 可跳过）──

if (-not $SkipChecks) {
    if (-not (Ensure-ClaudeCode)) {
        Write-Host ""
        Write-Host "  无法继续：Claude Code CLI 不可用" -ForegroundColor Red
        exit 1
    }
    Ensure-Git | Out-Null   # 非阻塞
}

# ── 解析 provider 配置 ──

$cfg = $null
$isCustom = $false
$providerProtocol = "anthropic"

if ($Provider -eq "custom") {
    # 自定义 provider：必须手动指定参数
    if ([string]::IsNullOrWhiteSpace($BaseUrl) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Host ""
        Write-Host "  [错误] 自定义 provider 需要 -BaseUrl 和 -ApiKey 参数" -ForegroundColor Red
        Write-Host '         示例：.\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx" -Protocol openai' -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    if ([string]::IsNullOrWhiteSpace($Model)) {
        Write-Host ""
        Write-Host "  [错误] 自定义 provider 需要 -Model 参数" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    $providerProtocol = if ($Protocol) { $Protocol.ToLower() } else { "anthropic" }
    $cfg = @{
        baseUrl   = $BaseUrl
        apiKey    = $ApiKey
        model     = $Model
        smallFast = if ($SmallFastModel) { $SmallFastModel } else { $Model }
        label     = "自定义"
        protocol  = $providerProtocol
    }
    $isCustom = $true

} elseif ($Provider) {
    # 已命名 provider：从注册表查找
    if (-not $PROVIDERS.ContainsKey($Provider)) {
        Write-Host ""
        Write-Host "  [错误] 未知 provider: '$Provider'" -ForegroundColor Red
        Show-Providers
        exit 1
    }
    $cfg = $PROVIDERS[$Provider]
    $providerProtocol = if ($cfg.protocol) { $cfg.protocol } else { "anthropic" }

} else {
    # 未指定 provider：使用默认
    $cfg = $PROVIDERS[$DEFAULT_PROVIDER]
    $Provider = $DEFAULT_PROVIDER
    $providerProtocol = if ($cfg.protocol) { $cfg.protocol } else { "anthropic" }
}

# 允许 -Model 覆盖已注册 provider 的默认模型
if ($Model -and -not $isCustom) {
    $cfg = @{
        baseUrl   = $cfg.baseUrl
        apiKey    = $cfg.apiKey
        model     = $Model
        smallFast = if ($SmallFastModel) { $SmallFastModel } else { $cfg.smallFast }
        label     = $cfg.label
        protocol  = $providerProtocol
    }
}

# ── 解析 API key ──
# 顺序：脚本里已填好 → .env → 环境变量 → 交互式输入（保存到 .env）
# 自定义 provider 必须通过 -ApiKey 显式传入，前面已经校验过。

if (-not $isCustom) {
    $resolvedKey = Resolve-ApiKey -ProviderName $Provider -CurrentValue $cfg.apiKey
    if ([string]::IsNullOrWhiteSpace($resolvedKey)) {
        Write-Host ""
        Write-Host "  [错误] Provider '$Provider' 的 API key 未设置" -ForegroundColor Red
        Write-Host "         可重新运行脚本并在提示时粘贴 key，或编辑同目录 .env / 脚本内 apiKey" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    $cfg.apiKey = $resolvedKey
}

# ── 如果是 OpenAI 协议，启动 LiteLLM 转换 ──

$litellmInfo = $null
$actualBaseUrl = $cfg.baseUrl
$actualApiKey  = $cfg.apiKey

if ($providerProtocol -eq "openai") {
    Write-Host ""
    Write-Host "  [信息] '$Provider' 使用 OpenAI 协议，需要 LiteLLM 做转换" -ForegroundColor Cyan

    # 检查 / 安装 Python（LiteLLM 依赖）
    if (-not $SkipChecks) {
        if (-not (Ensure-Python)) {
            Write-Host ""
            Write-Host "  无法继续：Python 不可用，OpenAI 协议 provider 需要 Python 跑 LiteLLM" -ForegroundColor Red
            exit 1
        }
    } elseif (-not (Test-Python)) {
        Write-Host ""
        Write-Host "  [错误] 未检测到 Python（已 -SkipChecks，不自动安装）" -ForegroundColor Red
        Write-Host "         请安装 Python: https://www.python.org/downloads/" -ForegroundColor Red
        exit 1
    }

    # 检查 / 安装 LiteLLM
    if (-not (Test-LiteLlm)) {
        Write-Host "  [信息] LiteLLM 未安装，正在自动安装..." -ForegroundColor Yellow
        if (-not (Install-LiteLlm)) {
            exit 1
        }
    }

    # 启动 LiteLLM 代理
    $litellmInfo = Start-LiteLlmProxy `
        -TargetBaseUrl $cfg.baseUrl `
        -TargetApiKey $cfg.apiKey `
        -TargetModel $cfg.model `
        -Port $LiteLlmPort

    if (-not $litellmInfo.Ready) {
        Write-Host "  [错误] LiteLLM 代理未能启动" -ForegroundColor Red
        exit 1
    }

    # Claude Code 连接 LiteLLM 本地代理（Anthropic 格式）
    $actualBaseUrl = "http://127.0.0.1:$($litellmInfo.Port)"
    $actualApiKey  = "litellm-proxy"  # LiteLLM 本地不需要真实 key
}

# ── 设置环境变量（进程级，退出即消失）──

$env:ANTHROPIC_BASE_URL         = $actualBaseUrl
$env:ANTHROPIC_AUTH_TOKEN       = $actualApiKey
$env:ANTHROPIC_MODEL            = $cfg.model
$env:ANTHROPIC_SMALL_FAST_MODEL = $cfg.smallFast

# ── 配置目录：默认每个 provider 隔离，加 -SharedConfig 则共享 ~/.claude ──

$useIsolated = -not $SharedConfig
if ($useIsolated) {
    $configDir = "$env:USERPROFILE\.claude-$Provider"
    $env:CLAUDE_CONFIG_DIR = $configDir
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
}

# ── 切换工作目录（如果指定了 -WorkDir）──

if ($WorkDir) {
    if (Test-Path $WorkDir) {
        Set-Location $WorkDir
    } else {
        Write-Host ""
        Write-Host "  [错误] 工作目录不存在: $WorkDir" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}

# ── 显示启动信息 ──

$providerDisplay = if ($isCustom) { "自定义 ($($cfg.baseUrl))" } else { "$Provider ($($cfg.label))" }
$protocolDisplay = if ($providerProtocol -eq "openai") { "OpenAI → LiteLLM → Anthropic" } else { "Anthropic (直连)" }
Write-Host ""
Write-Host "  ════════ Claude Code 代理 ════════" -ForegroundColor Cyan
Write-Host "   版本     : v$SCRIPT_VERSION"          -ForegroundColor Green
Write-Host "   Provider : $providerDisplay"         -ForegroundColor Green
Write-Host "   模型     : $($cfg.model)"             -ForegroundColor Green
Write-Host "   协议     : $protocolDisplay"          -ForegroundColor Green
if ($litellmInfo) {
    Write-Host "   LiteLLM  : http://127.0.0.1:$($litellmInfo.Port)" -ForegroundColor Green
} else {
    Write-Host "   端点     : $actualBaseUrl"         -ForegroundColor Green
}
Write-Host "   工作目录 : $(Get-Location)"           -ForegroundColor Green
if ($useIsolated) {
    Write-Host "   配置目录 : $env:CLAUDE_CONFIG_DIR (隔离)" -ForegroundColor Green
} else {
    Write-Host "   配置目录 : ~/.claude  (共享)"              -ForegroundColor Yellow
}
Write-Host "  ══════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── 启动 Claude Code ──

try {
    claude @args
} finally {
    # ── 清理：退出时停止 LiteLLM 代理 ──
    if ($litellmInfo) {
        Stop-LiteLlmProxy -Process $litellmInfo.Process -Port $litellmInfo.Port
    }
}


# ============================================================
# 小贴士：
#  * 提示"无法加载脚本"？运行一次：
#      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#
#  * 验证代理是否生效：启动后输入 /model 查看
#
#  * 添加新 provider：复制 providers.local.example.ps1 为 providers.local.ps1
#    并填入你的 provider。自动更新不会覆盖这个文件。
#
#  * 更新脚本：默认每 12 小时自动检查；手动立即更新加 -Update；
#    跳过加 -SkipUpdate。更新只替换 claude-proxy.ps1 本身，
#    你的 .env 和 providers.local.ps1 都不会被动。
#
#  * OpenAI 格式的 provider 会自动通过 LiteLLM 转换，
#    首次使用会自动安装（需要 Python + pip）
#
#  * LiteLLM 日志位于 %TEMP%\litellm-*.log，出错时可查看
# ============================================================
