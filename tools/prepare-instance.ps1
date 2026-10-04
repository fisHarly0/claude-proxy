param([Parameter(Mandatory = $true)][string]$RequestPath)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'launcher-support.ps1')
$jobDir = Split-Path -Parent $RequestPath
$utf8 = [Text.UTF8Encoding]::new($false)
function Report($stage, $message, $instance = '') {
    $value = @{ stage = $stage; message = $message; instancePath = $instance } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $jobDir 'status.json'), $value, $utf8)
}
try {
    Report 'working' '正在保存这套 API 配置…'
    $request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $instance = Save-LauncherProfile -Request $request -Root $root
    Report 'working' '正在检查并安装运行环境，首次下载可能需要几分钟…' $instance
    $env:CLAUDE_PROXY_CACHE_DIR = Join-Path $jobDir 'cache'
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $instance 'claude-proxy.ps1') -InstanceDir $instance -PrepareOnly -SkipUpdate
    if ($LASTEXITCODE -ne 0) { throw '环境准备失败' }
    Report 'ready' '配置已保存，运行环境已就绪。' $instance
    exit 0
} catch {
    # 不输出异常原文；请求 JSON 和外部命令错误可能含用户填写内容。
    $message = if ($instance) { '运行环境还未准备好。请检查网络或系统安装限制，查看安装日志后重试。API 配置已保存。' } else { '配置未保存。请检查名称、API 地址格式、模型和保存位置；重新填写 Key 后重试。' }
    # 只允许受控消息进入界面，绝不透传 JSON/系统异常中的用户输入。
    $safeMessages = @(
        'API 地址格式不正确。请填写 http(s) 开头的基础地址，不要包含 Key 或查询参数。',
        '这个名称已经存在。请从上方选择已有配置，或换一个名称。',
        '名称、接口地址、模型或项目目录无效，请检查填写内容。',
        '请填写 API Key。', 'Key 保存失败，请重新填写 Key。',
        '所选配置已经被移动或删除，请重新选择。',
        '所选文件夹不是有效的 Anthropic 兼容实例。',
        '无法创建实例。请换一个名称，或选择可写入的保存位置。'
    )
    if ($safeMessages -contains $_.Exception.Message) { $message = $_.Exception.Message }
    Report 'failed' $message $instance
    exit 1
}
