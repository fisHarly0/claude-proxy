# 每个 API 一个 Claude Code 实例

## 范围与实现顺序

2026-10-04：保留 claude-proxy 仓库名，聚焦 Windows 单机多 API 启动器。

1. 增加 `create-launcher.bat` / `new-launcher.ps1`：收集实例名称、API 地址、模型和协议，生成独立目录。
2. 主脚本增加 `-InstanceDir`：只加载该目录的 `profile.json` / `.env`，使用该目录的 `config/` 和默认 `workspace/`。
3. 生成目录携带主脚本快照、VERSION 和 LICENSE；移动整个目录后仍可启动。不复制已有密钥或本地 provider 脚本。
4. 加入独立进程回归验证、编码/语法闸门和新手说明。

## 数据与行为

- `profile.json` 版本 1，字段：name、baseUrl、model、smallFastModel、protocol、workDir。默认 workDir 为相对路径 `workspace`；用户指定已有项目时保存绝对路径。
- `launch.bat` 双击运行，通过相对路径调用主脚本；不拼接用户输入进脚本，不在命令行写 key。
- Key 首次启动时隐式输入并保存在实例 `.env`；不回退读取系统中的同名 key；同服务商的两把 key 也独立。
- `CLAUDE_CONFIG_DIR` 指向实例 `config/`，清除本进程继承的其他 API 身份/路由变量，再设置本实例连接与模型。
- 实例配置不能与旧的 provider/连接覆盖参数、共享配置、自更新混用。生成器不覆盖已有同名目录，不自动启动、不安装依赖、不访问 API。
- 工作目录与配置目录区分：默认各自独立；显式选择同一项目时，项目文件和项目级 Claude 配置仍共享。配置隔离不是文件系统沙箱。
- Anthropic 兼容接口直接连接；OpenAI 转换保留实验性质，不承诺模型工具调用兼容。启动新代理不得清理其他实例的代理进程。
- 老的 setup.bat/provider 用法继续可用。实例快照默认跳过自动更新检查；更新需手动替换实例主脚本，保留数据。

## 验收

- Windows PowerShell 5.1 语法、UTF-8 BOM、批处理 CRLF / 无 BOM、版本一致性通过。
- 在 F 盘隔离测试目录使用虚构 key 和模拟 Claude；禁止真实 API 请求、安装依赖或读取仓库密钥。
- 两个同端点实例并行启动，API key、config、工作目录独立，退出码传回；父进程环境不变。
- 中文、空格、批处理特殊字符路径和 JSON 中特殊字符按数据处理；整体移动后可启动。
- 拒绝重复目录、路径穿越、保留文件名、非法 URL / 空模型；实例不加载遗留 provider 配置或继承 key。
- 不宣称已验证真实模型、流式输出或工具调用，除非有真实服务实测证据。

配置目录依据：[Claude Code 环境变量文档](https://code.claude.com/docs/en/env-vars)。
