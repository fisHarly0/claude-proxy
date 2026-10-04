# 图形入口与后台共用。Key 只接收 Windows 当前用户加密后的密文。
function Save-LauncherProfile {
    param([Parameter(Mandatory = $true)]$Request, [string]$Root = $PSScriptRoot)
    $ErrorActionPreference = 'Stop'
    $uri = $null
    if (-not [Uri]::TryCreate([string]$Request.baseUrl, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http', 'https') -or -not $uri.Host -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
        throw 'API 地址格式不正确。请填写 http(s) 开头的基础地址，不要包含 Key 或查询参数。'
    }
    $params = @{
        Name = [string]$Request.name; BaseUrl = [string]$Request.baseUrl
        Model = [string]$Request.model; Protocol = 'anthropic'
        OutputDir = [string]$Request.outputDir; NonInteractive = $true
    }
    if ($Request.workDir) { $params.WorkDir = [string]$Request.workDir }
    $global:LASTEXITCODE = 0
    & (Join-Path $Root 'new-launcher.ps1') @params -ValidateOnly
    if ($LASTEXITCODE -ne 0) { throw '名称、接口地址、模型或项目目录无效，请检查填写内容。' }
    $outputRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($params.OutputDir)
    $instancePath = Join-Path $outputRoot $params.Name
    if ($Request.mode -notin @('new', 'existing')) { throw '未知的配置操作。' }
    if ($Request.mode -eq 'new' -and (Test-Path -LiteralPath $instancePath)) {
        throw '这个名称已经存在。请从上方选择已有配置，或换一个名称。'
    }
    $hasKey = -not [string]::IsNullOrWhiteSpace([string]$Request.keyCipher)
    if ($hasKey) {
        try {
            $secure = ConvertTo-SecureString ([string]$Request.keyCipher) -ErrorAction Stop
            if ($secure.Length -eq 0) { throw 'empty' }
            $secure.Dispose()
        } catch { throw 'Key 保存失败，请重新填写 Key。' }
    }
    if ($Request.mode -eq 'existing') {
        $configPath = Join-Path $instancePath 'profile.json'
        if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw '所选配置已经被移动或删除，请重新选择。' }
        $old = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($old.name -ne $params.Name -or $old.schemaVersion -ne 1 -or $old.protocol -ne 'anthropic') { throw '所选文件夹不是有效的 Anthropic 兼容实例。' }
        if (-not $hasKey -and -not (Test-Path -LiteralPath (Join-Path $instancePath 'api-key.dpapi')) -and
            -not (Test-Path -LiteralPath (Join-Path $instancePath '.env'))) { throw '请填写 API Key。' }
    } else {
        if (-not $hasKey) { throw '请填写 API Key。' }
        $global:LASTEXITCODE = 0
        & (Join-Path $Root 'new-launcher.ps1') @params
        if ($LASTEXITCODE -ne 0) { throw '无法创建实例。请换一个名称，或选择可写入的保存位置。' }
    }
    $utf8 = [Text.UTF8Encoding]::new($false)
    if ($hasKey) {
        # Windows DPAPI 绑定当前用户；明文不会落盘，也不会进入进程参数。
        [IO.File]::WriteAllText((Join-Path $instancePath 'api-key.dpapi'), [string]$Request.keyCipher, $utf8)
    }
    $profile = [ordered]@{
        schemaVersion = 1; name = $params.Name; baseUrl = $params.BaseUrl.TrimEnd('/')
        model = $params.Model; smallFastModel = $(if ($old -and $old.smallFastModel) { $old.smallFastModel } else { $params.Model }); protocol = 'anthropic'
        workDir = $(if ($params.WorkDir) { (Get-Item -LiteralPath $params.WorkDir).FullName } else { 'workspace' })
    }
    # 覆盖所选实例的连接信息和运行文件；config/workspace 中的用户数据不动。
    foreach ($file in @('claude-proxy.ps1', 'VERSION')) {
        Copy-Item -LiteralPath (Join-Path $Root $file) -Destination (Join-Path $instancePath $file) -Force
    }
    [IO.File]::WriteAllText((Join-Path $instancePath 'profile.json'), ($profile | ConvertTo-Json), $utf8)
    return $instancePath
}

function New-LauncherShortcut {
    param([string]$InstancePath, [string]$DesktopPath = [Environment]::GetFolderPath('Desktop'))
    $shell = New-Object -ComObject WScript.Shell
    $name = Split-Path -Leaf $InstancePath
    $linkPath = Join-Path $DesktopPath ("Claude - $name.lnk")
    if (Test-Path -LiteralPath $linkPath) {
        $existing = $shell.CreateShortcut($linkPath)
        if ($existing.TargetPath -ne (Join-Path $InstancePath 'launch.bat')) { return $false }
    }
    $link = $shell.CreateShortcut($linkPath)
    $link.TargetPath = Join-Path $InstancePath 'launch.bat'
    $link.WorkingDirectory = $InstancePath
    $link.Description = "启动独立的 Claude Code：$name"
    $link.Save()
    return $true
}
