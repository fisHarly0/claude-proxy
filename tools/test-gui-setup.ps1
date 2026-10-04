param([Parameter(Mandatory = $true)][string]$ScratchDir)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $ScratchDir ('gui-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$bom = [Text.UTF8Encoding]::new($true)
$checks = 0
function Assert($condition, $message) {
    if (-not $condition) { throw "FAIL: $message" }
    $script:checks++
    Write-Host "PASS: $message"
}
. (Join-Path $repo 'launcher-support.ps1')
$request = @{
    mode = 'new'; name = '测试 GUI'; baseUrl = 'https://example.invalid/anthropic'; model = 'test-model'
    outputDir = (Join-Path $testRoot 'profiles'); workDir = ''
    keyCipher = (ConvertTo-SecureString 'fake-gui-key' -AsPlainText -Force | ConvertFrom-SecureString)
}
$instance = Save-LauncherProfile -Request $request -Root $repo
Assert (Test-Path -LiteralPath (Join-Path $instance 'launch.bat')) 'GUI 配置能生成完整启动实例'
Assert (-not (Test-Path -LiteralPath (Join-Path $instance '.env'))) '图形方式不创建明文 Key 文件'
$cipher = [IO.File]::ReadAllText((Join-Path $instance 'api-key.dpapi'))
Assert ($cipher -notmatch 'fake-gui-key') '保存内容不含 Key 明文'
$secure = ConvertTo-SecureString $cipher
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { Assert ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) -eq 'fake-gui-key') '当前用户可解密保存的测试 Key' }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
[IO.File]::WriteAllText((Join-Path $instance 'config\keep.txt'), 'existing-session')
[IO.File]::WriteAllText((Join-Path $instance 'workspace\keep.txt'), 'existing-project')
$request.mode = 'existing'; $request.keyCipher = ''; $request.model = 'updated-model'
$null = Save-LauncherProfile -Request $request -Root $repo
Assert ([IO.File]::ReadAllText((Join-Path $instance 'api-key.dpapi')) -eq $cipher) '已有配置留空 Key 时保留原 Key'
Assert ((Get-Content -LiteralPath (Join-Path $instance 'profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json).model -eq 'updated-model') '已有配置可以修改模型'
Assert ((Test-Path -LiteralPath (Join-Path $instance 'config\keep.txt')) -and (Test-Path -LiteralPath (Join-Path $instance 'workspace\keep.txt'))) '更新保留会话和工作文件'
$request.keyCipher = (ConvertTo-SecureString 'fake-new-key' -AsPlainText -Force | ConvertFrom-SecureString)
$null = Save-LauncherProfile -Request $request -Root $repo
Assert ([IO.File]::ReadAllText((Join-Path $instance 'api-key.dpapi')) -ne $cipher) '可以替换已有 Key'
$request.mode = 'new'
try { $null = Save-LauncherProfile -Request $request -Root $repo; throw 'unexpected-success' }
catch { Assert ($_.Exception.Message -ne 'unexpected-success') '新增同名配置不能覆盖已有实例' }

# 模拟 Claude 只打印版本；PrepareOnly 必须不调用交互启动。
$mockBin = Join-Path $testRoot 'mock-bin'
[IO.Directory]::CreateDirectory($mockBin) | Out-Null
[IO.File]::WriteAllText((Join-Path $mockBin 'claude.cmd'), "@echo off`r`nif `"%~1`"==`"--version`" (echo test-version & exit /b 0)`r`necho UNEXPECTED_SESSION`r`nexit /b 91`r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $mockBin 'git.cmd'), "@echo off`r`nexit /b 0`r`n", $utf8)
function Run-Process($file, $arguments) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = 'powershell.exe'
    $info.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $file + '" ' + $arguments
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.EnvironmentVariables['PATH'] = $mockBin + ';' + $env:PATH
    $p = New-Object Diagnostics.Process; $p.StartInfo = $info
    $null = $p.Start()
    $out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(30000)) { $p.Kill(); throw '测试超时' }
    return @{ code = $p.ExitCode; text = ($out.Result + $err.Result) }
}
$run = Run-Process (Join-Path $instance 'claude-proxy.ps1') ('-InstanceDir "' + $instance + '" -PrepareOnly -SkipUpdate')
Assert ($run.code -eq 0 -and $run.text -notmatch 'UNEXPECTED_SESSION') '准备模式检查环境但不启动交互 Claude'
Assert ($run.text -notmatch 'fake-new-key') '准备日志不泄露 Key'

$jobDir = Join-Path $testRoot 'job'
[IO.Directory]::CreateDirectory($jobDir) | Out-Null
$request.mode = 'existing'; $request.keyCipher = ''
$requestPath = Join-Path $jobDir 'request.json'
[IO.File]::WriteAllText($requestPath, ($request | ConvertTo-Json), $utf8)
$run = Run-Process (Join-Path $repo 'tools\prepare-instance.ps1') ('-RequestPath "' + $requestPath + '"')
$status = Get-Content -LiteralPath (Join-Path $jobDir 'status.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($run.code -eq 0 -and $status.stage -eq 'ready' -and $status.instancePath -eq $instance) '后台完成保存和准备并报告可启动状态'
Assert ($run.text -notmatch 'fake-new-key') '后台过程不输出 Key'
$request.baseUrl = 'invalid-url'
[IO.File]::WriteAllText($requestPath, ($request | ConvertTo-Json), $utf8)
$run = Run-Process (Join-Path $repo 'tools\prepare-instance.ps1') ('-RequestPath "' + $requestPath + '"')
$status = Get-Content -LiteralPath (Join-Path $jobDir 'status.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($run.code -ne 0 -and $status.stage -eq 'failed') '后台验证失败有明确失败状态'
Assert ((Get-Content -LiteralPath (Join-Path $instance 'profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json).baseUrl -eq 'https://example.invalid/anthropic') '验证失败保留原来的有效配置'
$desktop = Join-Path $testRoot 'test-desktop'
[IO.Directory]::CreateDirectory($desktop) | Out-Null
Assert (New-LauncherShortcut -InstancePath $instance -DesktopPath $desktop) '可创建桌面启动入口'
Assert (Test-Path -LiteralPath (Join-Path $desktop 'Claude - 测试 GUI.lnk')) '快捷方式保存成功'

# 用 AST 只加载安装函数，不执行主脚本、不读取本地真实配置。
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'claude-proxy.ps1'), [ref]$null, [ref]$null)
$fn = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Install-ClaudeNative' }, $true)
. ([scriptblock]::Create($fn.Extent.Text))
$fakeExe = Join-Path $testRoot 'fake-installer.exe'
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class FakeInstaller {
    public static int Main(string[] args) {
        File.WriteAllText(Environment.GetEnvironmentVariable("INSTANCE_TEST_INSTALL_MARKER"), String.Join(" ", args));
        return 0;
    }
}
'@ -OutputAssembly $fakeExe -OutputType ConsoleApplication
$expectedHash = (Get-FileHash -LiteralPath $fakeExe -Algorithm SHA256).Hash
$script:badChecksum = $false
$script:badVersion = $false
$script:downloads = 0
function Invoke-RestMethod {
    param($Uri, $TimeoutSec, $ErrorAction)
    if ($Uri -match '/latest$') { if ($script:badVersion) { return '<html>error</html>' }; return '2.0.0' }
    $hash = if ($script:badChecksum) { '0' * 64 } else { $expectedHash }
    return @{ platforms = @{ 'win32-x64' = @{ checksum = $hash }; 'win32-arm64' = @{ checksum = $hash } } }
}
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec, $ErrorAction)
    $script:downloads++
    Copy-Item -LiteralPath $fakeExe -Destination $OutFile
}
function Test-ClaudeSmoke { return $true }
$originalCache = $env:CLAUDE_PROXY_CACHE_DIR
$originalPath = $env:PATH
$env:CLAUDE_PROXY_CACHE_DIR = Join-Path $testRoot 'download-cache'
$env:INSTANCE_TEST_INSTALL_MARKER = Join-Path $testRoot 'installed.txt'
try {
    $script:badVersion = $true
    Assert (-not (Install-ClaudeNative) -and $script:downloads -eq 0) '版本响应异常时不下载也不运行程序'
    $script:badVersion = $false; $script:badChecksum = $true
    Assert (-not (Install-ClaudeNative) -and $script:downloads -eq 1 -and -not (Test-Path -LiteralPath $env:INSTANCE_TEST_INSTALL_MARKER)) '校验失败时绝不执行下载文件'
    $script:badChecksum = $false
    Assert (Install-ClaudeNative) '验证通过时完成原生安装流程'
    Assert ([IO.File]::ReadAllText($env:INSTANCE_TEST_INSTALL_MARKER) -eq 'install stable') '原生安装运行 stable 安装参数'
    Assert (@(Get-ChildItem -LiteralPath $env:CLAUDE_PROXY_CACHE_DIR -File).Count -eq 0) '安装临时文件清理完成'
} finally {
    $env:PATH = $originalPath
    $env:CLAUDE_PROXY_CACHE_DIR = $originalCache
    Remove-Item Env:INSTANCE_TEST_INSTALL_MARKER -ErrorAction SilentlyContinue
}
Write-Host "通过 $checks 项 GUI / 安装流程检查。验证目录：$testRoot"
