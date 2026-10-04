# ============================================================
#  claude-proxy.ps1
#  多 API 独立 Claude Code 启动器；Anthropic 兼容直连，OpenAI 转换为实验功能。
#
#  默认 provider 是 DeepSeek，走官方 Anthropic 协议直连，无需 LiteLLM / Python。
#  对于只提供 OpenAI 格式的 provider（如 Moonshot、智谱、通义 等），
#  脚本会启动 LiteLLM 尝试协议转换，需另行验证流式输出和工具调用兼容性。
#
#  用法：
#    .\claude-proxy.ps1                              # 使用默认 provider（deepseek，直连）
#    .\claude-proxy.ps1 -Provider mimo               # 切到 MiMo（Anthropic 格式直连）
#    .\claude-proxy.ps1 -Provider moonshot           # OpenAI 格式，自动启动 LiteLLM 转换
#    .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx" -Protocol openai
#    .\claude-proxy.ps1 -List                        # 列出所有可用 provider
#    .\claude-proxy.ps1 -Help                        # 显示用法帮助
#    .\claude-proxy.ps1 -Doctor                      # 一键体检环境（新电脑部署先跑这个）
#    .\claude-proxy.ps1 -Provider deepseek -Model deepseek-v4-flash  # 覆盖模型
#    .\claude-proxy.ps1 -SharedConfig                # 用 ~/.claude 共享配置
#    .\claude-proxy.ps1 -WorkDir "C:\my\project"     # 指定工作目录
#    .\claude-proxy.ps1 -Update                      # 手动下载并应用脚本更新
#
#  环境变量是进程级别的，不会污染你的全局 `claude` 命令。
# ============================================================


# =================== 命令行参数 ===================

param(
    [string]$Provider,        # provider 名称（对应下面 $PROVIDERS 的 key）
    [string]$BaseUrl,         # 自定义 provider 的 API 端点，或覆盖已注册 provider
    [string]$ApiKey,          # 自定义 provider 的 API key，或覆盖已注册 provider
    [string]$Model,           # 自定义 provider 的模型名，或覆盖已有 provider 的默认模型
    [string]$SmallFastModel,  # 用于小型快速任务的模型（可选，默认跟主模型一样）
    [string]$Protocol,        # 自定义/覆盖 provider 的协议：anthropic 或 openai
    [switch]$SharedConfig,    # 加此开关则使用 ~/.claude 共享配置，否则每个 provider 隔离
    [string]$InstanceDir,     # 生成器创建的实例目录，配置与 key 均独立
    [switch]$PrepareOnly,     # 图形入口后台准备依赖，完成后退出，不启动会话
    [switch]$List,            # 列出所有已注册 provider
    [switch]$Doctor,          # 一键体检环境/网络/编码，不启动 Claude
    [Alias('h')]
    [switch]$Help,            # 显示用法帮助（-h 同义）
    [string]$WorkDir,         # 启动后的工作目录
    [int]$LiteLlmPort = 0,    # LiteLLM 代理端口（0 = 自动选端口）
    [switch]$SkipChecks,      # 跳过前置依赖检查（Node/Claude/Git/Python）
    [switch]$Update,          # 手动下载并应用脚本更新（默认只提示不自动更新）
    [switch]$SkipUpdate,      # 跳过本次更新检查
    [int]$RelaunchCount = 0   # 【内部参数】自动重开会话的次数计数器，防死循环，用户无需手动传
)


# 顶层捕获脚本真实的绑定参数与剩余参数。
# 注意：在【函数内部】读 $PSBoundParameters / $args 拿到的是那个函数自己的参数，
# 不是主脚本的。所以重启自身时必须用这里捕获的脚本级副本来重建命令行。
$ScriptBoundParameters = $PSBoundParameters
$ScriptExtraArgs       = $args


# 控制台 UTF-8 编码：尽早设置，保证后续任何中文输出（含 providers.local 加载警告）都不乱码。
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}


# =================== 自动更新配置 ===================
# 版本号：发布新版时手动 +1，同时更新仓库根目录的 VERSION 文件。
$SCRIPT_VERSION = "1.5.0"
$UPDATE_REPO    = "fisHarly0/claude-proxy"   # GitHub owner/repo
$UPDATE_BRANCH  = "master"


# =================== PROVIDER 注册表 ===================
# 在这里添加你的 provider。每个条目需要：
#   baseUrl   - API 端点
#   apiKey    - 你的 API key（可留占位符 PASTE_YOUR_xxx_HERE，首次运行会提示粘贴）
#   model     - 默认模型名
#   smallFast - 小型快速任务用的模型（可选，不填则跟 model 一样）
#   label     - 显示名称（仅用于 banner 展示）
#   protocol  - 协议类型：
#               "anthropic" = 原生 Anthropic 格式，直连无需转换
#               "openai"    = OpenAI 格式，脚本会自动启动 LiteLLM 做协议转换
#   signupUrl - （可选）申请 API key 的网址，没填好 key 时会打印给用户做引导
#
# 推荐做法：不要在本文件里加 provider（自动更新会覆盖本文件）。
# 复制 providers.local.example.ps1 为 providers.local.ps1，在那里加，更新不会动它。

$PROVIDERS = @{

    # ══════════════════════════════════════════════
    #  Anthropic 格式（直连，无需 LiteLLM / Python）
    # ══════════════════════════════════════════════

    "deepseek" = @{
        baseUrl   = "https://api.deepseek.com/anthropic"   # DeepSeek 官方 Anthropic 协议端点
        apiKey    = "PASTE_YOUR_DEEPSEEK_KEY_HERE"          # ← 首次运行会提示粘贴，存到 .env
        model     = "deepseek-v4-pro"                        # 主模型（对标 Opus）
        smallFast = "deepseek-v4-flash"                      # 小型快速任务模型（对标 Haiku）
        label     = "DeepSeek"
        protocol  = "anthropic"
        signupUrl = "https://platform.deepseek.com/api_keys"
    }

    "mimo" = @{
        baseUrl   = "https://token-plan-cn.xiaomimimo.com/anthropic"
        apiKey    = "PASTE_YOUR_MIMO_KEY_HERE"
        model     = "mimo-v2.5-pro"
        smallFast = "mimo-v2.5-pro"
        label     = "Xiaomi MiMo"
        protocol  = "anthropic"
        # signupUrl = "..."   # 注册/拿 key 地址请到小米 MiMo 平台确认后填写
    }

    # "openrouter" = @{
    #     baseUrl   = "https://openrouter.ai/api/v1/anthropic"
    #     apiKey    = "PASTE_YOUR_OPENROUTER_KEY_HERE"
    #     model     = "anthropic/claude-sonnet-4"
    #     smallFast = "anthropic/claude-sonnet-4"
    #     label     = "OpenRouter"
    #     protocol  = "anthropic"
    #     signupUrl = "https://openrouter.ai/keys"
    # }

    # ══════════════════════════════════════════════
    #  OpenAI 格式（自动通过 LiteLLM 转换）
    #  首次使用会自动安装 LiteLLM proxy 依赖（需要 Python）
    # ══════════════════════════════════════════════

    # "gemini" = @{
    #     baseUrl   = "https://generativelanguage.googleapis.com/v1beta/openai"
    #     apiKey    = "PASTE_YOUR_GEMINI_KEY_HERE"
    #     model     = "gemini-2.5-pro"
    #     smallFast = "gemini-2.5-flash"
    #     label     = "Google Gemini"
    #     protocol  = "openai"
    #     signupUrl = "https://aistudio.google.com/apikey"
    # }

    # "moonshot" = @{
    #     baseUrl   = "https://api.moonshot.cn/v1"
    #     apiKey    = "PASTE_YOUR_MOONSHOT_KEY_HERE"
    #     model     = "moonshot-v1-128k"
    #     smallFast = "moonshot-v1-8k"
    #     label     = "Moonshot (Kimi)"
    #     protocol  = "openai"
    #     signupUrl = "https://platform.moonshot.cn/console/api-keys"
    # }

    # "zhipu" = @{
    #     baseUrl   = "https://open.bigmodel.cn/api/paas/v4"
    #     apiKey    = "PASTE_YOUR_ZHIPU_KEY_HERE"
    #     model     = "glm-4-plus"
    #     smallFast = "glm-4-flash"
    #     label     = "智谱 GLM"
    #     protocol  = "openai"
    #     signupUrl = "https://open.bigmodel.cn/usercenter/apikeys"
    # }

    # "qwen" = @{
    #     baseUrl   = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    #     apiKey    = "PASTE_YOUR_QWEN_KEY_HERE"
    #     model     = "qwen-max"
    #     smallFast = "qwen-turbo"
    #     label     = "通义千问"
    #     protocol  = "openai"
    #     signupUrl = "https://dashscope.console.aliyun.com/apiKey"
    # }

    # "baichuan" = @{
    #     baseUrl   = "https://api.baichuan-ai.com/v1"
    #     apiKey    = "PASTE_YOUR_BAICHUAN_KEY_HERE"
    #     model     = "Baichuan4"
    #     smallFast = "Baichuan3-Turbo"
    #     label     = "百川智能"
    #     protocol  = "openai"
    #     signupUrl = "https://platform.baichuan-ai.com"
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
$DEFAULT_PROVIDER = "deepseek"

# ── 外置自定义 provider（providers.local.ps1）──
# 在脚本同目录放一个 providers.local.ps1，里面定义 $LocalProviders 哈希表即可。
# 这些 provider 会自动合并进 $PROVIDERS，且【自动更新覆盖主脚本时不会动这个文件】。
# 可选 $LocalDefaultProvider 覆盖默认 provider。模板见 providers.local.example.ps1。
$localProviderFile = if ($PSScriptRoot) { Join-Path $PSScriptRoot "providers.local.ps1" } else { Join-Path (Get-Location) "providers.local.ps1" }
if (-not $InstanceDir -and (Test-Path $localProviderFile)) {
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
    Write-Host "  [环境] 正在本窗口内用新会话重跑，让 PATH 生效并继续（无需手动操作，请勿关闭窗口）..." -ForegroundColor Cyan
    Write-Host ""

    try {
        # 重开后不再重复检查更新（节流通常已挡住，这里再保险一层），并递增重开计数
        $relaunch = Build-RelaunchArgs -Exclude @('RelaunchCount', 'SkipUpdate', 'Update')
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
        Write-Host "         修复（任选其一）：" -ForegroundColor Gray
        Write-Host "           1) 打开 Microsoft Store，搜索并安装 'App Installer'" -ForegroundColor Gray
        Write-Host "           2) 直接去官网手动安装（见下方 [手动] 提示）" -ForegroundColor Gray
        return $false
    }

    Write-Host "  [安装] 通过 winget 安装 $DisplayName ($PackageId)..." -ForegroundColor Yellow
    Write-Host "         首次安装可能需要 1-5 分钟，国内网络下窗口可能看起来没动静，这是正常的，请勿关闭窗口" -ForegroundColor Gray
    winget install --id $PackageId --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [错误] $DisplayName 安装失败（winget 退出码 $LASTEXITCODE）" -ForegroundColor Red
        Write-Host "         常见原因：无管理员权限 / 公司电脑被策略限制 / 网络到 Microsoft 源不通" -ForegroundColor Gray
        Write-Host "         修复：改用手动安装（见下方 [手动] 提示），装完重新双击 setup.bat" -ForegroundColor Gray
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
        Write-Host "  [手动] 请从 https://nodejs.org/ 下载 LTS 版本安装（Windows x64 .msi）" -ForegroundColor Red
        Write-Host "         国内可试镜像: https://npmmirror.com/mirrors/node/" -ForegroundColor Gray
        Write-Host "         装完后重新双击 setup.bat" -ForegroundColor Gray
        return $false
    }
    if (-not (Test-Command "node")) {
        # 先尝试自动新开会话（Invoke-Relaunch 成功会直接 exit，不会返回到这里）
        Invoke-Relaunch -Reason "Node.js 已安装，需要一个新会话让 PATH 生效" | Out-Null
        # 走到这说明已重开过多次仍不行，退回手动提示
        Write-Host "  [警告] Node.js 已安装但当前会话仍找不到 'node' 命令" -ForegroundColor Yellow
        Write-Host "         请关闭此窗口，重新双击 setup.bat（无需自己开 PowerShell）" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# 探测当前 npm 全局前缀下的 claude 是否可用（winget/npm 装完 PATH 常有延迟）
function Get-NpmGlobalBin {
    if (-not (Test-Command "npm")) { return $null }
    try {
        $prefix = (npm prefix -g 2>$null | Select-Object -Last 1)
        if ($prefix) {
            $bin = Join-Path $prefix "claude.cmd"
            if (Test-Path $bin) { return $bin }
            $binPs = Join-Path $prefix "claude.ps1"
            if (Test-Path $binPs) { return $binPs }
        }
    } catch {}
    return $null
}

# 通过 npm 安装 Claude Code；默认源失败时自动切国内镜像再试
function Install-ClaudeCodeCli {
    if (-not (Test-Command "npm")) {
        Write-Host "  [错误] 未找到 npm，无法安装 Claude Code（请先装好 Node.js）" -ForegroundColor Red
        return $false
    }

    $pkg = "@anthropic-ai/claude-code"
    $attempts = @(
        @{ Label = "默认 npm 源";       RegArgs = @() },
        @{ Label = "国内 npmmirror 镜像"; RegArgs = @("--registry", "https://registry.npmmirror.com") }
    )

    foreach ($a in $attempts) {
        Write-Host "  [安装] 通过 npm 安装 Claude Code（$($a.Label)）..." -ForegroundColor Yellow
        Write-Host "         npm install -g $pkg$(@($a.RegArgs) -join ' ')" -ForegroundColor Gray
        Write-Host "         国内网络可能较慢（1-5 分钟），请勿关闭窗口" -ForegroundColor Gray
        $npmArgs = @("install", "-g", $pkg) + $a.RegArgs
        & npm @npmArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [完成] Claude Code 已通过 $($a.Label) 安装" -ForegroundColor Green
            return $true
        }
        Write-Host "  [警告] $($a.Label) 安装失败（退出码 $LASTEXITCODE）" -ForegroundColor Yellow
    }

    Write-Host "  [错误] Claude Code 自动安装失败" -ForegroundColor Red
    Write-Host "         可手动执行任一命令后再双击 setup.bat：" -ForegroundColor Yellow
    Write-Host "           npm install -g $pkg --registry https://registry.npmmirror.com" -ForegroundColor Gray
    Write-Host "           npm install -g $pkg" -ForegroundColor Gray
    return $false
}

# 安装后做一次版本冒烟，避免"装了但命令不可用/半残包"
function Test-ClaudeSmoke {
    if (-not (Test-Command "claude")) { return $false }
    try {
        $ver = & claude --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $ver) {
            Write-Host "  [冒烟] Claude Code 可用：$("$ver" | Select-Object -First 1)" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "  [警告] claude 命令存在但 --version 失败，可能安装不完整" -ForegroundColor Yellow
    return $false
}

# 确保 Claude Code CLI 已安装
function Ensure-ClaudeCode {
    if (Test-Command "claude") {
        if (Test-ClaudeSmoke) { return $true }
    }
    # 原生安装不依赖 Node；先检查已安装但尚未加入 PATH 的官方目录。
    $nativeBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path -LiteralPath (Join-Path $nativeBin 'claude.exe')) {
        $env:PATH = "$nativeBin;$env:PATH"
        if (Test-ClaudeSmoke) { return $true }
    }
    if (Install-ClaudeNative) { return $true }
    Write-Host ""
    Write-Host "  [前置] 未检测到 'claude' 命令（Claude Code CLI）" -ForegroundColor Cyan

    # npm 全局目录里可能已经有，只是 PATH 还没刷新
    $npmBin = Get-NpmGlobalBin
    if ($npmBin -and (Test-Path $npmBin)) {
        Write-Host "  [环境] 在 npm 全局目录发现了 claude，刷新 PATH..." -ForegroundColor Cyan
        Refresh-Path
        Invoke-Relaunch -Reason "找到已安装的 Claude Code，需要新会话让 PATH 生效" | Out-Null
    }

    if (-not (Ensure-Node)) { return $false }

    if (-not (Install-ClaudeCodeCli)) {
        return $false
    }
    Refresh-Path
    if (-not (Test-Command "claude")) {
        # npm prefix 兜底：有时装好了但当前会话 PATH 仍没有
        $npmBin2 = Get-NpmGlobalBin
        if ($npmBin2) {
            Write-Host "  [环境] 尝试用 npm 全局路径直接调用..." -ForegroundColor Gray
        }
        Invoke-Relaunch -Reason "Claude Code 已安装，需要一个新会话让 PATH 生效" | Out-Null
        Write-Host "  [警告] Claude Code 已安装但当前会话仍找不到 'claude' 命令" -ForegroundColor Yellow
        Write-Host "         请关闭此窗口，重新双击 setup.bat（无需自己开 PowerShell）" -ForegroundColor Yellow
        Write-Host "         若仍失败，运行  .\claude-proxy.ps1 -Doctor  查看详细诊断" -ForegroundColor Gray
        return $false
    }
    Test-ClaudeSmoke | Out-Null
    return $true
}

# 安装逻辑依据官方 install.ps1 审阅实现；不下载执行 PowerShell 脚本。
function Install-ClaudeNative {
    if (-not [Environment]::Is64BitProcess) { return $false }
    $binaryPath = $null
    try {
        $cacheRoot = if ($env:CLAUDE_PROXY_CACHE_DIR) { $env:CLAUDE_PROXY_CACHE_DIR } elseif ($InstanceDir) { Join-Path $InstanceDir '.cache' } else { Join-Path $PSScriptRoot '.cache' }
        [IO.Directory]::CreateDirectory($cacheRoot) | Out-Null
        $base = 'https://downloads.claude.ai/claude-code-releases'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-Host '  [安装] 正在下载 Claude Code 原生程序，无需预装 Node.js…'
        $version = ([string](Invoke-RestMethod -Uri "$base/latest" -TimeoutSec 30 -ErrorAction Stop)).Trim()
        if ($version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$') { throw '下载服务未返回有效版本。' }
        $platform = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'win32-arm64' } else { 'win32-x64' }
        $manifest = Invoke-RestMethod -Uri "$base/$version/manifest.json" -TimeoutSec 30 -ErrorAction Stop
        $checksum = [string]$manifest.platforms.$platform.checksum
        if ($checksum -notmatch '^[a-fA-F0-9]{64}$') { throw '下载清单没有有效的文件校验值。' }
        $binaryPath = Join-Path $cacheRoot ('claude-install-' + [guid]::NewGuid().ToString('N') + '.exe')
        Invoke-WebRequest -Uri "$base/$version/$platform/claude.exe" -OutFile $binaryPath -UseBasicParsing -TimeoutSec 600 -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $binaryPath -Algorithm SHA256).Hash -ne $checksum) { throw '下载文件校验失败，未运行安装程序。' }
        Write-Host '  [安装] 文件校验通过，正在安装 Claude Code…'
        & $binaryPath install stable | Out-Host
        if ($LASTEXITCODE -ne 0) { throw '原生安装程序返回失败。' }
        $env:PATH = (Join-Path $env:USERPROFILE '.local\bin') + ';' + $env:PATH
        if (-not (Test-ClaudeSmoke)) { throw '安装结束但程序尚不可用。' }
        return $true
    } catch {
        Write-Host '  [提示] 原生安装未完成，将尝试已有的 Node/npm 安装方式。请确认网络可访问官方安装源。' -ForegroundColor Yellow
        return $false
    } finally {
        if ($binaryPath -and (Test-Path -LiteralPath $binaryPath)) { Remove-Item -LiteralPath $binaryPath -Force -ErrorAction SilentlyContinue }
    }
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
        Write-Host "  [手动] 请从 https://www.python.org/downloads/ 下载安装后重新双击 setup.bat" -ForegroundColor Red
        return $false
    }
    if (-not (Test-Python)) {
        Invoke-Relaunch -Reason "Python 已安装，需要一个新会话让 PATH 生效" | Out-Null
        Write-Host "  [警告] Python 已安装但当前会话仍找不到 'python' 命令" -ForegroundColor Yellow
        Write-Host "         请关闭此窗口，重新双击 setup.bat（无需自己开 PowerShell）" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# ── 一键体检（-Doctor）──
# 只读检查，不安装任何东西、不打印 API key 明文。绿=正常，黄=可继续但建议修，红=会卡住启动。
function Invoke-Doctor {
    # 用 script 作用域计数：嵌套函数里的 $script: 才能正确累加
    $script:DoctorPass = 0
    $script:DoctorWarn = 0
    $script:DoctorFail = 0
    function Write-Check {
        param([string]$Status, [string]$Name, [string]$Detail, [string]$Fix = "")
        $color = switch ($Status) {
            "OK"   { $script:DoctorPass++; "Green" }
            "WARN" { $script:DoctorWarn++; "Yellow" }
            "FAIL" { $script:DoctorFail++; "Red" }
            default { "Gray" }
        }
        $mark = switch ($Status) { "OK" { "[OK]  " } "WARN" { "[WARN]" } "FAIL" { "[FAIL]" } default { "[···] " } }
        Write-Host "  $mark $Name" -ForegroundColor $color
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Gray }
        if ($Fix -and $Status -ne "OK") { Write-Host "         修复：$Fix" -ForegroundColor DarkYellow }
    }

    Write-Host ""
    Write-Host "  ════════ claude-proxy 环境体检 v$SCRIPT_VERSION ════════" -ForegroundColor Cyan
    Write-Host "  （只检查不安装；把本窗口文字原样复制即可求助，不会带出 API key）" -ForegroundColor Gray
    Write-Host ""

    # 1. Windows
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $caption = $os.Caption
        $build = [int]$os.BuildNumber
        if ($build -ge 19045 -or $build -ge 19041) {
            Write-Check "OK" "Windows" "$caption (Build $build)"
        } elseif ($build -ge 10240) {
            Write-Check "WARN" "Windows" "$caption (Build $build)" "建议 Win10 22H2 或 Win11；过旧的精简系统可能没有 winget"
        } else {
            Write-Check "FAIL" "Windows" "$caption (Build $build)" "需要 Windows 10/11"
        }
    } catch {
        Write-Check "WARN" "Windows" "无法读取系统信息" ""
    }

    # 2. 执行策略
    try {
        $policies = @()
        foreach ($scope in @("Process","CurrentUser","LocalMachine")) {
            $p = Get-ExecutionPolicy -Scope $scope -ErrorAction SilentlyContinue
            if ($p -and $p -ne "Undefined") { $policies += "$scope=$p" }
        }
        $eff = Get-ExecutionPolicy
        if ($eff -in @("RemoteSigned","Unrestricted","Bypass")) {
            Write-Check "OK" "PowerShell 执行策略" "Effective=$eff ($($policies -join ', '))"
        } else {
            Write-Check "FAIL" "PowerShell 执行策略" "Effective=$eff" "Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        }
    } catch {
        Write-Check "WARN" "PowerShell 执行策略" "读取失败：$($_.Exception.Message)"
    }

    # 3. 本脚本编码（BOM）
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
        $bytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
            Write-Check "OK" "主脚本编码" "UTF-8 BOM 正确（中文不会乱码）"
        } else {
            Write-Check "FAIL" "主脚本编码" "缺少 UTF-8 BOM（前3字节: $($bytes[0]),$($bytes[1]),$($bytes[2])）" "用 VS Code 另存为 UTF-8 with BOM，或重新 Download ZIP（不要浏览器另存为单个文件）"
        }
    }

    # 4. winget
    if (Test-Command "winget") {
        try {
            $wv = (& winget --version 2>&1 | Select-Object -First 1)
            Write-Check "OK" "winget" "$wv"
        } catch {
            Write-Check "WARN" "winget" "命令存在但执行异常" "Microsoft Store 安装/更新 App Installer"
        }
    } else {
        Write-Check "WARN" "winget" "未检测到（自动装依赖会降级为手动）" "Microsoft Store 安装 App Installer；或自行手动装 Node/Git"
    }

    # 5. Node / npm
    if (Test-Command "node") {
        $nv = (& node --version 2>&1 | Select-Object -First 1)
        Write-Check "OK" "Node.js" "$nv"
    } else {
        $npmBin = Get-NpmGlobalBin
        if ($npmBin) {
            Write-Check "WARN" "Node.js" "PATH 中没有 node，但 npm 全局目录有痕迹" "关闭窗口重新双击 setup.bat"
        } else {
            Write-Check "FAIL" "Node.js" "未安装" "双击 setup.bat 自动装；或 https://nodejs.org/ 下 LTS"
        }
    }
    if (Test-Command "npm") {
        $mv = (& npm --version 2>&1 | Select-Object -First 1)
        Write-Check "OK" "npm" "$mv"
    } else {
        Write-Check "FAIL" "npm" "未安装" "先安装 Node.js（自带 npm）"
    }

    # 6. Claude Code
    if (Test-Command "claude") {
        try {
            $cv = (& claude --version 2>&1 | Select-Object -First 1)
            Write-Check "OK" "Claude Code CLI" "$cv"
        } catch {
            Write-Check "WARN" "Claude Code CLI" "命令存在但 --version 失败" "npm install -g @anthropic-ai/claude-code --registry https://registry.npmmirror.com"
        }
    } else {
        $npmBin = Get-NpmGlobalBin
        if ($npmBin) {
            $npmDir = Split-Path -Parent $npmBin
            Write-Check "WARN" "Claude Code CLI" "已安装于 $npmDir 但 PATH 未刷新" "关闭窗口重新双击 setup.bat"
        } else {
            Write-Check "FAIL" "Claude Code CLI" "未安装" "双击 setup.bat；或 npm install -g @anthropic-ai/claude-code --registry https://registry.npmmirror.com"
        }
    }

    # 7. Git / Python（非硬阻塞）
    if (Test-Command "git") {
        $gv = (& git --version 2>&1 | Select-Object -First 1)
        Write-Check "OK" "Git" "$gv"
    } else {
        Write-Check "WARN" "Git" "未安装（Claude 改代码时会用到，本代理不强制）" "winget install Git.Git 或 https://git-scm.com/"
    }
    if (Test-Python) {
        $pv = (& python --version 2>&1 | Select-Object -First 1)
        Write-Check "OK" "Python" "$pv（仅 OpenAI 协议 provider 需要）"
    } else {
        Write-Check "WARN" "Python" "未安装（默认 DeepSeek 直连不需要）" "只在用 Gemini/Moonshot 等 OpenAI 协议时才要装"
    }

    # 8. API key（只报有无，不回显）
    $dotenv = Load-DotEnv
    $hasKey = $false
    foreach ($k in $dotenv.Keys) {
        if ($k -match '_API_KEY$' -and -not [string]::IsNullOrWhiteSpace($dotenv[$k])) {
            $hasKey = $true
            $tail = $dotenv[$k]
            if ($tail.Length -gt 4) { $tail = "****" + $tail.Substring($tail.Length - 4) } else { $tail = "****" }
            Write-Check "OK" "API key" "已找到 $k（$tail）"
            break
        }
    }
    if (-not $hasKey) {
        $envFile = Get-DotEnvPath
        if (Test-Path $envFile) {
            Write-Check "WARN" "API key" ".env 存在但没有 *_API_KEY 条目" "重新双击 setup.bat，在提示处粘贴 key"
        } else {
            Write-Check "WARN" "API key" "尚未配置（首次启动会提示粘贴）" "双击 setup.bat，按提示粘贴"
        }
    }

    # 9. 磁盘
    try {
        $sys = Split-Path $env:SystemDrive -Qualifier
        $drive = Get-PSDrive -Name ($sys -replace ':','') -ErrorAction Stop
        $freeGB = [math]::Round($drive.Free / 1GB, 1)
        if ($freeGB -ge 2) {
            Write-Check "OK" "磁盘空间" "$sys 可用 $freeGB GB"
        } elseif ($freeGB -ge 0.5) {
            Write-Check "WARN" "磁盘空间" "$sys 可用 $freeGB GB" "装 Node+Claude 至少预留 1GB 以上"
        } else {
            Write-Check "FAIL" "磁盘空间" "$sys 可用 $freeGB GB" "清理磁盘后再装"
        }
    } catch {
        Write-Check "WARN" "磁盘空间" "无法读取"
    }

    # 10. 网络（短超时，单项失败不阻断其它检查）
    $netTests = @(
        @{ Name = "npmmirror（国内装包）"; Url = "https://registry.npmmirror.com/@anthropic-ai/claude-code"; Timeout = 5 }
        @{ Name = "npmjs（官方源）";     Url = "https://registry.npmjs.org/@anthropic-ai/claude-code"; Timeout = 5 }
        @{ Name = "DeepSeek API 端点";   Url = "https://api.deepseek.com/"; Timeout = 5 }
    )
    foreach ($t in $netTests) {
        try {
            $r = Invoke-WebRequest -Uri $t.Url -Method Head -TimeoutSec $t.Timeout -UseBasicParsing -ErrorAction Stop
            Write-Check "OK" "网络 $($t.Name)" "HTTP $($r.StatusCode)"
        } catch {
            # Head 可能被拒，再试 GET
            try {
                $r2 = Invoke-WebRequest -Uri $t.Url -TimeoutSec $t.Timeout -UseBasicParsing -ErrorAction Stop
                Write-Check "OK" "网络 $($t.Name)" "HTTP $($r2.StatusCode)"
            } catch {
                $isMirror = $t.Name -match "npmmirror"
                Write-Check ($(if ($isMirror) { "WARN" } else { "WARN" })) "网络 $($t.Name)" "连不上或超时" "检查代理/防火墙；装包优先靠 npmmirror"
            }
        }
    }

    # 11. setup.bat 换行（若在同目录）
    $setupPath = Join-Path (Split-Path -Parent $PSCommandPath) "setup.bat"
    if (Test-Path $setupPath) {
        $sb = [System.IO.File]::ReadAllBytes($setupPath)
        $hasBom = $sb.Length -ge 3 -and $sb[0] -eq 239 -and $sb[1] -eq 187 -and $sb[2] -eq 191
        $text = [System.Text.Encoding]::UTF8.GetString($sb)
        $hasCrlf = $text -match "`r`n"
        if ($hasBom) {
            Write-Check "FAIL" "setup.bat 编码" "带了 UTF-8 BOM（会导致 cmd 闪退）" "用 VS Code 保存为 UTF-8（无 BOM）+ CRLF，或重新下载 ZIP"
        } elseif ($hasCrlf) {
            Write-Check "OK" "setup.bat 编码" "无 BOM，CRLF 正常"
        } else {
            Write-Check "WARN" "setup.bat 编码" "无 BOM，但可能是 LF 换行" "VS Code 右下角改成 CRLF"
        }
    }

    Write-Host ""
    Write-Host "  ════════ 体检结果：通过 $script:DoctorPass · 警告 $script:DoctorWarn · 失败 $script:DoctorFail ════════" -ForegroundColor Cyan
    if ($script:DoctorFail -gt 0) {
        Write-Host "  存在会阻塞启动的问题（红色项）。请按每行「修复」提示处理后重试。" -ForegroundColor Red
        Write-Host "  求助时请复制本窗口全部文字（不含 API key 明文）。" -ForegroundColor Gray
    } elseif ($script:DoctorWarn -gt 0) {
        Write-Host "  核心项可通过，但有警告。默认 DeepSeek 直连通常仍可启动。" -ForegroundColor Yellow
    } else {
        Write-Host "  环境就绪。双击 setup.bat 即可启动。" -ForegroundColor Green
    }
    Write-Host ""
    return ($script:DoctorFail -eq 0)
}

# ── 自动更新（默认仅检查并提示；下载替换只在显式 -Update 时发生）──

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
                # 有的镜像（如 jsdelivr）会把内容当二进制返回 byte[]，统一解码成 UTF-8 字符串，
                # 否则后面 [version] 解析会拿到 "49 46 49..." 这种字节串而失败。
                $text = if ($resp.Content -is [byte[]]) {
                    [System.Text.Encoding]::UTF8.GetString($resp.Content)
                } else {
                    [string]$resp.Content
                }
                return @{ Content = $text; Url = $url }
            }
        } catch { continue }
    }
    return $null
}

# 默认更新行为：只拉远端 VERSION 比对，有新版就【打印提示】，绝不自动下载执行。
# 把"是否更新、何时更新"的决定权交还给用户，关掉默认的静默远程代码执行通道。
function Check-ForUpdate {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { return }
    $dir    = Split-Path -Parent $scriptPath
    $marker = Join-Path $dir ".update-check"

    # 节流：每 12 小时最多联网检查一次
    if (Test-Path $marker) {
        try {
            $lastTime = [datetime]::Parse((Get-Content $marker -Raw -ErrorAction Stop).Trim())
            if (((Get-Date) - $lastTime).TotalHours -lt 12) { return }
        } catch {}
    }

    $verRes = Fetch-FromMirrors -File "VERSION" -TimeoutSec 5
    # 无论成败都记录检查时间，避免每次双击都联网
    try { (Get-Date).ToString("o") | Set-Content -Path $marker -Encoding ascii -ErrorAction SilentlyContinue } catch {}
    if (-not $verRes) { return }   # 全部镜像连不上，静默跳过

    $remoteVer = ($verRes.Content -replace '[^\d\.]', '').Trim()
    if (-not $remoteVer) { return }
    try {
        $rv = [version]$remoteVer
        $lv = [version]$SCRIPT_VERSION
    } catch { return }
    if ($rv -le $lv) { return }   # 已是最新

    Write-Host ""
    Write-Host "  [更新] 发现新版本 v$remoteVer（当前 v$SCRIPT_VERSION）" -ForegroundColor Cyan
    Write-Host "         本工具默认不会自动下载更新。要更新请任选其一：" -ForegroundColor Gray
    Write-Host "           1) 运行  .\claude-proxy.ps1 -Update" -ForegroundColor Gray
    Write-Host "           2) 去 https://github.com/$UPDATE_REPO 重新下载 ZIP" -ForegroundColor Gray
    Write-Host ""
}

# 手动更新（仅在用户显式 -Update 时调用）：拉远端 VERSION 比对，更新则下载校验后替换并用新版重启。
# 提醒：脚本从镜像下载，仅做"非空+含版本标记+语法可解析"格式校验，不验证来源真实性（无 hash/签名）。
# 因此它只在用户主动 -Update 时运行，不作为默认行为。任何环节失败都降级为"继续用当前版本"。
function Invoke-SelfUpdate {
    param([switch]$Force)

    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { return }
    $dir    = Split-Path -Parent $scriptPath
    $marker = Join-Path $dir ".update-check"

    # -Update 始终带 -Force，跳过节流
    if (-not $Force -and (Test-Path $marker)) {
        try {
            $lastTime = [datetime]::Parse((Get-Content $marker -Raw -ErrorAction Stop).Trim())
            if (((Get-Date) - $lastTime).TotalHours -lt 12) { return }
        } catch {}
    }

    # 拉远端版本号
    $verRes = Fetch-FromMirrors -File "VERSION" -TimeoutSec 5
    try { (Get-Date).ToString("o") | Set-Content -Path $marker -Encoding ascii -ErrorAction SilentlyContinue } catch {}
    if (-not $verRes) {
        Write-Host "  [更新] 连不上更新源，继续使用当前版本 v$SCRIPT_VERSION" -ForegroundColor Yellow
        return
    }

    $remoteVer = ($verRes.Content -replace '[^\d\.]', '').Trim()
    if (-not $remoteVer) { return }
    try {
        $rv = [version]$remoteVer
        $lv = [version]$SCRIPT_VERSION
    } catch { return }
    if ($rv -le $lv) {
        Write-Host "  [更新] 已是最新版本 v$SCRIPT_VERSION" -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "  [更新] 发现新版本 v$remoteVer（当前 v$SCRIPT_VERSION），正在从镜像下载..." -ForegroundColor Cyan
    Write-Host "         （更新内容来自公开镜像，仅做格式校验；如担心可改为去 GitHub 手动下载）" -ForegroundColor DarkGray

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
    # 防止下到半截 / 错误页面 / 截断的内容写坏脚本。注意：这只防"损坏"，不防"投毒"。
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

    # 备份旧版（按版本号命名，坏更新不会顶掉历史好备份）+ 用下载的原始字节替换自身（保留 BOM）。
    # PowerShell 启动时已把脚本读入内存，覆盖磁盘上的 .ps1 不影响当前进程，所以可以安全替换自身。
    try {
        $bak = "$scriptPath.$SCRIPT_VERSION.bak"
        if (-not (Test-Path $bak)) { Copy-Item $scriptPath $bak -Force -ErrorAction SilentlyContinue }
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
    if ($InstanceDir) { return (Join-Path $InstanceDir '.env') }
    if ($PSScriptRoot) { return (Join-Path $PSScriptRoot ".env") }
    return (Join-Path (Get-Location) ".env")
}

function Load-DotEnv {
    $envFile = Get-DotEnvPath
    $result = @{}
    if (-not (Test-Path -LiteralPath $envFile)) { return $result }
    foreach ($line in Get-Content -LiteralPath $envFile -Encoding UTF8) {
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
    $lines = @("# claude-proxy 本地配置（含 API key，等同账号密码；不要提交到 git，也不要把整个文件夹打包发给别人）")
    foreach ($k in ($existing.Keys | Sort-Object)) {
        $lines += "$k=$($existing[$k])"
    }
    # 用无 BOM 的 UTF-8 写出
    [System.IO.File]::WriteAllLines($envFile, $lines, [System.Text.UTF8Encoding]::new($false))
    # 收紧权限：移除继承，仅当前用户可读写（失败不阻断）
    try { & icacls $envFile /inheritance:r /grant:r "$($env:USERNAME):(R,W)" 2>$null | Out-Null } catch {}
}

# 判断一个值是否是"示例占位符"（而非真实 key）
function Test-IsPlaceholderKey {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    # not-needed 是本地 Ollama 等的合法值，不当占位符
    if ($Value -eq "not-needed") { return $false }
    $patterns = @(
        '^PASTE_YOUR_.*_HERE$',
        '^sk-or-your-key$',
        '^sk-your-.*-key$',
        '^your-.*-key$',
        '^your-.*key.*$',
        '^your-model-name$',
        '^<.*>$'
    )
    foreach ($p in $patterns) { if ($Value -match $p) { return $true } }
    return $false
}

# 解析某个 provider 的真实 API key：
#   1) 脚本里已经填好（非占位符） → 直接用
#   2) .env 或系统环境变量里有 <PROVIDER>_API_KEY → 用
#   3) 都没有 → 交互式提示用户粘贴（不回显），存到 .env
function Resolve-ApiKey {
    param([string]$ProviderName, [string]$CurrentValue, [string]$SignupUrl)

    if ($InstanceDir) {
        $encryptedPath = Join-Path $InstanceDir 'api-key.dpapi'
        if (Test-Path -LiteralPath $encryptedPath) {
            try {
                $saved = Get-Content -LiteralPath $encryptedPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertTo-SecureString -ErrorAction Stop
                $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($saved)
                try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
                finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
            } catch {
                Write-Host '  [错误] 无法解密此 Key。请在图形入口重新填写（加密 Key 仅限原 Windows 用户使用）。' -ForegroundColor Red
                return $null
            }
        }
    }

    if (-not (Test-IsPlaceholderKey $CurrentValue)) {
        return $CurrentValue
    }

    $envVar = "$($ProviderName.ToUpper())_API_KEY"

    $dotenv = Load-DotEnv
    if ($dotenv.ContainsKey($envVar) -and -not [string]::IsNullOrWhiteSpace($dotenv[$envVar])) {
        return $dotenv[$envVar]
    }

    $sysVal = if ($InstanceDir) { $null } else { [System.Environment]::GetEnvironmentVariable($envVar) }
    if (-not [string]::IsNullOrWhiteSpace($sysVal)) {
        return $sysVal
    }

    Write-Host ""
    Write-Host "  ════ 首次配置：需要 $ProviderName 的 API key ════" -ForegroundColor Cyan
    if ($SignupUrl) {
        Write-Host "  还没有 key？去这里申请：$SignupUrl" -ForegroundColor Cyan
        Write-Host "  申请后把 key 整段复制，回到这里粘贴。" -ForegroundColor Gray
    }
    Write-Host "  请粘贴你的 $ProviderName API key 后回车（输入【不会显示】是正常的，粘贴后直接回车）：" -ForegroundColor Yellow

    # 不回显录入（避免 key 上屏 / 进 scrollback / 被截图录屏看到）
    $secure = Read-Host -AsSecureString
    $key = $null
    if ($secure -and $secure.Length -gt 0) {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try   { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    if ([string]::IsNullOrWhiteSpace($key)) {
        return $null
    }
    # 比 Trim 更狠：去掉所有空白与控制字符（粘贴常带换行/BOM/零宽字符）
    $key = ($key -replace '[\s\p{C}]', '')
    if ([string]::IsNullOrWhiteSpace($key)) {
        return $null
    }
    Save-DotEnv -Key $envVar -Value $key
    # 回显末 4 位供核对，不暴露整把 key
    $tail = if ($key.Length -ge 4) { $key.Substring($key.Length - 4) } else { '****' }
    Write-Host "  [完成] 已保存到 $(Get-DotEnvPath)（末4位 ...$tail，下次不会再问）" -ForegroundColor Green
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
    Write-Host '   .\claude-proxy.ps1                              # 默认 provider（deepseek，Anthropic 直连）' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider mimo               # 切到 MiMo（Anthropic 直连）' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider moonshot           # OpenAI 格式，自动 LiteLLM 转换' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -List                        # 列出所有 provider' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Doctor                      # 一键体检环境（新电脑部署先跑这个）' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Help                        # 显示本帮助' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider custom -BaseUrl "https://..." -ApiKey "sk-..." -Model "xxx" -Protocol openai' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Provider deepseek -Model deepseek-v4-flash  # 覆盖模型' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -SharedConfig                # 用 ~/.claude 共享配置' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -WorkDir "C:\my\project"     # 指定工作目录' -ForegroundColor Gray
    Write-Host '   .\create-launcher.bat                           # 为每个 API 创建独立启动器' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -InstanceDir "D:\实例\工作"   # 从实例目录启动' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -Update                      # 手动下载并应用脚本更新' -ForegroundColor Gray
    Write-Host '   .\claude-proxy.ps1 -SkipUpdate                  # 跳过本次更新检查' -ForegroundColor Gray
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
        # Import the proxy server itself so a base-only litellm install is rejected.
        $result = python -c "import litellm, backoff, orjson, redis, boto3; import litellm.proxy.proxy_server; print('ok')" 2>&1
        if ($result -match "ok") { return $true }
    } catch {}
    return $false
}

# 安装 LiteLLM
function Install-LiteLlm {
    Write-Host "  [信息] 正在安装 LiteLLM..." -ForegroundColor Yellow
    Write-Host "         python -m pip install 'litellm[proxy]'" -ForegroundColor Gray
    Write-Host "         国内网络可能较慢，请耐心等待，不要关闭窗口" -ForegroundColor Gray
    Write-Host ""
    python -m pip install "litellm[proxy]"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  [错误] LiteLLM 自动安装失败（多半是网络 / Python 环境问题）" -ForegroundColor Red
        Write-Host "         请检查网络后，关掉本窗口重新双击 setup.bat 再试" -ForegroundColor Yellow
        Write-Host "         (高级用户可手动: python -m pip install 'litellm[proxy]')" -ForegroundColor DarkGray
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

# 启动 LiteLLM 代理（后台进程），返回进程对象、端口、就绪状态与需清理的临时文件路径。
function Start-LiteLlmProxy {
    param(
        [string]$TargetBaseUrl,
        [string]$TargetApiKey,
        [string]$TargetModel,
        [int]$Port
    )

    # 不扫描或终止其他 LiteLLM 进程；它们可能属于同时运行的另一个实例。

    if ($Port -eq 0) {
        $Port = Get-FreePort
    }

    # 临时文件：config 与日志都用随机文件名，避免多实例冲突；用完即删。
    $cfgPath   = Join-Path $env:TEMP ("litellm-{0}-{1}.yaml"   -f $Port, [guid]::NewGuid().ToString('N'))
    $stdoutLog = Join-Path $env:TEMP ("litellm-{0}-{1}.out.log" -f $Port, [guid]::NewGuid().ToString('N'))
    $stderrLog = Join-Path $env:TEMP ("litellm-{0}-{1}.err.log" -f $Port, [guid]::NewGuid().ToString('N'))

    # 用 config 文件 + 环境变量传 key，【不把 key 放命令行】（命令行对同机所有进程可见）。
    # 通配路由 model_name="*" / model="aiohttp_openai/*"：请求里的任何模型名
    # （主模型 / small-fast）都原样转发到上游的 Chat Completions 端点。
    # 使用 aiohttp_openai 是为了避免 LiteLLM 对 gpt-5.4+ 模型自动桥接到
    # Responses API；部分第三方网关的 Responses input 只接受字符串。
    $cfgLines = @(
        "model_list:",
        '  - model_name: "*"',
        "    litellm_params:",
        '      model: "aiohttp_openai/*"',
        "      api_base: $TargetBaseUrl",
        "      api_key: os.environ/UPSTREAM_API_KEY"
    )
    [System.IO.File]::WriteAllLines($cfgPath, $cfgLines, [System.Text.UTF8Encoding]::new($false))

    # key 通过环境变量注入子进程（config 里用 os.environ/UPSTREAM_API_KEY 引用），并压低日志级别（避免落 key）。
    $env:UPSTREAM_API_KEY = $TargetApiKey
    $env:LITELLM_LOG      = "ERROR"

    $litellmCommand = Get-Command litellm.exe -ErrorAction SilentlyContinue
    if (-not $litellmCommand) {
        $litellmCommand = Get-Command litellm -ErrorAction SilentlyContinue
    }
    if (-not $litellmCommand) {
        Write-Host "  [错误] 找不到 LiteLLM 命令入口，请重新安装 litellm[proxy]" -ForegroundColor Red
        Remove-Item $cfgPath -ErrorAction SilentlyContinue
        Remove-Item $stdoutLog -ErrorAction SilentlyContinue
        Remove-Item $stderrLog -ErrorAction SilentlyContinue
        Remove-Item Env:\UPSTREAM_API_KEY -ErrorAction SilentlyContinue
        return @{ Process = $null; Port = $Port; Alive = $false; Ready = $false; ConfigPath = $cfgPath; StdoutLog = $stdoutLog; StderrLog = $stderrLog }
    }

    $litellmArgs = @(
        "--host", "127.0.0.1",
        "--port", $Port,
        "--config", $cfgPath
    )

    Write-Host "  [信息] 正在启动 LiteLLM 协议转换代理..." -ForegroundColor Yellow
    Write-Host "         端口: $Port" -ForegroundColor Gray
    Write-Host "         目标: $TargetBaseUrl → $TargetModel" -ForegroundColor Gray
    Write-Host ""

    $process = Start-Process -FilePath $litellmCommand.Source -ArgumentList $litellmArgs `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog

    # key 已交给子进程，父进程环境里立刻抹掉
    Remove-Item Env:\UPSTREAM_API_KEY -ErrorAction SilentlyContinue

    # 等待就绪：必须 /health 返回 200 才算就绪（最多等 30 秒）
    $maxWait = 30
    $waited  = 0
    $ready   = $false
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 1
        $waited++
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) { $ready = $true; break }
        } catch {
            # 还没启动好，继续等
        }
        if ($process.HasExited) { break }   # 进程已退出（启动失败），不必再等
    }

    $alive = -not $process.HasExited

    if ($ready) {
        Write-Host "  [信息] LiteLLM 代理已就绪 (http://127.0.0.1:$Port)" -ForegroundColor Green
        Write-Host ""
    } elseif (-not $alive) {
        Write-Host "  [错误] LiteLLM 启动失败" -ForegroundColor Red
        $stderr = Get-Content $stderrLog -ErrorAction SilentlyContinue
        if ($stderr) {
            # 脱敏后再打印（避免把 key 糊到屏幕）
            $masked = ($stderr | Select-Object -Last 5 | Out-String) -replace '(sk-[A-Za-z0-9]{4})[A-Za-z0-9_\-]+', '$1***'
            Write-Host "         错误日志(末5行，已脱敏)：" -ForegroundColor Red
            Write-Host "         $masked" -ForegroundColor Red
        }
    } else {
        # 第三态：进程还活着，但 30 秒内没确认就绪（低配机/杀软扫描会慢，也可能是上游配错）。
        # 不再冒充"已就绪"——如实告知，让用户决定。
        Write-Host "  [警告] LiteLLM 30 秒内未确认就绪，但进程仍在运行" -ForegroundColor Yellow
        Write-Host "         常见原因：机器较慢，或上游 API key / 地址配置有误" -ForegroundColor Yellow
        Write-Host "         若接下来连接报错，可关掉窗口重试，或检查 .env 里的 key" -ForegroundColor Yellow
        Write-Host ""
    }

    return @{
        Process    = $process
        Port       = $Port
        Ready      = $ready
        Alive      = $alive
        ConfigPath = $cfgPath
        StdoutLog  = $stdoutLog
        StderrLog  = $stderrLog
    }
}

# 停止 LiteLLM 代理并清理临时文件
function Stop-LiteLlmProxy {
    param([hashtable]$Info)

    if (-not $Info) { return }
    $proc = $Info.Process
    if ($proc -and -not $proc.HasExited) {
        Write-Host ""
        Write-Host "  [信息] 正在停止 LiteLLM 代理..." -ForegroundColor Yellow
        # /T 杀整棵进程树（uvicorn 可能 fork worker），/F 强制
        & taskkill /PID $proc.Id /T /F 2>$null | Out-Null
    }
    # 清理临时 config 与日志
    Remove-Item $Info.ConfigPath -ErrorAction SilentlyContinue
    Remove-Item $Info.StdoutLog  -ErrorAction SilentlyContinue
    Remove-Item $Info.StderrLog  -ErrorAction SilentlyContinue
}


# =================== 主逻辑 ===================

# 实例参数只读 JSON，不能把内容当作 PowerShell 执行；验证在更新和安装之前完成。
$instanceSettings = $null
if ($InstanceDir) {
    try {
        foreach ($conflict in @('Provider', 'BaseUrl', 'ApiKey', 'Model', 'SmallFastModel', 'Protocol', 'SharedConfig', 'Update')) {
            if ($PSBoundParameters.ContainsKey($conflict)) { throw "实例模式不能同时指定 -$conflict。请编辑实例的 profile.json。" }
        }
        $instanceItem = Get-Item -LiteralPath $InstanceDir -ErrorAction Stop
        if (-not $instanceItem.PSIsContainer -or $instanceItem.PSProvider.Name -ne 'FileSystem') { throw '实例目录不存在。' }
        $InstanceDir = $instanceItem.FullName
        $instanceSettings = Get-Content -LiteralPath (Join-Path $InstanceDir 'profile.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($instanceSettings.schemaVersion -ne 1) { throw '不支持的 profile.json 版本。' }
        foreach ($field in @('name', 'baseUrl', 'model', 'smallFastModel', 'protocol', 'workDir')) {
            $value = $instanceSettings.$field
            if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value) -or $value -match '[\p{C}]') { throw "profile.json 的 $field 无效。" }
        }
        $instanceUri = $null
        if (-not [Uri]::TryCreate($instanceSettings.baseUrl, [UriKind]::Absolute, [ref]$instanceUri) -or
            $instanceUri.Scheme -notin @('http', 'https') -or -not $instanceUri.Host -or
            $instanceUri.UserInfo -or $instanceUri.Query -or $instanceUri.Fragment -or $instanceSettings.baseUrl -match '\s') {
            throw 'profile.json 必须使用不含凭据或查询参数的 http(s) API 基础地址。'
        }
        if ($instanceSettings.protocol -notin @('anthropic', 'openai')) { throw 'profile.json 的协议必须为 anthropic 或 openai。' }
        if ($instanceSettings.model -match '\s' -or $instanceSettings.smallFastModel -match '\s') { throw '模型名不能包含空白。' }
        if (-not $WorkDir) {
            $WorkDir = $instanceSettings.workDir
            if (-not [IO.Path]::IsPathRooted($WorkDir)) { $WorkDir = Join-Path $InstanceDir $WorkDir }
        }
        if (-not (Test-Path -LiteralPath $WorkDir -PathType Container)) { throw '工作目录不存在。请修正 profile.json 的 workDir。' }
        $SkipUpdate = $true
    } catch {
        # 不输出 JSON 原文或解析器上下文，避免误填凭据后泄露到日志。
        Write-Host '  [错误] 实例配置无效、工作目录不存在或使用了冲突参数。检查 profile.json；实例模式不能搭配 provider/连接参数、SharedConfig 或 Update。' -ForegroundColor Red
        exit 1
    }
}

# 帮助 / 列表 / 体检：尽早处理，不启动 Claude
if ($Help) {
    Show-Usage
    Show-Providers
    exit 0
}
if ($List) {
    Show-Providers
    exit 0
}
if ($Doctor) {
    $ok = Invoke-Doctor
    if ($ok) { exit 0 } else { exit 1 }
}

# ── 自动更新：默认只检查并提示（不自动下载执行）；-Update 才真正下载替换 ──
if ($Update) {
    Invoke-SelfUpdate -Force
} elseif (-not $SkipUpdate) {
    Check-ForUpdate
}

# ── 前置依赖检查（小白模式，加 -SkipChecks 可跳过）──

# 图形后台安装完成后，新终端仍可能继承图形进程的旧 PATH。
# 即使跳过重复安装检查，也要找到已经安装的原生程序。
if ($InstanceDir -and -not (Test-Command 'claude')) {
    Refresh-Path
    $nativeBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path -LiteralPath (Join-Path $nativeBin 'claude.exe')) {
        $env:PATH = "$nativeBin;$env:PATH"
    }
}

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

if ($instanceSettings) {
    $Provider = 'instance'
    $providerProtocol = $instanceSettings.protocol
    $cfg = @{
        baseUrl = $instanceSettings.baseUrl
        apiKey = ''
        model = $instanceSettings.model
        smallFast = $instanceSettings.smallFastModel
        label = $instanceSettings.name
        protocol = $providerProtocol
        signupUrl = ''
    }
} elseif ($Provider -eq "custom") {
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
    # 已命名 provider：从注册表查找（浅拷贝一份，避免后面写 key 污染注册表对象）
    if (-not $PROVIDERS.ContainsKey($Provider)) {
        Write-Host ""
        Write-Host "  [错误] 未知 provider: '$Provider'" -ForegroundColor Red
        Show-Providers
        exit 1
    }
    $cfg = @{} + $PROVIDERS[$Provider]
    $providerProtocol = if ($cfg.protocol) { $cfg.protocol } else { "anthropic" }

} else {
    # 未指定 provider：使用默认（同样浅拷贝）
    $cfg = @{} + $PROVIDERS[$DEFAULT_PROVIDER]
    $Provider = $DEFAULT_PROVIDER
    $providerProtocol = if ($cfg.protocol) { $cfg.protocol } else { "anthropic" }
}

# 允许启动脚本覆盖已注册 provider 的连接参数。
# 这样每个 provider 可以有一个类似 claude-mimo.ps1 的独立启动脚本，
# 同时仍保留 provider 名称对应的隔离配置目录。
if (-not $isCustom -and ($BaseUrl -or $ApiKey -or $Protocol -or $SmallFastModel)) {
    if ($BaseUrl) { $cfg.baseUrl = $BaseUrl }
    if ($ApiKey) { $cfg.apiKey = $ApiKey }
    if ($SmallFastModel) { $cfg.smallFast = $SmallFastModel }
    if ($Protocol) { $providerProtocol = $Protocol.ToLower() }
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
        signupUrl = $cfg.signupUrl
    }
}

# ── 解析 API key ──
# 顺序：脚本里已填好 → .env → 环境变量 → 交互式输入（保存到 .env）
# 自定义 provider 必须通过 -ApiKey 显式传入，前面已经校验过。

if (-not $isCustom) {
    $resolvedKey = Resolve-ApiKey -ProviderName $Provider -CurrentValue $cfg.apiKey -SignupUrl $cfg.signupUrl
    if ([string]::IsNullOrWhiteSpace($resolvedKey)) {
        Write-Host ""
        Write-Host "  [错误] Provider '$Provider' 的 API key 未设置" -ForegroundColor Red
        Write-Host "         可重新运行脚本并在提示时粘贴 key，或编辑同目录 .env / 脚本内 apiKey" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    $cfg.apiKey = $resolvedKey
}

# ── 切换工作目录（放在启动代理之前，避免目录无效时白起一个 LiteLLM）──

if ($WorkDir) {
    if (Test-Path -LiteralPath $WorkDir -PathType Container) {
        Set-Location -LiteralPath $WorkDir
    } else {
        Write-Host ""
        Write-Host "  [错误] 工作目录不存在: $WorkDir" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}

# ── 配置目录：默认每个 provider 隔离，加 -SharedConfig 则共享 ~/.claude ──

$useIsolated = -not $SharedConfig
if ($useIsolated) {
    $configDir = if ($InstanceDir) { Join-Path $InstanceDir 'config' } else { "$env:USERPROFILE\.claude-$Provider" }
    $env:CLAUDE_CONFIG_DIR = $configDir
    [IO.Directory]::CreateDirectory($configDir) | Out-Null
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

    if ($PrepareOnly) { Write-Host '  [完成] 运行环境已准备好。'; exit 0 }

    # 启动 LiteLLM 代理
    $litellmInfo = Start-LiteLlmProxy `
        -TargetBaseUrl $cfg.baseUrl `
        -TargetApiKey $cfg.apiKey `
        -TargetModel $cfg.model `
        -Port $LiteLlmPort

    if (-not $litellmInfo.Alive) {
        Write-Host "  [错误] LiteLLM 代理未能启动" -ForegroundColor Red
        Stop-LiteLlmProxy -Info $litellmInfo
        exit 1
    }

    # Claude Code 连接 LiteLLM 本地代理（Anthropic 格式）
    $actualBaseUrl = "http://127.0.0.1:$($litellmInfo.Port)"
    $actualApiKey  = "litellm-proxy"  # LiteLLM 本地不需要真实 key
}

if ($PrepareOnly) { Write-Host '  [完成] 运行环境已准备好。'; exit 0 }

# ── 设置环境变量（进程级，退出即消失）──

if ($InstanceDir) {
    # 只清理当前进程中继承的身份、路由和模型变量，不修改用户/系统环境。
    foreach ($item in @(Get-ChildItem Env:)) {
        if ($item.Name -like 'ANTHROPIC_*' -or
            $item.Name -in @('CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY', 'CLAUDE_CODE_USE_ANTHROPIC_AWS', 'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR', 'CLAUDE_CODE_API_KEY_FILE_DESCRIPTOR')) {
            [Environment]::SetEnvironmentVariable($item.Name, $null, 'Process')
        }
    }
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $cfg.model
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $cfg.model
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $cfg.smallFast
}

$env:ANTHROPIC_BASE_URL         = $actualBaseUrl
$env:ANTHROPIC_AUTH_TOKEN       = $actualApiKey
$env:ANTHROPIC_MODEL            = $cfg.model
$env:ANTHROPIC_SMALL_FAST_MODEL = $cfg.smallFast

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
    if ($litellmInfo.Ready) {
        Write-Host "   LiteLLM  : http://127.0.0.1:$($litellmInfo.Port)" -ForegroundColor Green
    } else {
        Write-Host "   LiteLLM  : http://127.0.0.1:$($litellmInfo.Port)  (未确认就绪)" -ForegroundColor Yellow
    }
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

$claudeExitCode = 1
try {
    claude @args
    $claudeExitCode = $LASTEXITCODE
} finally {
    # ── 清理：退出时停止 LiteLLM 代理（含临时 config / 日志）──
    if ($litellmInfo) {
        Stop-LiteLlmProxy -Info $litellmInfo
    }
}

exit $claudeExitCode


# ============================================================
# 小贴士：
#  * 提示"无法加载脚本"？运行一次：
#      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#    或直接用 setup.bat，它会自动处理。
#
#  * 验证代理是否生效：启动后输入 /model 查看
#
#  * 添加新 provider：复制 providers.local.example.ps1 为 providers.local.ps1
#    并填入你的 provider。自动更新不会覆盖这个文件。
#
#  * 更新脚本：默认每 12 小时联网检查一次，发现新版【只提示不自动更新】；
#    要更新运行 -Update（手动下载替换），或去 GitHub 重新下载。
#    更新只替换 claude-proxy.ps1 本身，你的 .env 和 providers.local.ps1 都不会被动。
#
#  * OpenAI 格式的 provider 会自动通过 LiteLLM 转换，
#    首次使用会自动安装（需要 Python + pip）。默认的 deepseek 走 Anthropic 直连，无需这些。
#
#  * LiteLLM 临时日志位于 %TEMP%\litellm-*.log（正常退出会自动删）。
#    注意：该日志可能含访问地址等信息，排错后请删除，勿截图发给他人。
# ============================================================
