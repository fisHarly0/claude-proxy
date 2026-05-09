# claude-proxy

把 Claude Code 路由到任意 AI 提供商的 PowerShell 启动脚本。

支持两种协议：
- **Anthropic 格式**：直连（MiMo、OpenRouter 等）
- **OpenAI 格式**：自动通过 LiteLLM 转换（DeepSeek、Moonshot、通义千问等）

## 快速开始

1. 下载 `claude-proxy.ps1`
2. 编辑脚本，在 `$PROVIDERS` 里填入你的 API key
3. 运行：

```powershell
.\claude-proxy.ps1
```

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

## 协议转换原理

对于只提供 OpenAI 格式 API 的 provider，脚本会自动：

```
Claude Code → Anthropic 协议 → LiteLLM (本地) → OpenAI 协议 → 目标 AI
```

- 自动检测 Python 和 LiteLLM 是否可用
- 首次使用自动安装 LiteLLM（`pip install litellm`）
- 自动启动本地代理，选空闲端口
- Claude Code 退出时自动清理代理进程

## 添加新 provider

编辑脚本里的 `$PROVIDERS` 哈希表：

```powershell
# Anthropic 格式（直连）
"my-anthropic-provider" = @{
    baseUrl   = "https://api.example.com/anthropic"
    apiKey    = "sk-your-key"
    model     = "your-model"
    smallFast = "your-model"
    label     = "显示名称"
    protocol  = "anthropic"
}

# OpenAI 格式（自动 LiteLLM 转换）
"my-openai-provider" = @{
    baseUrl   = "https://api.example.com/v1"
    apiKey    = "sk-your-key"
    model     = "your-model"
    smallFast = "your-model"
    label     = "显示名称"
    protocol  = "openai"
}
```

## 预置 Provider

| Provider | 协议 | 说明 |
|----------|------|------|
| MiMo | Anthropic | 小米 MiMo，国内直连 |
| DeepSeek | OpenAI | DeepSeek V3/R1 |
| Moonshot | OpenAI | 月之暗面 Kimi |
| 智谱 GLM | OpenAI | 智谱 AI |
| 通义千问 | OpenAI | 阿里云 DashScope |
| 百川智能 | OpenAI | Baichuan |
| OpenRouter | Anthropic | 多模型聚合 |
| 本地 OpenAI | OpenAI | Ollama 等本地模型 |

## 注意事项

- 环境变量是进程级别的，不会影响你全局的 `claude` 命令
- 默认每个 provider 使用独立配置目录（`~/.claude-<provider>`）
- OpenAI 格式的 provider 需要 Python + pip（LiteLLM 依赖）
- LiteLLM 日志位于 `%TEMP%\litellm-*.log`，出错时可查看
- 需要 PowerShell 执行权限，如遇报错运行：`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- 启动后输入 `/model` 可验证代理是否生效
