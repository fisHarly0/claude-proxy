# AGENTS.md · claude-proxy 协作入口

本文件是统一入口兼容层。项目当前以 `README.md`、`TUTORIAL.md`、`claude-proxy.ps1` 和 `providers.local.example.ps1` 为实现说明；新增功能前先建立模块 spec。

## 接手顺序

1. 读取 `AGENTS.md`、`.ai-standard.yml` 和 `memory/current-state.md`。
2. 读取相关 spec、README 和最近交接记录。
3. 修改 PowerShell、模板或批处理后，检查 BOM、CRLF 和语法，不要运行真实 key。

稳定流程入口：`D:/AAA PROJECT/real-vibecoding-harries/操作手册/首次打开统一流程.md`。

## 安全边界

`.env`、`providers.local.ps1` 和 API key 不得读取、回显或提交。更新来源需经过现有格式校验；未经审查不得扩大远程执行范围。
