# claude-proxy

把 Claude Code 路由到任意 Anthropic 兼容代理的 PowerShell 启动脚本。

支持 MiMo、DeepSeek、OpenRouter 或任何兼容 Anthropic API 的自建代理。

## 快速开始

1. 下载 `claude-proxy.ps1`
2. 编辑脚本，在 `$PROVIDERS` 里填入你的 API key
3. 运行：

```powershell
.\claude-proxy.ps1
```

## 用法

```powershell
# 使用默认 provider（mimo）
.\claude-proxy.ps1

# 指定 provider
.\claude-proxy.ps1 -Provider mimo

# 临时用自定义端点
.\claude-proxy.ps1 -Provider custom -BaseUrl "https://your-proxy.com/anthropic" -ApiKey "sk-xxx" -Model "your-model"

# 覆盖模型
.\claude-proxy.ps1 -Provider mimo -Model mimo-v2-flash

# 列出所有可用 provider
.\claude-proxy.ps1 -List

# 使用共享配置（~/.claude）而非隔离目录
.\claude-proxy.ps1 -SharedConfig

# 指定工作目录
.\claude-proxy.ps1 -WorkDir "C:\my\project"
```

## 添加新 provider

编辑脚本里的 `$PROVIDERS` 哈希表，复制一个块填入你的值：

```powershell
$PROVIDERS = @{
    "my-provider" = @{
        baseUrl   = "https://api.example.com/anthropic"
        apiKey    = "sk-your-key"
        model     = "your-model-name"
        smallFast = "your-model-name"
        label     = "显示名称"
    }
}
```

## 已测试的代理服务

| Provider | Endpoint | 说明 |
|----------|----------|------|
| MiMo | `https://token-plan-cn.xiaomimimo.com/anthropic` | 小米 MiMo，国内直连 |
| DeepSeek | `https://api.deepseek.com/anthropic` | DeepSeek（需自行确认兼容性） |
| OpenRouter | `https://openrouter.ai/api/v1/anthropic` | 多模型聚合 |
| 自建 | `http://localhost:8080/anthropic` | LiteLLM / OneAPI 等 |

## 注意事项

- 环境变量是进程级别的，不会影响你全局的 `claude` 命令
- 默认每个 provider 使用独立配置目录（`~/.claude-<provider>`）
- 需要 PowerShell 执行权限，如遇报错运行：`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- 启动后输入 `/model` 可验证代理是否生效
