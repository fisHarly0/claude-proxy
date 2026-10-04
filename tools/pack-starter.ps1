# 打包可拷贝到新电脑的轻量入口，不包含依赖安装包或任何用户配置。
param([Parameter(Mandatory = $true)][string]$OutDir)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = [IO.File]::ReadAllText((Join-Path $root 'VERSION')).Trim()
[IO.Directory]::CreateDirectory($OutDir) | Out-Null
$stage = Join-Path $OutDir ('starter-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($stage) | Out-Null
$files = @('开始使用.bat', 'setup.bat', 'launcher-gui.ps1', 'launcher-support.ps1', 'new-launcher.ps1', 'create-launcher.bat', 'claude-proxy.ps1', 'VERSION', 'LICENSE', 'README.md', 'TUTORIAL.md', 'providers.local.example.ps1', 'tools/prepare-instance.ps1')
foreach ($file in $files) {
    $destination = Join-Path $stage $file
    [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $destination
}
$archive = Join-Path $OutDir ("claude-proxy-starter-v$version.zip")
if (Test-Path -LiteralPath $archive) { throw '目标 ZIP 已存在，请使用新的输出目录。' }
Compress-Archive -LiteralPath @(Get-ChildItem -LiteralPath $stage | ForEach-Object FullName) -DestinationPath $archive
Write-Host "新电脑使用包：$archive"
Write-Host '解压完整文件夹，双击 开始使用.bat。首次安装需联网。'
