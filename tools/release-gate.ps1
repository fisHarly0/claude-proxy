# ============================================================
#  release-gate.ps1 — 发版前编码/版本/语法闸门
#  用法（仓库根目录）：
#    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\release-gate.ps1
#  退出码 0=通过；非 0=有阻塞项，禁止发版
# ============================================================
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$fail = 0
$warn = 0

function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:fail++ }
function Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warn++ }
function Ok($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }

Write-Host ""
Write-Host "  ====== claude-proxy release gate ======" -ForegroundColor Cyan

# ── 1. 必须存在的文件 ──
$required = @("claude-proxy.ps1", "setup.bat", "create-launcher.bat", "new-launcher.ps1", "launcher-gui.ps1", "launcher-support.ps1", "开始使用.bat", "tools/prepare-instance.ps1", "VERSION", "README.md", "TUTORIAL.md", "providers.local.example.ps1")
foreach ($f in $required) {
    $p = Join-Path $root $f
    if (Test-Path $p) { Ok "存在 $f" } else { Fail "缺少 $f" }
}

# ── 2. BOM / 换行 ──
function Test-Bom($path, $expectBom, $label) {
    if (-not (Test-Path $path)) { return }
    $b = [IO.File]::ReadAllBytes($path)
    $hasBom = $b.Length -ge 3 -and $b[0] -eq 239 -and $b[1] -eq 187 -and $b[2] -eq 191
    if ($expectBom -and -not $hasBom) { Fail "$label 缺少 UTF-8 BOM" }
    elseif (-not $expectBom -and $hasBom) { Fail "$label 不应带 BOM" }
    else { Ok "$label BOM 符合预期 (hasBom=$hasBom)" }
}

Test-Bom (Join-Path $root "claude-proxy.ps1") $true "claude-proxy.ps1"
Test-Bom (Join-Path $root "providers.local.example.ps1") $true "providers.local.example.ps1"
Test-Bom (Join-Path $root "setup.bat") $false "setup.bat"
Test-Bom (Join-Path $root "new-launcher.ps1") $true "new-launcher.ps1"
Test-Bom (Join-Path $root "create-launcher.bat") $false "create-launcher.bat"

$setupPath = Join-Path $root "setup.bat"
if (Test-Path $setupPath) {
    $text = [IO.File]::ReadAllText($setupPath)
    if ($text -notmatch "`r`n") { Fail "setup.bat 必须是 CRLF 换行" }
    else { Ok "setup.bat CRLF 正常" }
}

# ── 3. 版本号一致 ──
$verFile = (Get-Content (Join-Path $root "VERSION") -Raw).Trim()
$ps1 = Get-Content (Join-Path $root "claude-proxy.ps1") -Raw
if ($ps1 -match '\$SCRIPT_VERSION\s*=\s*"([^"]+)"') {
    $scriptVer = $Matches[1]
    if ($scriptVer -eq $verFile) { Ok "版本一致: $scriptVer" }
    else { Fail "VERSION ($verFile) != SCRIPT_VERSION ($scriptVer)" }
} else {
    Fail "无法从 claude-proxy.ps1 解析 SCRIPT_VERSION"
}

# ── 4. PowerShell 语法 ──
$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize($ps1, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    Fail "claude-proxy.ps1 语法错误 $($errors.Count) 处："
    $errors | Select-Object -First 5 | ForEach-Object { Write-Host "         $($_.Message)" -ForegroundColor Red }
} else {
    Ok "claude-proxy.ps1 语法解析通过"
}

# 新的入口也必须在 Windows PowerShell 5.1 可解析，批处理保留 CRLF。
$generator = Join-Path $root 'new-launcher.ps1'
if (Test-Path $generator) {
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($generator, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count) { Fail 'new-launcher.ps1 语法错误' }
    else { Ok 'new-launcher.ps1 语法解析通过' }
}
$creator = Join-Path $root 'create-launcher.bat'
if (Test-Path $creator) {
    $batchText = [IO.File]::ReadAllText($creator)
    if ($batchText -notmatch "`r`n" -or $batchText -match '(?<!\r)\n') { Fail 'create-launcher.bat 必须使用 CRLF' }
    else { Ok 'create-launcher.bat CRLF 正常' }
}

foreach ($file in @('launcher-gui.ps1', 'launcher-support.ps1', 'tools/prepare-instance.ps1')) {
    $path = Join-Path $root $file
    Test-Bom $path $true $file
    if (Test-Path -LiteralPath $path) {
        $parseErrors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count) { Fail "$file 语法错误" } else { Ok "$file 语法解析通过" }
    }
}
$entry = Join-Path $root '开始使用.bat'
Test-Bom $entry $false '开始使用.bat'
if (Test-Path -LiteralPath $entry) {
    $batchText = [IO.File]::ReadAllText($entry)
    if ($batchText -notmatch "`r`n" -or $batchText -match '(?<!\r)\n') { Fail '开始使用.bat 必须使用 CRLF' }
}

# ── 5. 禁止把密钥文件打进发布物 ──
foreach ($secret in @(".env", "providers.local.ps1")) {
    if (Test-Path (Join-Path $root $secret)) {
        Warn "工作区存在 $secret（本地正常；确认不要打进 ZIP / commit）"
    }
}

Write-Host ""
if ($fail -gt 0) {
    Write-Host "  ====== GATE FAIL：$fail 项阻塞，禁止发版 ======" -ForegroundColor Red
    exit 1
}
Write-Host "  ====== GATE PASS（警告 $warn）可以发版 ======" -ForegroundColor Green
exit 0
