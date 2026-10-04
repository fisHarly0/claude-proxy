# 为每个 API 生成可移动的独立 Claude Code 启动目录。兼容 Windows PowerShell 5.1。
[CmdletBinding()]
param(
    [string]$Name,
    [string]$BaseUrl,
    [string]$Model,
    [string]$SmallFastModel,
    [ValidateSet('anthropic', 'openai')][string]$Protocol = 'anthropic',
    [string]$OutputDir = (Join-Path $PSScriptRoot 'launchers'),
    [string]$WorkDir,
    [switch]$NonInteractive,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8

try {
    Write-Host '为一个 API 创建独立的 Claude Code 启动器' -ForegroundColor Cyan
    if (-not $NonInteractive) {
        if (-not $Name) { $Name = Read-Host '实例名（例如 deepseek-work 或 我的备用API）' }
        if (-not $BaseUrl) { $BaseUrl = Read-Host '服务商提供的 Claude Code / Anthropic 兼容 API 基础地址' }
        if (-not $Model) { $Model = Read-Host '服务商提供的完整模型名' }
        if (-not $PSBoundParameters.ContainsKey('Protocol')) {
            $choice = Read-Host '协议：回车 = Anthropic 直连；输入 openai = 实验性转换'
            if ($choice) { $Protocol = $choice.Trim().ToLowerInvariant() }
        }
        if (-not $WorkDir) {
            $WorkDir = Read-Host '已有代码项目目录（回车 = 创建独立工作目录）'
        }
    }
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Length -gt 80 -or
        $Name -match '[<>:"/\\|?*\p{C}]' -or $Name -match '^[. ]|[. ]$' -or
        $Name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\.|$)') {
        throw '实例名不能为空，也不能包含路径、Windows 保留名称或非法文件名字符。'
    }
    $uri = $null
    if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http', 'https') -or -not $uri.Host -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $BaseUrl -match '[\s\p{C}]') {
        throw 'API 地址必须是 http(s) 基础地址，不能包含用户名、密码、查询参数或片段。不要把 Key 放进地址。'
    }
    if ([string]::IsNullOrWhiteSpace($Model) -or $Model -match '[\s\p{C}]') {
        throw '请填写完整模型名，不能包含空白或控制字符。'
    }
    if (-not $SmallFastModel) { $SmallFastModel = $Model }
    if ($SmallFastModel -match '[\s\p{C}]') { throw '快速模型名不能包含空白或控制字符。' }
    if ($Protocol -notin @('anthropic', 'openai')) { throw '协议只能填写 anthropic 或 openai。' }
    if ($Protocol -eq 'openai') {
        Write-Warning 'OpenAI 转换为实验功能，需要 Python + LiteLLM；不保证 Claude Code 的流式输出和工具调用兼容。优先使用服务商的 Anthropic 兼容地址。'
    }
    $projectDir = 'workspace'
    if ($WorkDir) {
        $item = Get-Item -LiteralPath $WorkDir
        if (-not $item.PSIsContainer -or $item.PSProvider.Name -ne 'FileSystem') { throw '工作目录必须是已存在的文件夹。' }
        $projectDir = $item.FullName
    }
    if ($ValidateOnly) { return }
    $outputRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
    $destination = Join-Path $outputRoot $Name
    if (Test-Path -LiteralPath $destination) { throw '同名实例目录已存在。请换一个名字；现有配置和 Key 不会被覆盖。' }
    # 只复制发布文件，不读取 .env / providers.local.ps1 或已有实例。
    foreach ($file in @('claude-proxy.ps1', 'VERSION', 'LICENSE')) {
        if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) {
            throw "缺少运行文件 $file，请下载完整仓库。"
        }
    }
    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    # New-Item 不使用 -Force：并发创建同名实例时也必须失败，不能覆盖。
    New-Item -ItemType Directory -Path $destination -ErrorAction Stop | Out-Null
    foreach ($folder in @('config', 'workspace')) {
        [IO.Directory]::CreateDirectory((Join-Path $destination $folder)) | Out-Null
    }
    foreach ($file in @('claude-proxy.ps1', 'VERSION', 'LICENSE')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $destination $file)
    }
    $profile = [ordered]@{
        schemaVersion = 1
        name = $Name
        baseUrl = $BaseUrl.TrimEnd('/')
        model = $Model
        smallFastModel = $SmallFastModel
        protocol = $Protocol
        workDir = $projectDir
    }
    [IO.File]::WriteAllText((Join-Path $destination 'profile.json'), ($profile | ConvertTo-Json), $utf8)
    # 模板不插入用户输入，路径由 cmd 的 %~dp0 取得；禁用 delayed expansion 保留 !。
    $launcher = @'
@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-proxy.ps1" -InstanceDir "%~dp0." -SkipUpdate %*
set "LAUNCH_EXIT=%errorlevel%"
if not "%LAUNCH_EXIT%"=="0" echo Launch failed. Exit code: %LAUNCH_EXIT%
if not defined CLAUDE_PROXY_NO_PAUSE pause
exit /b %LAUNCH_EXIT%
'@
    [IO.File]::WriteAllText((Join-Path $destination 'launch.bat'), (($launcher -replace '\r?\n', "`r`n") + "`r`n"), $utf8)
    [IO.File]::WriteAllText((Join-Path $destination '.gitignore'), "*`n", $utf8)
    Write-Host "已生成：$destination" -ForegroundColor Green
    Write-Host '双击里面的 launch.bat。第一次启动会要求输入 Key，之后保存在此实例的 .env。'
    Write-Host 'config 保存 Claude 配置与会话；workspace 是默认工作目录。完整文件夹可移动，包含 Key 时不要外发。'
    Write-Host '修改接口或模型：编辑 profile.json；换 Key：删除该实例 .env 后重新启动。'
} catch {
    Write-Host "创建失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
