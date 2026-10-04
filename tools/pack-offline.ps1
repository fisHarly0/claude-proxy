# ============================================================
#  pack-offline.ps1 — 生成「新电脑离线安装包」ZIP
#  用法（仓库根目录，需联网下载 Node 安装包一次）：
#    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pack-offline.ps1
#    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pack-offline.ps1 -NodeMirror
#    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pack-offline.ps1 -OutDir D:\dist
#
#  产出：dist\claude-proxy-offline-v<版本>-win-x64.zip
#  包内：setup.bat + claude-proxy.ps1 + 模板/文档 + node-*-x64.msi + 离线说明.md
#  【绝不】打包 .env / providers.local.ps1
# ============================================================
param(
    [switch]$NodeMirror,   # 优先用 npmmirror 下载 Node
    [string]$OutDir = "",  # 输出目录，默认 <repo>\dist
    [string]$NodeMsiPath = ""  # 已有 Node 安装包时跳过下载
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $OutDir) { $OutDir = Join-Path $root "dist" }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$ver = (Get-Content (Join-Path $root "VERSION") -Raw).Trim()
$zipName = "claude-proxy-offline-v$ver-win-x64.zip"
$zipPath = Join-Path $OutDir $zipName
$stage = Join-Path $OutDir ("stage-" + [guid]::NewGuid().ToString("N"))

Write-Host ""
Write-Host "  ====== 打包离线安装包 v$ver ======" -ForegroundColor Cyan

# ── 1. 拷贝脚本与文档（白名单，防止扫进密钥）──
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$include = @(
    "claude-proxy.ps1",
    "setup.bat",
    "create-launcher.bat",
    "new-launcher.ps1",
    "launcher-gui.ps1",
    "launcher-support.ps1",
    "开始使用.bat",
    "VERSION",
    "README.md",
    "TUTORIAL.md",
    "LICENSE",
    "providers.local.example.ps1"
)
foreach ($f in $include) {
    $src = Join-Path $root $f
    if (-not (Test-Path $src)) { throw "缺少 $f，先跑 tools/release-gate.ps1" }
    Copy-Item $src (Join-Path $stage $f) -Force
    Write-Host "  + $f"
}
[IO.Directory]::CreateDirectory((Join-Path $stage 'tools')) | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'tools\prepare-instance.ps1') -Destination (Join-Path $stage 'tools\prepare-instance.ps1')

# ── 2. Node 安装包 ──
$nodeDir = Join-Path $stage "node"
New-Item -ItemType Directory -Path $nodeDir -Force | Out-Null

function Get-NodeLtsUrl {
    param([switch]$PreferMirror)
    # 取 Node 官方 LTS 版本号（短超时，失败则回退一个已知 LTS 系列目录）
    $metaUrls = @(
        "https://nodejs.org/dist/index.json",
        "https://npmmirror.com/mirrors/node/index.json"
    )
    if ($PreferMirror) { [array]::Reverse($metaUrls) }
    foreach ($u in $metaUrls) {
        try {
            $json = Invoke-RestMethod -Uri $u -TimeoutSec 8
            $lts = $json | Where-Object { $_.lts } | Select-Object -First 1
            if ($lts -and $lts.version) {
                $v = $lts.version.TrimStart("v")
                if ($u -match "npmmirror") {
                    return "https://npmmirror.com/mirrors/node/v$v/node-v$v-x64.msi"
                }
                return "https://nodejs.org/dist/v$v/node-v$v-x64.msi"
            }
        } catch { continue }
    }
    return $null
}

if ($NodeMsiPath) {
    if (-not (Test-Path $NodeMsiPath)) { throw "找不到 -NodeMsiPath: $NodeMsiPath" }
    Copy-Item $NodeMsiPath (Join-Path $nodeDir (Split-Path -Leaf $NodeMsiPath)) -Force
    Write-Host "  + 使用本地 Node 安装包: $NodeMsiPath"
} else {
    $url = Get-NodeLtsUrl -PreferMirror:$NodeMirror
    if (-not $url) { throw "无法解析 Node LTS 下载地址（检查网络后重试，或用 -NodeMsiPath 指定本地 msi）" }
    $msiName = Split-Path -Leaf $url
    $msiPath = Join-Path $nodeDir $msiName
    Write-Host "  [下载] $url"
    Invoke-WebRequest -Uri $url -OutFile $msiPath -TimeoutSec 180
    if ((Get-Item $msiPath).Length -lt 1MB) { throw "Node 安装包下载不完整: $msiPath" }
    Write-Host "  + $msiName ($([math]::Round((Get-Item $msiPath).Length/1MB,1)) MB)"
}

# ── 3. 离线说明 ──
$readme = @"
# claude-proxy 离线安装包 v$ver

适用：新电脑、公司网络装不动 winget/npm、需要拷贝 U 盘/内网分发。

## 安装步骤（按顺序）

1. 运行 ``node\`` 里的 ``node-v*-x64.msi``，一路下一步（勾选默认即可）。
2. **关闭**安装完成的窗口，重新打开资源管理器进入本文件夹。
3. 双击 ``setup.bat``。
4. 若提示缺 Claude Code，联网时脚本会自动 ``npm install``；
   完全离线则需在有网机器上先装好 Claude Code 再拷用户目录，或用公司内网 npm 源。

> 默认 DeepSeek 走 Anthropic 直连，只需 Node + Claude Code + API key，
> **不需要** Python / LiteLLM。

## 出问题先跑体检

```
setup.bat -Doctor
```

把窗口文字原样复制求助（不会带出 API key）。

## 安全

- 本包**不含** ``.env``，请勿把配置好 key 的文件夹再打包外发。
- API key 等同账号密码，只在目标机器上粘贴一次。
"@
Set-Content -Path (Join-Path $stage "离线说明.md") -Value $readme -Encoding UTF8
Write-Host "  + 离线说明.md"

# ── 4. 压缩 ──
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -Force
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Remove-Item $stage -Recurse -Force

Write-Host ""
Write-Host "  完成: $zipPath ($sizeMB MB)" -ForegroundColor Green
Write-Host "  分发前请自测：解压到无 Node 的机器 → 装 Node → 双击 setup.bat → -Doctor" -ForegroundColor Gray
Write-Host ""
