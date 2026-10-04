# 当前状态 / Current State

更新时间：2026-10-04

- 定位：Windows 新电脑、多 API 的 Claude Code 图形配置启动器，保留 claude-proxy 名称。
- 用户最新确认：首页默认第三方自定义 API；填写必要信息后，一个按钮自动准备环境、保存独立配置并启动。
- 版本 v1.5.0。开发基线 master / da2d492；2026-10-04 用户已要求提交并推送本轮代码、测试和 README，发布闸门通过。本轮仅同步源码，不创建正式 Release。
- 主入口：开始使用.bat；无参数 setup.bat 也打开图形界面。create-launcher.bat / new-launcher.ps1 保留命令行入口。
- README 已按图形版重新整理：三步开始、多 API 隔离、日常操作、Key 与更新说明；旧 CLI 折叠收纳。已检查本地链接、代码块与 diff；本次文档修改未重新运行代码测试。此前打包的 ZIP 仍含当时的 README，后续分发需重新打包。
- UI：名称、Anthropic 兼容基础地址、模型、Key；已有配置可选择；更多选项可换存储/项目目录。后台安装、进度、取消、具体错误提示、重试；主按钮在小窗口固定底部。
- 图形 Key 使用 Windows 当前用户 DPAPI 保存到 api-key.dpapi；留空保留旧 Key。换电脑/用户需重新输入；旧 CLI .env 继续兼容。
- 安装优先使用官方原生发布源，manifest SHA256 校验后二进制安装；Node/npm 为后备。PrepareOnly 不进入会话；完成后启动可见 Claude 终端并尝试创建桌面快捷方式。
- 实例仍独立配置/会话和默认工作目录；共享代码项目会共享项目文件与设置。图形入口仅支持 Anthropic 兼容；OpenAI 转换仍为命令行实验功能。
- 验证：36 项实例回归 + 22 项后台/安装流程检查 + 8 项实际表单操作通过；PS5.1 编码/语法/版本门通过；轻量 ZIP 白名单、解压运行和源码 hash 一致性检查通过。
- 所有 API Key 和安装器均为测试伪值/替身，没有执行真实模型调用或在本机实际安装 Claude；未在干净 Windows 新机和真实高 DPI 硬件上验收。
- 分发包：F:\Codex\work\claude-proxy-release\20261004-v1.5.0\claude-proxy-starter-v1.5.0.zip。
- 规格：spec/modules/instances.md、spec/modules/gui-setup.md；界面事实 PRODUCT.md、DESIGN.md；详细交接 memory/handoff-2026-10-04-gui.md。

## 接手约束

- 禁止读取、回显或提交仓库 .env、providers.local.ps1 及真实 Key。测试仅使用 F 盘隔离目录内的虚构数据。
- PowerShell 必须 UTF-8 BOM，批处理 CRLF / 无 BOM；改脚本后运行 tools/release-gate.ps1。Git diff 检查需带 core.whitespace=cr-at-eol 等设置以兼容仓库锁定的 CRLF。
- 打包只能使用白名单。图形入口依赖完整程序文件，不可只下载主脚本；旧 -Update 不分发 GUI 或 tools。
- 新项目 F:\Codex\projects，工作树 F:\Codex\worktrees，验证与日志 F:\Codex\work，工具缓存 F:\dev\cache。当前已有仓库继续位于 D:\AAA PROJECT\claude-proxy。
