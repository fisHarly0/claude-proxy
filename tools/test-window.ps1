# 实际构建表单并触发主按钮。使用独立源码副本、虚构 Key 和命令替身，不安装程序。
param([Parameter(Mandatory = $true)][string]$ScratchDir)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $ScratchDir ('window-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $testRoot 'tools')) | Out-Null
foreach ($file in @('launcher-gui.ps1', 'launcher-support.ps1', 'new-launcher.ps1', 'claude-proxy.ps1', 'VERSION', 'LICENSE', 'tools/prepare-instance.ps1')) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $testRoot $file)
}
$mock = Join-Path $testRoot 'mock-bin'
[IO.Directory]::CreateDirectory($mock) | Out-Null
[IO.File]::WriteAllText((Join-Path $mock 'claude.cmd'), "@echo off`r`necho test-version`r`nexit /b 0`r`n")
[IO.File]::WriteAllText((Join-Path $mock 'git.cmd'), "@echo off`r`nexit /b 0`r`n")
$uiPath = Join-Path $testRoot 'launcher-gui.ps1'
$source = [IO.File]::ReadAllText($uiPath) -replace "`r`n", "`n"
$marker = 'Refresh-Instances' + "`n" + 'if ($PreviewPath)'
$end = $source.LastIndexOf($marker)
if ($end -lt 0) { throw '无法定位 UI 启动边界。' }
$tail = @'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Refresh-Instances
$script:openedClaude = $false
$script:uiChecks = 0
function Assert-UI($condition, $label) {
    if (-not $condition) { throw "FAIL: $label" }
    $script:uiChecks++
    Write-Host "PASS: $label"
}
function Start-Process {
    param([Parameter(Position=0)]$FilePath, $ArgumentList, $WindowStyle, [switch]$PassThru, $RedirectStandardOutput, $RedirectStandardError, $WorkingDirectory)
    if ($ArgumentList -like '*prepare-instance.ps1*') {
        return (Microsoft.PowerShell.Management\Start-Process @PSBoundParameters)
    }
    if ($ArgumentList -like '*claude-proxy.ps1*') { $script:openedClaude = $true; return }
    throw 'Unexpected process'
}
function New-LauncherShortcut { param($InstancePath) return $true }
function Wait-UI {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($script:job -and $watch.Elapsed.TotalSeconds -lt 20) {
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }
    if ($script:job) { Stop-Preparation; throw 'UI timeout' }
}
try {
    $form.Show()
    $timer.Start()
    [Windows.Forms.Application]::DoEvents()
    $main.PerformClick()
    Assert-UI ($status.Text -like '*请先填写*' -and -not $script:job) '空表单提示必填项，不创建后台任务'
    $nameBox.Text = '窗口测试'
    $urlBox.Text = 'bad-url'
    $modelBox.Text = 'test-model'
    $keyBox.Text = 'fake-window-key'
    $main.PerformClick()
    Assert-UI ($script:working -and -not $main.Enabled) '点击后进入后台工作状态，防止重复提交'
    Wait-UI
    Assert-UI ($status.Text -like '*API 地址格式不正确*' -and $main.Enabled) '地址错误显示具体提示并恢复重试'
    Assert-UI (-not $script:openedClaude) '配置失败不会打开 Claude'
    $urlBox.Text = 'https://example.invalid/anthropic'
    $keyBox.Text = 'fake-window-key'
    $main.PerformClick()
    Wait-UI
    Assert-UI ($script:openedClaude -and $status.Text -like '*已打开 Claude*') '同一个主按钮完成保存、准备和打开会话'
    Assert-UI ($instances.SelectedIndex -gt 0 -and $keyBox.Text -eq '') '完成后选中已有配置并清空 Key 输入'
    $script:openedClaude = $false
    $main.PerformClick()
    Wait-UI
    Assert-UI $script:openedClaude '已有配置留空 Key 可以再次一键启动'
    Fit-Window 560
    [Windows.Forms.Application]::DoEvents()
    Assert-UI ($main.Bottom -le $form.ClientSize.Height -and $main.Top -gt 0) '小窗口下主按钮始终位于可见区域'
    Write-Host "通过 $script:uiChecks 项实际表单操作检查。"
} finally {
    if ($script:job) { Stop-Preparation }
    $timer.Stop()
    $script:working = $false
    $form.Close()
    $timer.Dispose()
    $form.Dispose()
}
'@
[IO.File]::WriteAllText($uiPath, ($source.Substring(0, $end) + $tail), [Text.UTF8Encoding]::new($true))
$info = New-Object Diagnostics.ProcessStartInfo
$info.FileName = 'powershell.exe'
$info.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "' + $uiPath + '" -ProfileRoot "' + (Join-Path $testRoot 'profiles') + '"'
$info.UseShellExecute = $false; $info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
$info.EnvironmentVariables['PATH'] = $mock + ';' + $env:PATH
$process = New-Object Diagnostics.Process
$process.StartInfo = $info
$null = $process.Start()
$out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(60000)) { $process.Kill(); throw '窗口测试超时。' }
Write-Output ($out.Result + $err.Result)
if ($process.ExitCode -ne 0) { throw '窗口操作测试失败。' }
Write-Host "窗口验证目录：$testRoot"
