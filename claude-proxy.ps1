# ============================================================
#  claude-proxy.ps1
#  把 Claude Code 路由到任意 Anthropic 兼容代理（MiMo / DeepSeek / 自建等）
#
#  用法：
#    .\claude-proxy.ps1                              # 使用默认 provider
#    .\claude-proxy.ps1 -Provider mimo               # 指定 provider
#    .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx"
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
    [string]$BaseUrl,         # 自定义 provider 的 Anthropic 兼容端点
    [string]$ApiKey,          # 自定义 provider 的 API key
    [string]$Model,           # 自定义 provider 的模型名，或覆盖已有 provider 的默认模型
    [string]$SmallFastModel,  # 用于小型快速任务的模型（可选，默认跟主模型一样）
    [switch]$SharedConfig,    # 加此开关则使用 ~/.claude 共享配置，否则每个 provider 隔离
    [switch]$List,            # 列出所有已注册 provider
    [string]$WorkDir          # 启动后的工作目录
)


# =================== PROVIDER 注册表 ===================
# 在这里添加你的 provider。每个条目需要：
#   baseUrl   - Anthropic 兼容的 API 端点
#   apiKey    - 你的 API key
#   model     - 默认模型名
#   smallFast - 小型快速任务用的模型（可选，不填则跟 model 一样）
#   label     - 显示名称（仅用于 banner 展示）
#
# 添加新 provider：复制一个块，填入你的值即可。

$PROVIDERS = @{
    # ── 小米 MiMo ──
    "mimo" = @{
        baseUrl   = "https://token-plan-cn.xiaomimimo.com/anthropic"
        apiKey    = "PASTE_YOUR_MIMO_KEY_HERE"    # ← 在这里粘贴你的 MiMo API key
        model     = "mimo-v2.5-pro"
        smallFast = "mimo-v2.5-pro"
        label     = "Xiaomi MiMo"
    }

    # ── 以下为示例，取消注释并填入你的 key 即可使用 ──

    # "deepseek" = @{
    #     baseUrl   = "https://api.deepseek.com/anthropic"
    #     apiKey    = "sk-your-deepseek-key"
    #     model     = "deepseek-chat"
    #     smallFast = "deepseek-chat"
    #     label     = "DeepSeek"
    # }

    # "openrouter" = @{
    #     baseUrl   = "https://openrouter.ai/api/v1/anthropic"
    #     apiKey    = "sk-or-your-key"
    #     model     = "anthropic/claude-sonnet-4"
    #     smallFast = "anthropic/claude-sonnet-4"
    #     label     = "OpenRouter"
    # }

    # "local" = @{
    #     baseUrl   = "http://localhost:8080/anthropic"
    #     apiKey    = "not-needed"
    #     model     = "my-local-model"
    #     smallFast = "my-local-model"
    #     label     = "本地代理"
    # }
}

# 不传 -Provider 时使用哪个
$DEFAULT_PROVIDER = "mimo"


# =================== 辅助函数 ===================

# 列出所有已注册的 provider
function Show-Providers {
    Write-Host ""
    Write-Host "  可用 Provider：" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($name in $PROVIDERS.Keys | Sort-Object) {
        $p = $PROVIDERS[$name]
        $default = if ($name -eq $DEFAULT_PROVIDER) { " (默认)" } else { "" }
        Write-Host "   $name$default" -ForegroundColor Yellow -NoNewline
        Write-Host "  →  $($p.label)  [$($p.model)]" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  自定义 Provider（临时使用，无需注册）：" -ForegroundColor Cyan
    Write-Host '   .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx"' -ForegroundColor Gray
    Write-Host ""
}

# 显示用法帮助
function Show-Usage {
    Write-Host ""
    Write-Host "  用法：" -ForegroundColor Cyan
    Write-Host '   .\claude-proxy.ps1                              # 使用默认 provider' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider mimo               # 指定 provider' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -List                        # 列出所有 provider' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx"' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider mimo -Model mimo-v2-flash  # 覆盖模型' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -SharedConfig                 # 用 ~/.claude 共享配置' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -WorkDir "C:\my\project"     # 指定工作目录' -ForegroundColor Gray
    Write-Host ""
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

if ($Provider -eq "custom") {
    # 自定义 provider：必须手动指定 BaseUrl、ApiKey、Model
    if ([string]::IsNullOrWhiteSpace($BaseUrl) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Host ""
        Write-Host "  [错误] 自定义 provider 需要 -BaseUrl 和 -ApiKey 参数" -ForegroundColor Red
        Write-Host '         示例：.\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx"' -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    if ([string]::IsNullOrWhiteSpace($Model)) {
        Write-Host ""
        Write-Host "  [错误] 自定义 provider 需要 -Model 参数" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    $cfg = @{
        baseUrl   = $BaseUrl
        apiKey    = $ApiKey
        model     = $Model
        smallFast = if ($SmallFastModel) { $SmallFastModel } else { $Model }
        label     = "自定义"
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

} else {
    # 未指定 provider：使用默认
    $cfg = $PROVIDERS[$DEFAULT_PROVIDER]
    $Provider = $DEFAULT_PROVIDER
}

# 允许 -Model 覆盖已注册 provider 的默认模型
if ($Model -and -not $isCustom) {
    $cfg = @{
        baseUrl   = $cfg.baseUrl
        apiKey    = $cfg.apiKey
        model     = $Model
        smallFast = if ($SmallFastModel) { $SmallFastModel } else { $cfg.smallFast }
        label     = $cfg.label
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

# ── 设置环境变量（进程级，退出即消失）──

$env:ANTHROPIC_BASE_URL         = $cfg.baseUrl
$env:ANTHROPIC_AUTH_TOKEN       = $cfg.apiKey
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
Write-Host ""
Write-Host "  ════════ Claude Code 代理 ════════" -ForegroundColor Cyan
Write-Host "   Provider : $providerDisplay"         -ForegroundColor Green
Write-Host "   模型     : $($cfg.model)"             -ForegroundColor Green
Write-Host "   端点     : $($cfg.baseUrl)"           -ForegroundColor Green
Write-Host "   工作目录 : $(Get-Location)"           -ForegroundColor Green
if ($useIsolated) {
    Write-Host "   配置目录 : $env:CLAUDE_CONFIG_DIR (隔离)" -ForegroundColor Green
} else {
    Write-Host "   配置目录 : ~/.claude  (共享)"              -ForegroundColor Yellow
}
Write-Host "  ══════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── 启动 Claude Code ──

claude @args


# ============================================================
# 小贴士：
#  * 提示"无法加载脚本"？运行一次：
#      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#
#  * 验证代理是否生效：启动后输入 /model 查看
#
#  * 添加新 provider：编辑上面的 $PROVIDERS 哈希表
# ============================================================
