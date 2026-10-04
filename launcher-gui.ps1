param(
    [string]$ProfileRoot = (Join-Path $PSScriptRoot 'launchers'),
    [string]$PreviewPath,
    [int]$PreviewHeight = 0,
    [ValidateSet('idle', 'working', 'failed')][string]$PreviewState = 'idle'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'launcher-support.ps1')
[Windows.Forms.Application]::EnableVisualStyles()
$script:profiles = @()
$script:job = $null
$script:jobDir = $null
$script:selectedInstance = $null
$script:readyInstance = $null
$script:working = $false
$ink = [Drawing.ColorTranslator]::FromHtml('#202C39')
$muted = [Drawing.ColorTranslator]::FromHtml('#506071')
$accent = [Drawing.ColorTranslator]::FromHtml('#176B56')
$form = New-Object Windows.Forms.Form
$form.Text = 'claude-proxy · 配置并启动'
$form.ClientSize = New-Object Drawing.Size(680, 750)
$form.MinimumSize = New-Object Drawing.Size(600, 480)
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.BackColor = [Drawing.Color]::White
$form.ForeColor = $ink
$form.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10)
$form.Padding = New-Object Windows.Forms.Padding(28, 22, 28, 22)
$scroll = New-Object Windows.Forms.Panel
$scroll.Dock = 'Fill'
$scroll.AutoScroll = $true
$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock = 'Top'
$layout.AutoSize = $true
$layout.AutoSizeMode = 'GrowAndShrink'
$layout.ColumnCount = 1
$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 100))) | Out-Null
$scroll.Controls.Add($layout)
$form.Controls.Add($scroll)
function Fit-Window([int]$preferredHeight) {
    $area = [Windows.Forms.Screen]::FromControl($form).WorkingArea
    $form.ClientSize = New-Object Drawing.Size([Math]::Min(680, $area.Width - 50), [Math]::Min($preferredHeight, $area.Height - 80))
}
Fit-Window 750

function Add-Row($control, [int]$height) {
    $row = $layout.RowCount
    $layout.RowCount++
    $layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute', $height))) | Out-Null
    $control.Dock = 'Fill'
    $control.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 6)
    $layout.Controls.Add($control, 0, $row)
}
function Make-Label([string]$text) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $text
    $label.AutoSize = $false
    $label.TextAlign = 'MiddleLeft'
    return $label
}
function Add-Field([string]$label, [bool]$password = $false) {
    Add-Row (Make-Label $label) 27
    $box = New-Object Windows.Forms.TextBox
    $box.UseSystemPasswordChar = $password
    $box.AccessibleName = $label
    Add-Row $box 38
    return $box
}
$heading = Make-Label '把这套 API 配好，直接开始用。'
$heading.Font = New-Object Drawing.Font('Microsoft YaHei UI', 20, [Drawing.FontStyle]::Bold)
Add-Row $heading 53
$intro = Make-Label '填好下面的信息，其余交给程序：准备环境、独立保存配置、打开 Claude。'
$intro.ForeColor = $muted
Add-Row $intro 48
$instances = New-Object Windows.Forms.ComboBox
$instances.DropDownStyle = 'DropDownList'
$instances.AccessibleName = '选择已有配置或新增 API'
Add-Row $instances 38
$nameBox = Add-Field '给这套 API 起个名字'
$urlBox = Add-Field 'API 基础地址（服务商提供的 Anthropic 兼容地址）'
$modelBox = Add-Field '模型名称（按服务商提供的名称填写）'
$keyBox = Add-Field 'API Key（仅保存在这台电脑，输入不会显示）' $true
$keyHint = Make-Label '第一次填写 Key；选择已有配置时，留空表示继续用原来的 Key。'
$keyHint.ForeColor = $muted
Add-Row $keyHint 35
$advancedLink = New-Object Windows.Forms.LinkLabel
$advancedLink.Text = '更多选项：保存位置和代码项目'
$advancedLink.LinkColor = $accent
Add-Row $advancedLink 31
$advanced = New-Object Windows.Forms.TableLayoutPanel
$advanced.ColumnCount = 2
$advanced.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 100))) | Out-Null
$advanced.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Absolute', 90))) | Out-Null
$advanced.RowCount = 2
$storageBox = New-Object Windows.Forms.TextBox
$storageBox.Text = $ProfileRoot
$storageBox.ReadOnly = $true
$storageBox.AccessibleName = '实例保存位置'
$workBox = New-Object Windows.Forms.TextBox
$workBox.AccessibleName = '代码项目目录，留空自动创建'
$storageBrowse = New-Object Windows.Forms.Button
$storageBrowse.Text = '保存位置'
$workBrowse = New-Object Windows.Forms.Button
$workBrowse.Text = '代码项目'
foreach ($c in @($storageBox, $workBox, $storageBrowse, $workBrowse)) { $c.Dock = 'Fill' }
$advanced.Controls.Add($storageBox, 0, 0); $advanced.Controls.Add($storageBrowse, 1, 0)
$advanced.Controls.Add($workBox, 0, 1); $advanced.Controls.Add($workBrowse, 1, 1)
$advancedRow = $layout.RowCount
Add-Row $advanced 0
$advanced.Visible = $false
$advancedLink.Add_LinkClicked({
    $advanced.Visible = -not $advanced.Visible
    $layout.RowStyles[$advancedRow].Height = $(if ($advanced.Visible) { 80 } else { 0 })
    Fit-Window $(if ($advanced.Visible) { 830 } else { 750 })
})
$status = Make-Label '准备好后，点击下方按钮。首次安装需要联网。'
$status.ForeColor = $muted
Add-Row $status 57
$progress = New-Object Windows.Forms.ProgressBar
$progress.Style = 'Marquee'
$progress.Visible = $false
Add-Row $progress 13
$main = New-Object Windows.Forms.Button
$main.Text = '配置并启动 Claude'
$main.BackColor = $accent
$main.ForeColor = [Drawing.Color]::White
$main.FlatStyle = 'Flat'
$main.FlatAppearance.BorderSize = 0
$main.Font = New-Object Drawing.Font('Microsoft YaHei UI', 12, [Drawing.FontStyle]::Bold)
$main.Dock = 'Bottom'
$main.Height = 48
$form.Controls.Add($main)
$scroll.BringToFront()
$form.AcceptButton = $main
$footer = Make-Label '每套 API 独立保存配置和会话。安装完成后会创建桌面启动入口。'
$footer.ForeColor = $muted
Add-Row $footer 38
$logLink = New-Object Windows.Forms.LinkLabel
$logLink.Text = '查看安装日志'
$logLink.LinkColor = $accent
$logLink.Visible = $false
Add-Row $logLink 28
$cancelLink = New-Object Windows.Forms.LinkLabel
$cancelLink.Text = '取消准备'
$cancelLink.LinkColor = $muted
$cancelLink.Visible = $false
Add-Row $cancelLink 28

function Refresh-Instances([string]$selectPath = '') {
    $script:profiles = @()
    $instances.Items.Clear()
    $instances.Items.Add('＋ 新增一套自定义 API') | Out-Null
    if (Test-Path -LiteralPath $storageBox.Text) {
        foreach ($dir in Get-ChildItem -LiteralPath $storageBox.Text -Directory) {
            $p = Join-Path $dir.FullName 'profile.json'
            if (Test-Path -LiteralPath $p) {
                try {
                    $profile = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($profile.schemaVersion -eq 1 -and $profile.protocol -eq 'anthropic' -and $profile.name -eq $dir.Name) {
                        $script:profiles += @{ path = $dir.FullName; data = $profile }
                        $instances.Items.Add($dir.Name) | Out-Null
                    }
                } catch { }
            }
        }
    }
    $instances.SelectedIndex = 0
    for ($i = 0; $i -lt $script:profiles.Count; $i++) {
        if ($script:profiles[$i].path -eq $selectPath) { $instances.SelectedIndex = $i + 1; break }
    }
}
function Set-Working([bool]$value) {
    $script:working = $value
    foreach ($control in @($instances, $nameBox, $urlBox, $modelBox, $keyBox, $storageBrowse, $workBrowse, $workBox, $main)) { $control.Enabled = -not $value }
    if (-not $value -and $script:selectedInstance) { $nameBox.Enabled = $false }
    $progress.Visible = $value
    $cancelLink.Visible = $value
    $main.Text = $(if ($value) { '正在准备，请稍候…' } else { '配置并启动 Claude' })
}
$instances.Add_SelectedIndexChanged({
    $keyBox.Clear()
    $script:readyInstance = $null
    if ($instances.SelectedIndex -gt 0) {
        $p = $script:profiles[$instances.SelectedIndex - 1]
        $script:selectedInstance = $p.path
        $nameBox.Text = $p.data.name
        $urlBox.Text = $p.data.baseUrl
        $modelBox.Text = $p.data.model
        $workBox.Text = $(if ($p.data.workDir -eq 'workspace') { '' } elseif ([IO.Path]::IsPathRooted($p.data.workDir)) { $p.data.workDir } else { Join-Path $p.path $p.data.workDir })
        $nameBox.Enabled = $false
    } else {
        $script:selectedInstance = $null
        $nameBox.Enabled = $true
        foreach ($box in @($nameBox, $urlBox, $modelBox, $workBox)) { $box.Clear() }
    }
})
$storageBrowse.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择保存所有独立 API 实例的文件夹'
    if ($dialog.ShowDialog() -eq 'OK') { $storageBox.Text = $dialog.SelectedPath; Refresh-Instances }
    $dialog.Dispose()
})
$workBrowse.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择已有代码项目；不选择则自动创建独立工作目录'
    if ($dialog.ShowDialog() -eq 'OK') { $workBox.Text = $dialog.SelectedPath }
    $dialog.Dispose()
})
$logLink.Add_LinkClicked({
    if ($script:jobDir) { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + (Join-Path $script:jobDir 'install.log') + '"') }
})
function Stop-Preparation {
    if ($script:job -and -not $script:job.HasExited) {
        # 只结束本窗口创建的后台任务树；不扫描或清理其他实例。
        & taskkill.exe /PID $script:job.Id /T /F 2>$null | Out-Null
    }
    if ($script:job) { $script:job.Dispose(); $script:job = $null }
    Set-Working $false
    $target = Join-Path $storageBox.Text $nameBox.Text.Trim()
    if (Test-Path -LiteralPath (Join-Path $target 'profile.json')) { Refresh-Instances $target }
    $status.Text = '已取消准备。已保存的配置会保留；再次点击可重试。'
    $main.Text = '重试配置并启动'
}
$cancelLink.Add_LinkClicked({ Stop-Preparation })
$main.Add_Click({
    try {
        foreach ($box in @($nameBox, $urlBox, $modelBox)) {
            if ([string]::IsNullOrWhiteSpace($box.Text)) { $status.Text = '请先填写名称、API 地址和模型。'; $box.Focus(); return }
        }
        if (-not $script:selectedInstance -and [string]::IsNullOrWhiteSpace($keyBox.Text)) { $status.Text = '请填写这套 API 的 Key。'; $keyBox.Focus(); return }
        $cipher = ''
        if ($keyBox.Text) {
            $clean = $keyBox.Text -replace '[\s\p{C}]', ''
            if (-not $clean) { $status.Text = 'Key 不能只包含空格。'; return }
            $secure = ConvertTo-SecureString $clean -AsPlainText -Force
            $cipher = ConvertFrom-SecureString $secure
            $secure.Dispose()
            $clean = $null
        }
        $script:jobDir = Join-Path $storageBox.Text ('.setup-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($script:jobDir) | Out-Null
        $request = @{
            name = $nameBox.Text.Trim(); baseUrl = $urlBox.Text.Trim(); model = $modelBox.Text.Trim()
            keyCipher = $cipher; outputDir = $storageBox.Text; workDir = $workBox.Text.Trim()
            mode = $(if ($script:selectedInstance) { 'existing' } else { 'new' })
        }
        $requestPath = Join-Path $script:jobDir 'request.json'
        [IO.File]::WriteAllText($requestPath, ($request | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
        $keyBox.Clear()
        $argsText = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $PSScriptRoot 'tools\prepare-instance.ps1') + '" -RequestPath "' + $requestPath + '"'
        $script:job = Start-Process powershell.exe -ArgumentList $argsText -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $script:jobDir 'install.log') -RedirectStandardError (Join-Path $script:jobDir 'error.log')
        $status.ForeColor = $muted
        $status.Text = '正在保存配置并检查运行环境…'
        $logLink.Visible = $true
        Set-Working $true
    } catch {
        Set-Working $false
        $status.ForeColor = [Drawing.Color]::Firebrick
        $status.Text = '无法开始。请在“更多选项”中选择可以写入的保存位置，重新填写 Key 后重试。'
    }
})
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({
    if (-not $script:job) { return }
    $result = $null
    try {
        $statusPath = Join-Path $script:jobDir 'status.json'
        if (Test-Path -LiteralPath $statusPath) {
            $result = Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $status.Text = $result.message
            if ($result.instancePath) { $script:readyInstance = $result.instancePath }
        }
    } catch { $result = $null }
    if (-not $script:job.HasExited) { return }
    $script:job.Dispose()
    $script:job = $null
    Set-Working $false
    $selected = $script:readyInstance
    if ($selected) { Refresh-Instances $selected }
    if ($result -and $result.stage -eq 'ready') {
        try {
            $shortcut = $false
            try { $shortcut = New-LauncherShortcut -InstancePath $selected } catch { }
            # 用户实际要操作的 Claude 终端是可见窗口；安装后台仍隐藏。
            Start-Process powershell.exe -WorkingDirectory $selected -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $selected 'claude-proxy.ps1') + '" -InstanceDir "' + $selected + '" -SkipChecks -SkipUpdate')
            $status.ForeColor = $accent
            $status.Text = $(if ($shortcut) { '已打开 Claude。以后双击桌面的对应快捷方式即可。' } else { '已打开 Claude。以后双击实例文件夹中的 launch.bat 即可。' })
        } catch { $status.Text = '配置已完成，但未能打开窗口。请双击实例文件夹中的 launch.bat。' }
    } else {
        $status.ForeColor = [Drawing.Color]::Firebrick
        $status.Text = $(if ($result -and $result.stage -eq 'failed') { $result.message } else { '准备过程意外结束。请查看安装日志，检查网络后重试。' })
        $main.Text = '重试配置并启动'
    }
})
$form.Add_FormClosing({
    param($sender, $eventArgs)
    if ($script:working) {
        $answer = [Windows.Forms.MessageBox]::Show('正在准备环境。关闭窗口会取消本次准备，已保存的配置会保留。是否关闭？', '取消并关闭', 'YesNo', 'Question')
        if ($answer -eq 'Yes') { Stop-Preparation } else { $eventArgs.Cancel = $true }
    }
})
Refresh-Instances
if ($PreviewPath) {
    # 仅用于本地视觉验收；不访问 API，不启动安装或读取任何 Key。
    if ($PreviewState -eq 'working') { Set-Working $true; $status.Text = '正在检查并安装运行环境，首次下载可能需要几分钟…' }
    if ($PreviewState -eq 'failed') { $status.Text = '无法连接下载服务。请检查网络后重试，已保存的配置会保留。'; $status.ForeColor = [Drawing.Color]::Firebrick; $main.Text = '重试配置并启动' }
    if ($PreviewHeight -gt 0) { Fit-Window $PreviewHeight }
    $form.Show()
    [Windows.Forms.Application]::DoEvents()
    $bitmap = New-Object Drawing.Bitmap($form.Width, $form.Height)
    $form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
    $bitmap.Save($PreviewPath, [Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $script:working = $false
    $form.Close()
} else {
    $timer.Start()
    [void]$form.ShowDialog()
    $timer.Stop()
}
$timer.Dispose()
$form.Dispose()
