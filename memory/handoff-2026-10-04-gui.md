# 2026-10-04 图形化新电脑入口交接

## 结果与范围

用户要求进一步小白化：新电脑直接打开后一个按钮完成配置和启动，明确首页默认第三方自定义 API。已实现开始使用.bat / setup.bat 图形入口，运行环境准备、DPAPI Key、实例保存、已有配置更新、取消和重试、桌面入口、自动启动。保留独立实例和旧 CLI。主脚本版本 1.5.0。

新增 UI/后台：launcher-gui.ps1、launcher-support.ps1、tools/prepare-instance.ps1。主脚本增加 PrepareOnly、加密 Key 读取、原生安装和安装后 PATH 补充。new-launcher.ps1 增加 ValidateOnly 复用校验。打包白名单与 release-gate 同步。Windows Forms 无额外 GUI 运行库依赖。

官方安装脚本已只读下载审阅（F:\Codex\work\claude-proxy-gui-audit\official-install.ps1）；实现固定 https://downloads.claude.ai/claude-code-releases 发布源、严格版本和 manifest SHA256 校验，不下载执行远程 PowerShell 内容。实际开发验证未调用真实安装器。

## 验证证据

- tools/test-instances.ps1：36 项通过，目录 F:\Codex\work\claude-proxy-validation\instances-aeef33625e9d4badafab841e3e4cd96b。
- tools/test-gui-setup.ps1：22 项通过，目录 F:\Codex\work\claude-proxy-validation\gui-206a2d296cc04c2b8694403dd531120f。覆盖加密、保留 Key/用户文件、后台状态、快捷方式、校验失败不执行、校验成功调用安装与清理。
- tools/test-window.ps1：8 项实际表单操作通过，目录 F:\Codex\work\claude-proxy-validation\window-4bdadc0f24e44884b113adb5f1001816。操作真实控件，后台走真实脚本，仅 Claude/安装及桌面创建的外部边界替换为测试实现；验证错误修正后一个按钮完成准备并发起启动、再启动免 Key。
- release-gate：PASS。仓库真实 .env/providers.local.ps1 仅检查存在性，未读取。
- 截图 F:\Codex\work\claude-proxy-gui-audit\{idle,working,failed,small}-final.png。独立界面检查提出小屏尺寸和错误恢复两项修正，复核均 resolved，ship 仅覆盖这两项。设计事实存 DESIGN.md 与 .impeccable/design.json，原生 Windows 无 HTML/CSS 组件。
- Git diff 检查：git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol -c core.safecrlf=false diff --check。
- 轻量 ZIP 共 13 项白名单文件，不含用户实例/密钥/缓存。已解压启动 GUI，主脚本/GUI/支持库/worker hash 与源码一致。

## 交付与未验证

包：F:\Codex\work\claude-proxy-release\20261004-v1.5.0\claude-proxy-starter-v1.5.0.zip。全部解压后双击开始使用.bat。首次安装依赖联网；Windows/Claude 本人的许可及信任步骤仍需用户确认。

未运行真实 API、未在干净新机安装、未在真实高 DPI 硬件验证；OpenAI 转换未升级为已验证兼容。单击成功仅意味着运行环境准备并发起 Claude 进程启动，不代表模型/工具调用通过验收。

Git master / da2d492，本轮与上一轮修改均未 commit / push / 发布。没有更名仓库，没有读取真实 Key，没有写入用户桌面快捷方式（测试使用临时桌面替身）。没有遗留已知运行中的测试进程。
