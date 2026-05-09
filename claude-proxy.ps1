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
    [int]$LiteLlmPort = 0    # LiteLLM 代理端口（0 = 自动选端口）
)


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
}

# 不传 -Provider 时使用哪个
$DEFAULT_PROVIDER = "mimo"


# =================== 辅助函数 ===================

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

# ── 校验 API key ──

if ([string]::IsNullOrWhiteSpace($cfg.apiKey) -or $cfg.apiKey -eq "PASTE_YOUR_KEY_HERE") {
    Write-Host ""
    Write-Host "  [错误] Provider '$Provider' 的 API key 未设置" -ForegroundColor Red
    Write-Host "         请编辑此脚本，填入 '$Provider' 的 apiKey" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ── 如果是 OpenAI 协议，启动 LiteLLM 转换 ──

$litellmInfo = $null
$actualBaseUrl = $cfg.baseUrl
$actualApiKey  = $cfg.apiKey

if ($providerProtocol -eq "openai") {
    Write-Host ""
    Write-Host "  [信息] '$Provider' 使用 OpenAI 协议，需要 LiteLLM 做转换" -ForegroundColor Cyan

    # 检查 Python
    if (-not (Test-Python)) {
        Write-Host ""
        Write-Host "  [错误] 未检测到 Python" -ForegroundColor Red
        Write-Host "         LiteLLM 需要 Python，请先安装：" -ForegroundColor Red
        Write-Host "         https://www.python.org/downloads/" -ForegroundColor Red
        Write-Host ""
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
#  * 添加新 provider：编辑上面的 $PROVIDERS 哈希表
#
#  * OpenAI 格式的 provider 会自动通过 LiteLLM 转换，
#    首次使用会自动安装（需要 Python + pip）
#
#  * LiteLLM 日志位于 %TEMP%\litellm-*.log，出错时可查看
# ============================================================
