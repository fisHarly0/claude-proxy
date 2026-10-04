# 离线集成测试：只使用临时目录、虚构 Key 和模拟 Claude，绝不调用真实 API。
param([Parameter(Mandatory = $true)][string]$ScratchDir)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ScratchDir) ('instances-' + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
$bom = [Text.UTF8Encoding]::new($true)
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$checks = 0

function Assert($condition, $message) {
    if (-not $condition) { throw "FAIL: $message" }
    $script:checks++
    Write-Host "PASS: $message"
}
function Write-TestFile($path, $content, [switch]$Script) {
    $encoding = if ($Script) { $bom } else { $utf8 }
    [IO.File]::WriteAllText($path, ($content -replace '\r?\n', "`r`n"), $encoding)
}
function Start-TestProcess([string]$scriptPath, [string]$arguments, [string]$label, [switch]$Batch) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = if ($Batch) { $env:ComSpec } else { 'powershell.exe' }
    $info.Arguments = if ($Batch) { '/d /c ""' + $scriptPath + '" ' + $arguments + '"' } else { '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $scriptPath + '" ' + $arguments }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.WorkingDirectory = $testRoot
    $info.EnvironmentVariables['PATH'] = $mockDir + ';' + $env:PATH
    $info.EnvironmentVariables['CLAUDE_PROXY_NO_PAUSE'] = '1'
    $info.EnvironmentVariables['ANTHROPIC_API_KEY'] = 'fake-stale-api-key'
    $info.EnvironmentVariables['ANTHROPIC_AUTH_TOKEN'] = 'fake-stale-token'
    $info.EnvironmentVariables['ANTHROPIC_DEFAULT_SONNET_MODEL'] = 'stale-model'
    $info.EnvironmentVariables['CLAUDE_CODE_OAUTH_TOKEN'] = 'fake-stale-oauth'
    $info.EnvironmentVariables['CLAUDE_CODE_USE_VERTEX'] = '1'
    $info.EnvironmentVariables['INSTANCE_API_KEY'] = 'fake-inherited-key'
    $info.EnvironmentVariables['INSTANCE_TEST_REPORT'] = Join-Path $testRoot ($label + '.json')
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    $null = $process.Start()
    return @{ Process = $process; Output = $process.StandardOutput.ReadToEndAsync(); Error = $process.StandardError.ReadToEndAsync(); Label = $label }
}
function Finish-TestProcess($run) {
    if (-not $run.Process.WaitForExit(30000)) {
        $run.Process.Kill()
        throw '测试进程超时。'
    }
    $output = $run.Output.Result + $run.Error.Result
    Write-TestFile (Join-Path $testRoot ($run.Label + '.log')) $output
    return @{ ExitCode = $run.Process.ExitCode; Output = $output }
}

# 建立模拟命令；只有这个命令会被测试启动器调用。
$mockDir = Join-Path $testRoot 'mock-bin'
[IO.Directory]::CreateDirectory($mockDir) | Out-Null
Write-TestFile (Join-Path $mockDir 'claude.cmd') @'
@echo off
set "INSTANCE_TEST_CWD=%CD%"
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0capture.ps1" %*
exit /b %errorlevel%
'@
Write-TestFile (Join-Path $mockDir 'capture.ps1') @'
$ErrorActionPreference = 'Stop'
$hash = [Security.Cryptography.SHA256]::Create()
$keyHash = [Convert]::ToBase64String($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($env:ANTHROPIC_AUTH_TOKEN)))
$start = [DateTime]::UtcNow.ToString('o')
Start-Sleep -Seconds 2
$result = @{
    config = $env:CLAUDE_CONFIG_DIR
    workDir = $env:INSTANCE_TEST_CWD
    keyHash = $keyHash
    model = $env:ANTHROPIC_MODEL
    sonnet = $env:ANTHROPIC_DEFAULT_SONNET_MODEL
    haiku = $env:ANTHROPIC_DEFAULT_HAIKU_MODEL
    baseUrl = $env:ANTHROPIC_BASE_URL
    cleared = (-not $env:ANTHROPIC_API_KEY -and -not $env:CLAUDE_CODE_OAUTH_TOKEN -and -not $env:CLAUDE_CODE_USE_VERTEX)
    arguments = @($args)
    start = $start
    finish = [DateTime]::UtcNow.ToString('o')
}
[IO.File]::WriteAllText((Join-Path $env:CLAUDE_CONFIG_DIR 'session-test.txt'), $keyHash)
[IO.File]::WriteAllText($env:INSTANCE_TEST_REPORT, ($result | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
exit 7
'@ -Script

$outputDir = Join-Path $testRoot '中文 & %TEST% ! [目录]'
$generator = Join-Path $repo 'new-launcher.ps1'
$names = @("工作 A's", '工作 B')
$model = 'model-$(noop);&value'
for ($i = 0; $i -lt 2; $i++) {
    $arguments = '-NonInteractive -Name "' + $names[$i] + '" -BaseUrl "https://example.invalid/anthropic" -Model "' + $model + '" -OutputDir "' + $outputDir + '"'
    $result = Finish-TestProcess (Start-TestProcess $generator $arguments ('generate-' + $i))
    Assert ($result.ExitCode -eq 0) "生成实例 $i"
    $folder = Join-Path $outputDir $names[$i]
    Assert (-not (Test-Path -LiteralPath (Join-Path $folder '.env'))) '生成时不复制仓库密钥'
    Write-TestFile (Join-Path $folder '.env') ("INSTANCE_API_KEY=fake-test-key-$i`n")
    # 实例模式即使旁边有遗留 provider 脚本，也不得执行它。
    Write-TestFile (Join-Path $folder 'providers.local.ps1') "throw 'MUST NOT LOAD LOCAL PROVIDERS'" -Script
}
$folderA = Join-Path $outputDir $names[0]
$folderB = Join-Path $outputDir $names[1]
$runA = Start-TestProcess (Join-Path $folderA 'launch.bat') '-SkipChecks --resume' 'launch-a' -Batch
$runB = Start-TestProcess (Join-Path $folderB 'launch.bat') '-SkipChecks --resume' 'launch-b' -Batch
$resultA = Finish-TestProcess $runA
$resultB = Finish-TestProcess $runB
Assert ($resultA.ExitCode -eq 7 -and $resultB.ExitCode -eq 7) '两个批处理均返回 Claude 的退出码'
$a = Get-Content -LiteralPath (Join-Path $testRoot 'launch-a.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$b = Get-Content -LiteralPath (Join-Path $testRoot 'launch-b.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($a.config -eq (Join-Path $folderA 'config') -and $b.config -eq (Join-Path $folderB 'config')) '同端点的配置目录互相独立'
Assert ($a.workDir -eq (Join-Path $folderA 'workspace') -and $b.workDir -eq (Join-Path $folderB 'workspace')) '默认工作目录互相独立'
$sha = [Security.Cryptography.SHA256]::Create()
Assert ($a.keyHash -eq [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('fake-test-key-0'))) -and
        $b.keyHash -eq [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('fake-test-key-1')))) '两个实例使用各自的虚构 Key'
Assert ($a.cleared -and $b.cleared) '继承的认证和路由变量已清除'
Assert ($a.model -eq $model -and $a.sonnet -eq $model -and $a.haiku -eq $model) '模型特殊字符按数据传递，别名指向本实例'
Assert ($a.arguments -contains '--resume' -and $b.arguments -contains '--resume') 'Claude 参数通过批处理传递'
Assert ([DateTime]$a.start -lt [DateTime]$b.finish -and [DateTime]$b.start -lt [DateTime]$a.finish) '两个实例确实同时运行'
Assert ($resultA.Output -notmatch 'fake-test-key' -and $resultB.Output -notmatch 'fake-test-key') '启动日志没有虚构 Key 明文'

# 复制整个生成目录模拟搬家，不移动或删除任何已有用户目录。
$relocated = Join-Path $testRoot '搬家之后'
Copy-Item -LiteralPath $folderA -Destination $relocated -Recurse
$result = Finish-TestProcess (Start-TestProcess (Join-Path $relocated 'launch.bat') '-SkipChecks' 'relocated' -Batch)
$moved = Get-Content -LiteralPath (Join-Path $testRoot 'relocated.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($result.ExitCode -eq 7 -and $moved.config -eq (Join-Path $relocated 'config') -and $moved.workDir -eq (Join-Path $relocated 'workspace')) '整个文件夹搬家后路径跟随新位置'

$externalProject = Join-Path $testRoot '已有项目 [测试]'
[IO.Directory]::CreateDirectory($externalProject) | Out-Null
$arguments = '-NonInteractive -Name external -BaseUrl https://example.invalid -Model test -WorkDir "' + $externalProject + '" -OutputDir "' + $outputDir + '"'
$result = Finish-TestProcess (Start-TestProcess $generator $arguments 'external-generate')
Assert ($result.ExitCode -eq 0) '可以选择已有项目目录'
$external = Join-Path $outputDir 'external'
Write-TestFile (Join-Path $external '.env') "INSTANCE_API_KEY=fake-test-key-external`n"
$result = Finish-TestProcess (Start-TestProcess (Join-Path $external 'launch.bat') '-SkipChecks' 'external-launch' -Batch)
$externalResult = Get-Content -LiteralPath (Join-Path $testRoot 'external-launch.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($result.ExitCode -eq 7 -and $externalResult.workDir -eq $externalProject) '已有项目路径按字面处理'

$result = Finish-TestProcess (Start-TestProcess $generator $arguments 'duplicate')
Assert ($result.ExitCode -ne 0) '同名实例不能覆盖'
Assert ((Get-Content -LiteralPath (Join-Path $external 'profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json).workDir -eq $externalProject) '重复生成保留原配置'
foreach ($invalid in @('../escape', 'CON', 'x.', 'a/b', 'NUL.txt')) {
    $arguments = '-NonInteractive -Name "' + $invalid + '" -BaseUrl https://example.invalid -Model test -OutputDir "' + $outputDir + '"'
    $result = Finish-TestProcess (Start-TestProcess $generator $arguments ('invalid-' + $checks))
    Assert ($result.ExitCode -ne 0) "拒绝非法实例名 $invalid"
}
foreach ($url in @('file:///C:/test', 'https://example.invalid?key=fake-secret', 'https://user:pass@example.invalid', 'invalid')) {
    $arguments = '-NonInteractive -Name bad-url -BaseUrl "' + $url + '" -Model test -OutputDir "' + $outputDir + '"'
    $result = Finish-TestProcess (Start-TestProcess $generator $arguments ('invalid-url-' + $checks))
    Assert ($result.ExitCode -ne 0) '拒绝无效或含凭据的 API 地址'
}

# 无密钥实例不得使用父进程的 INSTANCE_API_KEY；-NonInteractive 会让安全输入失败并退出。
$arguments = '-NonInteractive -Name no-key -BaseUrl https://example.invalid -Model test -OutputDir "' + $outputDir + '"'
$result = Finish-TestProcess (Start-TestProcess $generator $arguments 'no-key-generate')
$noKey = Join-Path $outputDir 'no-key'
$arguments = '-InstanceDir "' + $noKey + '" -SkipChecks -SkipUpdate'
$result = Finish-TestProcess (Start-TestProcess (Join-Path $noKey 'claude-proxy.ps1') $arguments 'no-key-launch')
Assert ($result.ExitCode -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $testRoot 'no-key-launch.json'))) '无本地 Key 时不能回退使用系统 Key'

# 用函数替换安全输入，仅注入虚构 Key，验证首次保存和再次免输入。
Write-TestFile (Join-Path $noKey 'first-run-test.ps1') @'
function Read-Host {
    param([switch]$AsSecureString)
    if (-not $AsSecureString) { throw 'Key input must be secure' }
    return (ConvertTo-SecureString 'fake-first-input' -AsPlainText -Force)
}
& (Join-Path $PSScriptRoot 'claude-proxy.ps1') -InstanceDir $PSScriptRoot -SkipChecks -SkipUpdate
exit $LASTEXITCODE
'@ -Script
$result = Finish-TestProcess (Start-TestProcess (Join-Path $noKey 'first-run-test.ps1') '' 'first-key-save')
Assert ($result.ExitCode -eq 7 -and (Test-Path -LiteralPath (Join-Path $noKey '.env'))) '首次安全输入后保存到实例目录'
Assert ($result.Output -notmatch 'fake-first-input') '首次保存不打印完整 Key'
$result = Finish-TestProcess (Start-TestProcess (Join-Path $noKey 'claude-proxy.ps1') $arguments 'saved-key-reuse')
$savedResult = Get-Content -LiteralPath (Join-Path $testRoot 'saved-key-reuse.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($result.ExitCode -eq 7 -and $savedResult.keyHash -eq [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('fake-first-input')))) '再次启动直接使用保存的 Key，不再询问'

$arguments = '-InstanceDir "' + $folderA + '" -SkipChecks -SharedConfig'
$result = Finish-TestProcess (Start-TestProcess (Join-Path $folderA 'claude-proxy.ps1') $arguments 'conflict')
Assert ($result.ExitCode -ne 0) '拒绝实例与共享配置混用'
Write-TestFile (Join-Path $relocated 'profile.json') '{broken fake-sensitive-value'
$arguments = '-InstanceDir "' + $relocated + '" -SkipChecks'
$result = Finish-TestProcess (Start-TestProcess (Join-Path $relocated 'claude-proxy.ps1') $arguments 'broken')
Assert ($result.ExitCode -ne 0 -and $result.Output -notmatch 'fake-sensitive-value') '损坏 JSON 不回显配置内容'

$bytes = [IO.File]::ReadAllBytes((Join-Path $folderA 'claude-proxy.ps1'))
Assert ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) '生成的主脚本保留 UTF-8 BOM'
$batch = [IO.File]::ReadAllText((Join-Path $folderA 'launch.bat'))
$bytes = [IO.File]::ReadAllBytes((Join-Path $folderA 'launch.bat'))
Assert ($bytes[0] -eq 64 -and $batch -match "`r`n" -and $batch -notmatch '(?<!\r)\n') '生成的批处理无 BOM 且使用 CRLF'

# 旧帮助入口在无用户配置的测试副本运行，避免读取原仓库真实配置。
$legacy = Join-Path $testRoot 'legacy'
[IO.Directory]::CreateDirectory($legacy) | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'claude-proxy.ps1') -Destination (Join-Path $legacy 'claude-proxy.ps1')
$result = Finish-TestProcess (Start-TestProcess (Join-Path $legacy 'claude-proxy.ps1') '-Help' 'legacy-help')
Assert ($result.ExitCode -eq 0 -and $result.Output -match 'SharedConfig') '旧命令行帮助入口继续可用'
Write-Host "通过 $checks 项检查。验证目录：$testRoot"
