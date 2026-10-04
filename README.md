# claude-proxy

**一台 Windows 电脑，多套 API。填好信息，点击一次“配置并启动 Claude”。**

给工作 API、个人 API，或同一家服务商的不同 Key，各自创建一个独立的 Claude Code 启动入口。程序负责准备运行环境、保存配置和打开 Claude；以后双击对应的桌面快捷方式即可使用。

**v1.5.0 开发版 · Windows · MIT**

[新手教程](./TUTORIAL.md) · [源码仓库](https://github.com/fisHarly0/claude-proxy) · [反馈问题](https://github.com/fisHarly0/claude-proxy/issues)

## 三步开始

1. **完整解压程序包**，双击 `开始使用.bat`。双击 `setup.bat` 也会打开同一个窗口。
2. 填写 **名称、API 基础地址、模型名称、API Key**。
3. 点击 **“配置并启动 Claude”**，等待窗口提示完成。

默认使用**第三方自定义 API**。请按服务商的 **Claude Code / Anthropic 兼容接入说明**填写地址和模型，不要把 Key 放进地址，也不要自行追加 `/messages` 或 `/chat/completions`。

首次使用需联网下载。程序优先原生安装 Claude Code，**不用提前安装 Node.js 或 Python**；原生安装失败时会尝试 Node/npm 后备方式。Windows 的安装授权、Claude 的首次许可和项目信任提示仍需要你本人确认。

> 请使用包含图形入口的 v1.5.0 程序包或完整源码，不要只下载一个 `.ps1` 文件。当前版本已完成本地验证，尚未发布正式版本。

## 点下按钮后会做什么

- 保存这套 API 的连接信息，并加密保存 Key。
- 检查 Claude Code 是否可用，缺少时尝试自动安装。
- 创建独立的 Claude 配置目录和默认代码目录。
- 尝试创建桌面快捷方式，并打开 Claude Code。

准备过程在后台进行，窗口会显示当前步骤。可以取消；失败后会提示原因，修正后点击重试，已经保存的配置会保留。

**打开 Claude 不等于 API 已验证成功。** 实际能否对话、流式输出和调用工具，还取决于服务商接口、模型能力及账号权限。

## 多个 API，分别使用

例如，你可以创建“工作用”“个人用”“备用”三套配置。它们可以同时启动，也可以来自同一家服务商、使用不同的 Key。Claude Code 程序只需安装一份。

| 内容 | 如何保存 |
| --- | --- |
| API 地址、模型 | 每个实例自己的 `profile.json` |
| API Key | 图形入口加密保存到各自的 `api-key.dpapi` |
| Claude 用户配置与会话 | 每个实例自己的 `config/` |
| 默认代码目录 | 每个实例自己的 `workspace/` |
| 启动入口 | 各自的 `launch.bat` 和桌面快捷方式 |

默认目录如下，也可以在“更多选项”中更换保存位置：

```text
launchers/
├── 工作用/
│   ├── launch.bat          # 双击启动这一套 API
│   ├── profile.json        # 接口、模型与工作目录
│   ├── api-key.dpapi       # 加密 Key
│   ├── config/             # Claude 用户配置与会话
│   ├── workspace/          # 默认代码目录
│   ├── claude-proxy.ps1    # 此实例的运行脚本
│   ├── VERSION
│   └── LICENSE
└── 个人用/
    └── ...                 # 另一套独立配置
```

配置隔离使用 Claude Code 的 [`CLAUDE_CONFIG_DIR`](https://code.claude.com/docs/en/env-vars)。如果在“更多选项 → 代码项目”中选择同一个已有项目，两个实例仍会共享项目文件及项目级 Claude 设置。独立配置目录并不是文件访问沙箱。

## 日常使用

| 想做什么 | 怎么操作 |
| --- | --- |
| 再次启动 | 双击桌面的 `Claude - 名称`，或实例目录里的 `launch.bat` |
| 添加另一个 API | 打开图形入口，顶部选“新增一套自定义 API”，填写不同名称 |
| 修改地址或模型 | 先退出对应 Claude，选择已有配置，修改后点“配置并启动 Claude” |
| 更换 Key | 选择已有配置，填写新 Key；留空则保留原来的 Key |
| 使用已有代码项目 | 在“更多选项 → 代码项目”中选择文件夹 |
| 安装失败后重试 | 查看窗口提示和安装日志，修正后再次点击主按钮 |
| 中途停止 | 点击“取消准备”，已保存的配置会保留 |

### 移动和更新

**同一电脑内搬家：** 退出对应 Claude，移动整个实例文件夹，不要只移动 `launch.bat`。在图形入口选择新的保存位置，再选择该实例。原桌面快捷方式可能仍指向旧路径，可直接使用新位置的 `launch.bat`；自选项目的绝对路径也需要检查。

**换电脑或 Windows 用户：** 图形 Key 绑定原 Windows 用户，不能保证跨电脑解密。请在新电脑的图形入口重新填写 Key。

**更新整个工具：** 获取完整新版程序文件，保留已有实例文件夹。用新版图形入口选择已有配置并启动，会更新该实例的主脚本和版本文件，保留 Key、会话和代码。也可以退出实例后手动复制新版 `claude-proxy.ps1` 和 `VERSION` 到实例目录。

旧命令行的 `-Update` 只更新主脚本，不会升级图形入口或 `tools/`；实例模式不接受 `-Update`。

## 接口支持范围

| 接口类型 | 入口与状态 |
| --- | --- |
| Anthropic 兼容 API | 图形入口支持直连，请使用服务商给出的 Claude Code 接入地址 |
| 只有 OpenAI 格式的 API | 仅保留命令行的 LiteLLM 实验转换，不保证 Claude Code 工具调用兼容 |
| Claude 订阅登录 | 当前图形流程面向 API Key 配置，不管理订阅账号切换 |

本项目负责本机配置、环境准备和独立启动。它不会给一个不兼容的 API 自动补齐 Claude Code 所需的能力，也不提供模型额度或 API Key。

## Key 如何保存

图形入口使用 Windows 当前用户的 **DPAPI 加密**，Key 不会写入进程命令行或安装日志。不要把配置好的整个实例文件夹发给别人，里面还可能包含会话和项目数据。

旧命令行入口仍支持明文 `.env`；存在 `api-key.dpapi` 时优先使用加密 Key。图形版换 Key 请直接在窗口操作，删除 `.env` 不会更换已保存的加密 Key。

原生安装从官方发布源下载，并校验发布清单中的 SHA256 后才运行文件。下载被网络或组织策略阻止时，自动安装仍可能失败。安装方式参考 [Claude Code 官方说明](https://code.claude.com/docs/en/setup)。

## 常见问题

**点开后没有窗口？** 先确认已完整解压，使用 Windows 10/11 的 64 位环境，并保留 `tools/` 文件夹。不要在 ZIP 内直接运行，也不要单独下载主脚本。

**名称已存在？** 在窗口顶部选择已有配置，或为新的 API 换一个名字，程序不会覆盖同名新实例。

**安装失败？** 点击“查看安装日志”，检查网络和系统安装限制，再重试。完整排错步骤见 [新手教程](./TUTORIAL.md#没成功怎么办)。

**Claude 打开了，但认证失败或不能调用工具？** 检查 Key、额度、模型权限及接口协议。程序能启动只说明本机准备完成，不能证明上游 API 兼容。

**没有桌面快捷方式？** 可以直接双击实例文件夹中的 `launch.bat`。

## 命令行用法

图形入口之外，仍保留独立启动器生成和旧 Provider 模式。以下命令在仓库目录的 PowerShell 中运行。

<details>
<summary>生成独立启动器</summary>

双击 `create-launcher.bat`，按文字提示操作；或使用参数生成。下面的地址和模型是占位示例，请替换：

```powershell
.\new-launcher.ps1 -Name work-api -BaseUrl 'https://api.example.com/anthropic' `
  -Model 'your-model-id' -OutputDir 'F:\ClaudeInstances' -NonInteractive
```

生成器不会复制已有 Key，也不覆盖同名目录。双击生成的 `launch.bat` 后，首次安全输入 Key，保存到该实例的明文 `.env`。使用 OpenAI 实验转换时，生成命令加 `-Protocol openai`。

```powershell
# 从已生成的实例启动，并临时指定代码项目
.\claude-proxy.ps1 -InstanceDir 'F:\ClaudeInstances\work-api' -WorkDir 'F:\Projects\demo'
```

`-InstanceDir` 不能与 `-Provider`、连接覆盖参数、`-SharedConfig` 或 `-Update` 混用。连接信息保存在实例的 `profile.json` 中。

</details>

<details>
<summary>旧 Provider 模式和参数</summary>

```powershell
# 指定内置 provider；名称存在不代表当前账号或模型已经验证可用
.\setup.bat -Provider deepseek
.\setup.bat -Provider mimo

# 查看可用配置、帮助与环境体检
.\setup.bat -List
.\setup.bat -Help
.\setup.bat -Doctor
```

旧模式直接运行主脚本、不传 `-Provider` 时仍默认 DeepSeek。各服务商使用不同配置目录，但同一家服务商的不同 Key 不会自动分开；需要多套 Key 时请使用独立实例。

添加自定义 Provider：复制 [providers.local.example.ps1](./providers.local.example.ps1) 为 `providers.local.ps1`，按模板填写地址、模型和协议。Key 留占位符可在首次启动时输入；不要把真实 Key 提交到仓库，也不要直接修改会被更新覆盖的主脚本。模板中的模型名称仅是配置示例，以服务商当前提供的信息为准。

| 参数 | 用途 |
| --- | --- |
| `-Provider` | 选择已注册的 Provider |
| `-BaseUrl`、`-Model`、`-SmallFastModel` | 覆盖地址、主模型和快速模型 |
| `-ApiKey` | 旧入口支持的显式 Key 参数；日常使用优先选图形输入，避免 Key 进入命令历史 |
| `-Protocol` | `anthropic` 直连或 `openai` 实验转换 |
| `-WorkDir` | 指定已有代码项目 |
| `-SharedConfig` | 旧模式使用共享 Claude 配置目录 |
| `-InstanceDir` | 使用独立实例目录 |
| `-PrepareOnly` | 准备运行环境，不进入 Claude 会话，供图形后台调用 |
| `-SkipChecks`、`-SkipUpdate` | 跳过依赖检查或主脚本更新检查 |
| `-LiteLlmPort` | OpenAI 实验代理端口，`0` 表示自动选择 |
| `-Update` | 旧模式手动更新主脚本，不升级图形入口 |

旧模式默认只检查并提示脚本更新。`-Update` 经公开镜像下载，仅进行格式和语法校验，不验证发布签名；需要可核对来源时请获取完整源码更新。它保留旧脚本备份，不覆盖本地 `.env` 或 `providers.local.ps1`。

</details>

## 开发与验证

图形界面使用 Windows Forms，运行于 Windows 自带的 PowerShell 5.1。程序入口、后台准备和实例运行分别位于：

| 文件 | 职责 |
| --- | --- |
| `开始使用.bat` / `setup.bat` | 图形入口；`setup.bat` 带参数时保留旧用法 |
| `launcher-gui.ps1` | 表单、状态、取消与启动 |
| `launcher-support.ps1` | 保存配置、加密 Key、创建快捷方式 |
| `tools/prepare-instance.ps1` | 后台准备任务 |
| `claude-proxy.ps1` | 依赖安装、实例隔离与 Claude 启动 |
| `new-launcher.ps1` / `create-launcher.bat` | 命令行生成独立实例 |
| `tools/pack-starter.ps1` | 白名单打包轻量使用包，首次运行仍需联网 |

本地验证记录：**36 项实例回归、22 项配置与安装流程检查、8 项实际表单操作检查通过**，另通过编码、语法、版本与打包检查。测试使用虚构 Key、模拟 Claude 和安装器；**尚未完成干净 Windows 新机的真实安装、真实 API/工具调用及真实高 DPI 硬件验收**。

复现检查（临时目录可以自行指定）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-instances.ps1 -ScratchDir 'F:\claude-proxy-tests'
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-gui-setup.ps1 -ScratchDir 'F:\claude-proxy-tests'
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-window.ps1 -ScratchDir 'F:\claude-proxy-tests'
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\release-gate.ps1
```

打包给新电脑：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pack-starter.ps1 -OutDir 'F:\claude-proxy-packages'
```

打包使用文件白名单，不包含实例、Key 和缓存。`pack-offline.ps1` 另可附带 Node 安装包，但**不等于包含 Claude Code 的完整离线安装环境**。

修改 PowerShell 文件时保留 **UTF-8 BOM**，批处理使用 **CRLF、无 BOM**；同步主脚本版本与 `VERSION`，运行发布检查后再分发。不要用真实 Key 跑测试。

## 许可证

[MIT License](./LICENSE)
