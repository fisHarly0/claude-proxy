# 当前状态 / Current State

更新时间：2026-09-11

- 项目定位：PowerShell 启动器，把 Claude Code 路由到 Anthropic 或 OpenAI 兼容 provider。
- 当前版本：README 标记为 v1.2.0；默认 DeepSeek 走 Anthropic 直连，OpenAI 协议 provider 通过 LiteLLM。
- 技术边界：PowerShell 5.1+、Claude Code CLI、Node；部分 provider 需要 Python + LiteLLM。
- 真源：主脚本、provider 模板、VERSION、README/TUTORIAL。

## 接手约束

- 不读取或提交 `.env`、`providers.local.ps1` 和真实 key。
- `claude-proxy.ps1` 与 provider 模板必须保留 UTF-8 BOM；`setup.bat` 必须 CRLF 无 BOM。
- 修改 provider 时优先扩展 `providers.local.ps1`，不要把用户配置写回主脚本。
- 自动更新只保留现有格式校验边界，供应链安全变化先写决策记录。

## 本轮状态

只新增协作档案，没有修改 README、教程、主脚本或批处理文件。
