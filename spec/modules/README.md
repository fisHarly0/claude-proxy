# 模块规格索引

| 模块 | 代码范围 | 维护重点 |
|---|---|---|
| 启动参数 | `claude-proxy.ps1` | provider、协议、模型和工作目录解析 |
| [独立实例启动器](instances.md) | `new-launcher.ps1`、`create-launcher.bat`、`-InstanceDir` | 每个 API 独立 Key、配置目录与启动入口 |
| [图形化配置并启动](gui-setup.md) | `launcher-gui.ps1`、`launcher-support.ps1`、`tools/prepare-instance.ps1` | 新电脑一个按钮准备环境、保存配置并启动 |
| Provider 配置 | `providers.local.example.ps1`、`.env` | 配置隔离；真实 key 不进仓库 |
| LiteLLM 转换 | 主脚本中的 OpenAI 协议分支 | 临时配置、端口、退出清理 |
| 自动更新 | `-Update`、VERSION | 来源、格式校验、备份和回滚 |
| 编码与发布 | `setup.bat`、PowerShell 文件 | BOM/CRLF 闸门 |

本目录只提供治理索引，不复制脚本参数或 provider 字段。
