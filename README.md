# claude-proxy

**把 Claude Code 路由到任意 AI 提供商的 PowerShell 启动脚本。**

> 第一次用、不懂编程？请直接看 **[小白教程 TUTORIAL.md](./TUTORIAL.md)**，那里一步步带你跑通。本文档偏技术参考。

Claude Code 官方只能连接 Anthropic 的 API。如果你有 DeepSeek、Gemini、通义千问等其他 AI 服务的 API key，想在 Claude Code 里用它们，就需要一个"代理"把请求转发过去。claude-proxy 就是做这件事的——它是一个 PowerShell 脚本，帮你配置好一切环境变量，让 Claude Code 无缝连接到你选择的 AI 提供商。

支持两种协议：
- **Anthropic 格式**：直连，无需额外依赖（DeepSeek、MiMo、OpenRouter 等）
- **OpenAI 格式**：自动通过 LiteLLM 做协议转换（Moonshot、智谱、通义千问、Gemini 等）

> 默认使用 **DeepSeek**，走它官方的 Anthropic 协议端点直连，**不需要装 Python / LiteLLM**，对小白最省事。

---

## 功能特性

- 一键启动：双击 `setup.bat` 即可，自动检测并安装所需依赖
- 内置 DeepSeek（默认）+ MiMo 直连，另附若干主流 provider 模板，按需启用
- 自定义 provider：支持任何兼容 Anthropic 或 OpenAI 格式的 API
- 自动协议转换：OpenAI 格式的 provider 自动通过 LiteLLM 转换，无需手动操作
- API key 管理：首次粘贴（输入不回显）后自动保存到 `.env`，下次免输入
- 配置隔离：每个 provider 使用独立配置目录，互不干扰
- 更新提示：默认只检查并提示新版，要不要更新由你决定（`-Update` 手动更新）
- 零污染：环境变量仅在当前进程生效，退出即消失

---

## 技术栈

| 技术 | 用途 |
|------|------|
| PowerShell 5.1+ | 主脚本语言（Windows 自带） |
| Claude Code CLI | AI 编程助手本体 |
| Node.js | Claude Code 运行环境 |
| Python + LiteLLM | OpenAI 协议转换（**仅 OpenAI 格式 provider 需要**；默认的 DeepSeek 不需要） |
| Git | 项目代码管理（非必需） |
| winget | Windows 包管理器，自动安装依赖 |

---

## 快速开始

### 方法一：双击启动（推荐小白）

1. 打开仓库页面 → 绿色 **`Code`** 按钮 → **`Download ZIP`** → 解压到一个你方便找到的文件夹（如 `D:\claude-proxy`）
2. 进入解压出来的文件夹，**双击 `setup.bat`**

> **不要**在浏览器里对 `claude-proxy.ps1` 单独用"另存为"。该文件依赖 UTF-8 BOM，浏览器/记事本另存极易丢 BOM 或存成 `.txt`，导致中文乱码、双击闪退。请用 Download ZIP（走 git 原始字节，编码不会坏）。

首次运行时脚本会自动：
- 放开 PowerShell 执行策略（仅当前用户）
- 检测 Node.js / Claude Code CLI / Git，缺什么用 winget 装什么
- 弹出提示让你粘贴 API key（输入不会显示是正常的），保存到 `.env`（下次不再问）
- 只有使用 OpenAI 协议的 provider 时，才会自动装 Python + LiteLLM

> 运行只需要 `setup.bat` + `claude-proxy.ps1` 两个文件；`providers.local.example.ps1` 是可选模板。

### 方法二：命令行启动

```powershell
# 使用默认 provider（deepseek，Anthropic 格式直连）
.\claude-proxy.ps1

# 切换到其它 provider
.\claude-proxy.ps1 -Provider mimo

# 列出所有可用 provider
.\claude-proxy.ps1 -List

# 显示帮助
.\claude-proxy.ps1 -Help
```

---

## 项目结构

```
claude-proxy/
├── claude-proxy.ps1              # 主脚本（-Update 时会覆盖此文件）
├── setup.bat                     # 一键启动器（双击即可）
├── providers.local.example.ps1   # 自定义/扩展 provider 的模板
├── providers.local.ps1           # 你的自定义 provider（更新不覆盖，已在 .gitignore）
├── .env                          # API key 存储（更新不覆盖，已在 .gitignore，运行时自动生成）
├── VERSION                       # 版本号文件
├── .gitignore                    # Git 忽略规则
├── .gitattributes                # Git 换行符规则（锁定 CRLF / BOM）
├── LICENSE                       # MIT 许可证
├── TUTORIAL.md                   # 小白教程
└── README.md                     # 本文件
```

---

## 使用说明

> 完整的"手把手"步骤在 [TUTORIAL.md](./TUTORIAL.md)。下面是命令行速查。

### 基本用法

```powershell
# 使用默认 provider（deepseek，直连）
.\claude-proxy.ps1

# 使用其它已注册 provider
.\claude-proxy.ps1 -Provider mimo

# 覆盖模型
.\claude-proxy.ps1 -Provider deepseek -Model deepseek-v4-flash

# 使用共享配置（~/.claude）而非隔离目录
.\claude-proxy.ps1 -SharedConfig

# 指定工作目录
.\claude-proxy.ps1 -WorkDir "C:\my\project"

# 列出所有可用 provider / 显示帮助
.\claude-proxy.ps1 -List
.\claude-proxy.ps1 -Help
```

### 临时使用自定义端点

不想注册 provider，临时用一下：

```powershell
.\claude-proxy.ps1 -Provider custom -BaseUrl "https://api.example.com/v1" -ApiKey "sk-xxx" -Model "xxx" -Protocol openai
```

### 添加自己的 Provider（唯一推荐方式）

**在 `providers.local.ps1` 里加，不要改主脚本 `claude-proxy.ps1`**（主脚本会被 `-Update` 覆盖，你的改动会丢；`providers.local.ps1` 永远不会被动）。

1. 把 `providers.local.example.ps1` 复制一份，改名为 `providers.local.ps1`
2. 编辑 `providers.local.ps1`，取消注释一个示例块、或在 `$LocalProviders` 哈希表里填入你的 provider：

```powershell
$LocalProviders = @{
    "my-provider" = @{
        baseUrl   = "https://your-api-endpoint.com/v1"   # 你的 API 地址
        apiKey    = "PASTE_YOUR_MY-PROVIDER_KEY_HERE"     # 留占位符即可，首次运行会提示粘贴
        model     = "your-model-name"                     # 模型名
        smallFast = "your-model-name"                     # 小型快速模型（可与上面相同）
        label     = "我的 Provider"                        # 显示名称
        protocol  = "anthropic"                           # anthropic 或 openai
        signupUrl = "https://..."                         # 可选：申请 key 的网址
    }
}
# 可选：覆盖默认 provider
# $LocalDefaultProvider = "my-provider"
```

**protocol 怎么选？**
- 你的 API 端点兼容 Anthropic 格式 → `"anthropic"`（直连，无需额外依赖）
- 你的 API 端点是 OpenAI 格式 → `"openai"`（脚本自动起 LiteLLM 转换，需要 Python）

---

## 配置选项

### 命令行参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `-Provider` | provider 名称 | `-Provider mimo` |
| `-BaseUrl` | 自定义 API 端点 | `-BaseUrl "https://..."` |
| `-ApiKey` | 自定义 API key | `-ApiKey "sk-xxx"` |
| `-Model` | 覆盖模型名 | `-Model deepseek-v4-flash` |
| `-SmallFastModel` | 小型快速任务模型 | `-SmallFastModel "fast-model"` |
| `-Protocol` | 协议类型 | `-Protocol openai` |
| `-SharedConfig` | 使用共享配置目录 | `-SharedConfig` |
| `-WorkDir` | 指定工作目录 | `-WorkDir "C:\project"` |
| `-List` | 列出所有 provider | `-List` |
| `-Help` | 显示帮助（`-h` 同义） | `-Help` |
| `-SkipChecks` | 跳过依赖检查 | `-SkipChecks` |
| `-Update` | 手动下载并应用更新 | `-Update` |
| `-SkipUpdate` | 跳过本次更新检查 | `-SkipUpdate` |
| `-LiteLlmPort` | LiteLLM 代理端口（0=自动） | `-LiteLlmPort 8080` |

### 环境变量

脚本会设置以下进程级环境变量（退出即消失）：

| 变量 | 说明 |
|------|------|
| `ANTHROPIC_BASE_URL` | API 端点地址 |
| `ANTHROPIC_AUTH_TOKEN` | API key |
| `ANTHROPIC_MODEL` | 默认模型 |
| `ANTHROPIC_SMALL_FAST_MODEL` | 小型快速模型 |

### 预置 Provider

| Provider | 协议 | 状态 | 说明 |
|----------|------|------|------|
| DeepSeek | Anthropic | 默认启用 | DeepSeek 官方 Anthropic 端点，直连无需 LiteLLM |
| MiMo | Anthropic | 启用 | 小米 MiMo，国内直连 |
| OpenRouter | Anthropic | 模板 | 多模型聚合 |
| Gemini | OpenAI | 模板 | Google Gemini |
| Moonshot | OpenAI | 模板 | 月之暗面 Kimi |
| 智谱 GLM | OpenAI | 模板 | 智谱 AI |
| 通义千问 | OpenAI | 模板 | 阿里云 DashScope |

> "模板"表示默认未启用。**启用方式不是去改主脚本，而是把对应块复制进 `providers.local.ps1`**（见上方"添加自己的 Provider"）。模板都在 `providers.local.example.ps1` 里，取消注释即可。

---

## 自动更新

- **默认行为：只检查、只提示，不自动下载执行。** 每次启动最多每 12 小时联网比对一次版本号，发现新版只打印一行提示，更新与否由你决定。
- 手动更新：`.\claude-proxy.ps1 -Update`（下载并替换主脚本后用新版重启），或直接去 GitHub 重新下载 ZIP。
- 多镜像顺序尝试（jsdelivr → gh-proxy.com → kkgithub → GitHub 官方），全部连不上就静默跳过，绝不卡住启动。
- 下载后做"非空 + 含版本标记 + 语法可解析"的**格式校验**，旧版按版本号备份为 `claude-proxy.<旧版本>.bak`。
- **安全说明**：`-Update` 从上述公开镜像拉取，仅做格式校验，**不验证数字签名**（不防"镜像被投毒"这类来源伪造）。如果你对供应链安全敏感，请只用"去 GitHub 手动下载"的方式更新。
- 更新只替换 `claude-proxy.ps1` 本身，`.env`、`providers.local.ps1`、`setup.bat` 都不动。
- 注意：`README.md` / `TUTORIAL.md` **不随 `-Update` 分发**，文档最新版以 GitHub 仓库为准。

---

## 安全须知

- **API key 等同账号密码。** 录入时不回显（屏幕看不到是正常的），保存在脚本同目录 `.env`，并尽量收紧文件权限为仅当前用户可读。
- `.env` 是明文存储。**不要把整个文件夹打包发给别人 / 传网盘**；求助时只发报错文本，别截到含 key 的窗口。
- 使用 OpenAI 协议 provider 时，上游真实 key 通过临时配置文件 + 环境变量传给 LiteLLM，**不会出现在进程命令行里**（避免被同机其它进程看到）。
- 自动更新默认不执行远程代码（见上一节）。

---

## 常见问题

更完整的排错见 [TUTORIAL.md](./TUTORIAL.md#遇到问题怎么办)。

### 提示"无法加载脚本"或"在此系统上禁止运行脚本"

运行一次：
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```
或者直接用 `setup.bat`，它通常会自动处理（若被组策略锁定则可能仍需手动设置）。

### 如何验证代理是否生效？

启动 Claude Code 后输入 `/model`，显示的模型名应该与你配置的一致。

### 怎么回退到旧版本？

`-Update` 更新时旧版会按版本号备份为 `claude-proxy.<旧版本>.bak`。挑你要回退的那一份，改名回 `claude-proxy.ps1` 即可。

### 更新后自定义 provider 丢了？

不会。`providers.local.ps1` 永远不会被 `-Update` 覆盖。如果丢了，检查是否误删了这个文件。

---

## 协议转换原理

对于只提供 OpenAI 格式 API 的 provider，脚本会自动：

```
Claude Code → Anthropic 协议 → LiteLLM (本地) → OpenAI 协议 → 目标 AI
```

- 自动检测 Python 和 LiteLLM 是否可用，首次使用自动安装（`pip install litellm`）
- 起本地代理时自动选空闲端口，上游 key 走临时配置 + 环境变量（不上命令行）
- Claude Code 退出时自动停止代理并清理临时文件
- 默认的 DeepSeek 是 Anthropic 直连，**不经过这条链路**，无需 Python

---

## 贡献

欢迎提交 Issue 和 Pull Request。

**发布新版流程：**

1. 修改 `claude-proxy.ps1` 顶部的 `$SCRIPT_VERSION` 和根目录 `VERSION` 文件（**同时改**）
2. **【发版前必做·编码闸门】** 确认字节未被编辑器破坏（任一不符必须改回再提交）：
   ```powershell
   # claude-proxy.ps1 / providers.local.example.ps1 必须以 UTF-8 BOM 开头（前 3 字节 239,187,191）
   (Get-Content .\claude-proxy.ps1 -Encoding Byte -TotalCount 3) -join ','   # 期望 239,187,191
   # setup.bat 必须无 BOM 且为 CRLF
   $b=[IO.File]::ReadAllBytes('.\setup.bat'); "$($b[0]),$($b[1]),$($b[2])"    # 不应是 239,187,191
   ```
3. commit + push 到 `master`
4. 用户下次启动会收到"有新版"提示，运行 `-Update` 或重新下载即可升级。
   - 注意：`-Update` 只分发 `claude-proxy.ps1` + `VERSION`。若本次改了 `README` / `setup.bat` / 模板，请在 release notes 里提醒用户重新下载整个仓库。

> **编码铁律**：`claude-proxy.ps1`、`providers.local.example.ps1` 必须存成 **UTF-8 with BOM**（PS 5.1 需要 BOM 才能正确解码中文）；`setup.bat` 必须是 **CRLF 换行、无 BOM**。很多编辑器保存时会偷偷去掉 BOM 或改成 LF，改完务必用上面的命令检查。

---

## 许可证

[MIT License](./LICENSE)
