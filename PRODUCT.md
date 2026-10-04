# Product

<!-- impeccable:product-schema 1 -->

## Platform

Windows desktop（PowerShell 5.1 / Windows Forms，当前工具的移动端分类不适用）。

## Users

Windows 新手，使用一台电脑连接多个 API，不希望自己安装 Node、编辑配置文件或记命令。

## Product Purpose

填一次 API 信息，点击“配置并启动”，自动准备环境并进入独立的 Claude Code 实例。再次使用直接启动已有实例。

## Capabilities and Constraints

用户已确认默认第三方自定义 API。不同 API / Key 独立配置和工作目录；仓库保留 claude-proxy 名称。API 兼容性依赖服务商，系统和 Claude 自己的授权步骤不能绕过。当前公开能力为 Windows 脚本，不声称具有干净新机实测证据。

## Product Principles

- 一个明确的主要操作；技术选项放在更多选项中。
- 安装和失败状态可理解、可重试，配置和会话不会因重试丢失。
- Key 不出现在命令行、日志或截图中。
- 以运行证据描述能力，区分本地检查与真实 API 验证。
