# claude-proxy

把 Claude Code 路由到任意 AI 提供商的 PowerShell 启动脚本。

支持两种协议：
- **Anthropic 格式**：直连（MiMo、OpenRouter 等）
- **OpenAI 格式**：自动通过 LiteLLM 转换（DeepSeek、Moonshot、通义千问等）

## 快速开始（小白模式）

1. 下载这个目录里的 **三个文件**（`setup.bat`、`claude-proxy.ps1`、`README.md`），放在同一个文件夹
2. **双击 `setup.bat`**

就这样。首次运行时脚本会自动：

- 放开 PowerShell 执行策略（仅当前用户）
- **检测 Node.js / Claude Code CLI / Git，缺什么用 winget 装什么**（电脑上没装过 Claude Code 也没关系，脚本帮你搞定）
- 弹出提示让你粘贴 API key，保存到同目录 `.env`（下次不再问）
- 用 OpenAI 协议的 provider（DeepSeek/Kimi/通义等）时还会自动装 Python + LiteLLM

装完后 `.env` 里就是你的 key，下次双击 `setup.bat` 直接进 Claude Code。

> 老用户/想用命令行也可以直接跑 `.\claude-proxy.ps1`。已经装好全套环境的话可以加 `-SkipChecks` 跳过检测。

脚本会**每 12 小时自动检查更新**：发现新版就从镜像下载、校验后替换 `claude-proxy.ps1` 自己，再用新版本重启——你不用做任何事。你的 `.env`（API key）和 `providers.local.ps1`（自定义 provider）都不会被动。想立即更新加 `-Update`，想跳过加 `-SkipUpdate`。

## 自动环境检测

脚本启动时会自动检测以下依赖，**缺什么装什么，装过的直接跳过**：

| 依赖 | 用途 | 安装方式 |
|------|------|----------|
| Node.js | Claude Code 运行环境 | winget |
| Claude Code CLI | `claude` 命令本体 | npm |
| Git | 项目代码管理（非必需，不阻塞启动） | winget |
| Python + LiteLLM | OpenAI 协议转换（仅 OpenAI 格式 provider 需要） | winget + pip |

加 `-SkipChecks` 可跳过全部检测，适合环境已就绪的老用户。

## 用法

```powershell
# 使用默认 provider（mimo，Anthropic 格式直连）
.\claude-proxy.ps1

# OpenAI 格式 provider（自动启动 LiteLLM 转换）
.\claude-proxy.ps1 -Provider deepseek
.\claude-proxy.ps1 -Provider moonshot

# 指定 provider
.\claude-proxy.ps1 -Provider mimo

# 临时用自定义端点（OpenAI 格式）
.\claude-proxy.ps1 -Provider custom -BaseUrl "https://api.example.com/v1" -ApiKey "sk-xxx" -Model "xxx" -Protocol openai

# 覆盖模型
.\claude-proxy.ps1 -Provider mimo -Model mimo-v2-flash

# 列出所有可用 provider
.\claude-proxy.ps1 -List

# 使用共享配置（~/.claude）而非隔离目录
.\claude-proxy.ps1 -SharedConfig

# 指定工作目录
.\claude-proxy.ps1 -WorkDir "C:\my\project"
```

## 添加自己的 Provider

把 `providers.local.example.ps1` **复制一份改名为 `providers.local.ps1`**，在里面的 `$LocalProviders` 哈希表填入你的 provider 即可：

```powershell
$LocalProviders = @{
    "my-provider" = @{
        baseUrl   = "https://your-api-endpoint.com/v1"   # 填你的 API 地址
        apiKey    = "PASTE_YOUR_MY-PROVIDER_KEY_HERE"     # 填 key 或留占位符，首次运行会提示
        model     = "your-model-name"                     # 填模型名
        smallFast = "your-model-name"                     # 小型快速模型（可与上面相同）
        label     = "我的 Provider"                        # 显示名称，随便写
        protocol  = "anthropic"                           # anthropic 或 openai
    }
}
# 可选：覆盖默认 provider
# $LocalDefaultProvider = "my-provider"
```

> **为什么放在单独文件？** 自动更新会整体覆盖 `claude-proxy.ps1`，但**永远不会动 `providers.local.ps1`**。所以你加的 provider 在每次更新后都还在，不会被冲掉。`providers.local.ps1` 也在 `.gitignore` 里，不会误传到 git。

**protocol 怎么选？**
- 你的 API 端点兼容 Anthropic 格式 → `"anthropic"`（直连，无需额外依赖）
- 你的 API 端点是 OpenAI 格式 → `"openai"`（脚本自动起 LiteLLM 转换，需要 Python）

API key 留占位符（`PASTE_YOUR_..._HERE`）的话，首次运行会交互式提示你粘贴，自动存到 `.env`，下次不再问。

也可以不改脚本，用 `-Provider custom` 临时指定：

```powershell
.\claude-proxy.ps1 -Provider custom -BaseUrl "https://your-url.com/v1" -ApiKey "sk-xxx" -Model "xxx" -Protocol openai
```

## 协议转换原理

对于只提供 OpenAI 格式 API 的 provider，脚本会自动：

```
Claude Code → Anthropic 协议 → LiteLLM (本地) → OpenAI 协议 → 目标 AI
```

- 自动检测 Python 和 LiteLLM 是否可用
- 首次使用自动安装 LiteLLM（`pip install litellm`）
- 自动启动本地代理，选空闲端口
- Claude Code 退出时自动清理代理进程

## 预置 Provider

| Provider | 协议 | 说明 |
|----------|------|------|
| MiMo | Anthropic | 小米 MiMo，国内直连 |
| Gemini | OpenAI | Google Gemini 2.5 Pro/Flash |
| DeepSeek | OpenAI | DeepSeek V3/R1 |
| Moonshot | OpenAI | 月之暗面 Kimi |
| 智谱 GLM | OpenAI | 智谱 AI |
| 通义千问 | OpenAI | 阿里云 DashScope |
| 百川智能 | OpenAI | Baichuan |
| OpenRouter | Anthropic | 多模型聚合 |
| 本地 OpenAI | OpenAI | Ollama 等本地模型 |

> 预置 provider 默认注释掉了（MiMo 除外），取消注释 + 填 key 即可启用。

## 自动更新

- 每次启动**最多每 12 小时**联网检查一次（节流，避免每次双击都联网）；`-Update` 忽略节流强制检查，`-SkipUpdate` 跳过。
- 更新源按可达性**多镜像顺序尝试**，全部连不上就静默用本地版本，**绝不卡住启动**：
  1. jsdelivr CDN（国内快）
  2. gh-proxy.com 镜像
  3. kkgithub 镜像
  4. GitHub 官方 raw（兜底）
- 下载后会校验（非空 + 含版本标记 + 语法可解析）才替换，旧版备份为 `claude-proxy.ps1.bak`，失败自动回退。
- 更新**只替换 `claude-proxy.ps1` 自己**。`.env`、`providers.local.ps1`、`setup.bat` 都不动。
- jsdelivr 有 CDN 缓存，刚 push 的新版可能要等几小时到一天才被它认出来；急的话见下方维护者说明。

### 维护者：怎么发布新版

1. 改完代码，把 `claude-proxy.ps1` 顶部的 `$SCRIPT_VERSION` 和根目录 `VERSION` 文件**同时**改成新版本号（如 `1.2.0`）。
2. commit + push 到 `master`。
3. 用户下次启动（或 `-Update`）就会自动升级。
4. 想让 jsdelivr 立刻刷新缓存，访问一次：
   `https://purge.jsdelivr.net/gh/fisHarly0/claude-proxy@master/claude-proxy.ps1`
   和 `.../VERSION`。

> **编码铁律（否则用户双击直接崩）**：
> - `claude-proxy.ps1`、`providers.local.ps1` 含中文，**必须存成 UTF-8 with BOM**。Windows PowerShell 5.1 用 `-File` 加载无 BOM 的中文脚本会按 GBK 解码、乱码、解析失败。
> - `setup.bat` **必须是 CRLF 换行、不要 BOM**。LF 换行会让 cmd 把命令拆错，BOM 会让 `@echo off` 前出现乱码字符。
> - 很多编辑器（尤其记事本）保存时会偷偷去掉 BOM 或改成 LF，改完务必检查。

## 注意事项

- 环境变量是进程级别的，不会影响你全局的 `claude` 命令
- 默认每个 provider 使用独立配置目录（`~/.claude-<provider>`）
- OpenAI 格式的 provider 需要 Python + pip（LiteLLM 依赖，脚本会自动装）
- LiteLLM 日志位于 `%TEMP%\litellm-*.log`，出错时可查看
- 启动后输入 `/model` 可验证代理是否生效
- API key 存在脚本同目录的 `.env` 里，**不要提交到 git**（已在 `.gitignore` 中排除）
- winget 安装新软件后，**第一次需要新开一个 PowerShell 窗口**才能让 PATH 生效，脚本会自动提示
- 如果你已经把全套环境（Node/Claude/Git/Python）装好了，可以加 `-SkipChecks` 加速启动
