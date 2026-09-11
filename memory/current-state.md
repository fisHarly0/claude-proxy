# 当前状态 / Current State

更新时间：2026-09-11

- 项目定位：PowerShell 启动器，把 Claude Code 路由到 Anthropic 或 OpenAI 兼容 provider。
- 当前版本：**v1.3.0**（`VERSION` 与 `$SCRIPT_VERSION` 已对齐）。
- 技术边界：PowerShell 5.1+、Claude Code CLI、Node；部分 provider 需要 Python + LiteLLM。
- 真源：主脚本、provider 模板、VERSION、README/TUTORIAL、`tools/`。

## 本轮变更（v1.3.0 · 新机部署顺畅化）

1. **`-Doctor` 一键体检**：执行策略 / BOM / winget / node / npm / claude / git / python / `.env` 是否有 key / 磁盘 / 网络（npmmirror·npmjs·DeepSeek）/ setup.bat 编码。只读、不安装、不打印 key 明文。`setup.bat -Doctor` 可透传。
2. **安装链加固**：`npm install -g @anthropic-ai/claude-code` 失败自动切 `registry.npmmirror.com`；winget 失败给可操作手动路径；装完 `claude --version` 冒烟；npm 全局目录已装但 PATH 未刷新时引导重开。
3. **教程**：TUTORIAL 增「新电脑冷启动」时间线表 + 首启 Claude 说明 + 排错改口到 Doctor。
4. **离线包**：`tools/pack-offline.ps1`（白名单拷贝 + 下 Node LTS msi + 离线说明，产出 `dist/*.zip`，**不含 `.env`**）。已实测生成 `dist/claude-proxy-offline-v1.3.0-win-x64.zip`。
5. **发版闸门**：`tools/release-gate.ps1`（BOM/CRLF/版本一致/语法/密钥文件提醒）。本轮 **GATE PASS**。

## 接手约束

- 不读取或提交 `.env`、`providers.local.ps1` 和真实 key。
- `claude-proxy.ps1` 与 provider 模板必须保留 UTF-8 BOM；`setup.bat` 必须 CRLF 无 BOM。
- **编辑 `claude-proxy.ps1` 后必须再跑 `tools/release-gate.ps1`**（本机编辑器易偷掉 BOM）。
- 修改 provider 时优先扩展 `providers.local.ps1`，不要把用户配置写回主脚本。
- 自动更新只保留现有格式校验边界；`tools/` 不随 `-Update` 分发。
- `dist/` 已在 `.gitignore`。

## 本轮状态

主脚本/README/TUTORIAL/setup.bat/VERSION/tools 均已改动；**未 commit、未 push**（等用户拍板）。工作区另有此前遗留的 LiteLLM/provider 覆盖相关未提交改动，一并保留。
