---
name: claude-proxy
description: Windows 原生 API 配置与启动窗口
colors:
  primary: "#176B56"
  ink: "#202C39"
  muted: "#506071"
  surface: "white"
  error: "firebrick"
typography:
  headline:
    fontFamily: "Microsoft YaHei UI"
    fontSize: "20pt"
    fontWeight: 700
  body:
    fontFamily: "Microsoft YaHei UI"
    fontSize: "10pt"
    fontWeight: 400
  label-primary:
    fontFamily: "Microsoft YaHei UI"
    fontSize: "12pt"
    fontWeight: 700
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    typography: "{typography.label-primary}"
    height: "48px"
---

# Design System: claude-proxy

## Overview

当前界面采用 Windows 原生操作工具（Operate）方向：白底、深色文字、系统控件和一个深绿主按钮。视觉层级服务于填写 API 信息并启动独立实例，不设营销展示区。界面面向 Windows 新手，主要输入直接可见，目录设置收在“更多选项”中。

本文件记录 `launcher-gui.ps1` 的已实现样式，产品约束来自 `PRODUCT.md`，交互范围来自 `spec/modules/gui-setup.md`。没有另行命名创意隐喻。Windows 主题、字体可用性及 DPI 会影响原生控件的最终呈现。

**Key Characteristics:**
- 原生 Windows Forms 控件与系统焦点、禁用状态。
- 单列输入、一个固定在底部的主要操作。
- Key 密文输入；状态文字、进度条、取消和重试提供反馈。

## Colors

主色是深绿，文字使用深蓝灰与较浅蓝灰，背景保持白色。精确值以 frontmatter 为准；原生控件边框、禁用表面与进度条颜色由 Windows 绘制。

### Primary

- **深绿**（`primary`）：主要按钮、更多选项与日志链接，以及成功打开进程后的状态文字。

### Neutral

- **白色**（`surface`）：窗口背景与启用主按钮的文字。
- **深蓝灰**（`ink`）：标题、字段标签及默认文字。
- **辅助蓝灰**（`muted`）：说明、Key 提示、默认状态、页脚与取消链接。

错误状态使用 **砖红**（`error`），并配有说明与重试文案；颜色不是唯一反馈。没有自定义色阶或统一的 hover 色值。

## Typography

标题、正文和主按钮均使用 Windows 字体 Microsoft YaHei UI。`Drawing.Font` 的尺寸单位为点，frontmatter 用 `pt` 保留这一事实；未实现网页字体栈。

- **Headline**：首行“把这套 API 配好，直接开始用。”，粗体。
- **Body**：输入标签、说明、状态、链接与原生输入控件。
- **Label-primary**：主要按钮的粗体操作文字。

没有独立展示字体、等宽字体、字距或行高令牌。文本框与下拉框保留原生文本渲染。

## Layout

窗口初始客户区为 680 × 750，最小外框为 600 × 480；启用 DPI 自动缩放。窗口在当前屏幕工作区内限制尺寸：宽度取 680 与工作区宽度减 50 的较小值，高度取目标高度与工作区高度减 80 的较小值，同时受最小窗口尺寸约束。

窗口内边距为左右 28、上下 22。单列 `TableLayoutPanel` 放在可滚动区域中；每行下边距为 6。字段标签行高 27，文本框行高 38。上述均为源代码中的布局数值，不等同于所有 DPI 下的截图物理像素。

主按钮停靠在窗口内容底部，位于输入滚动区之外。小高度窗口中，输入与说明可垂直滚动，主按钮持续可见。没有网页断点或移动端布局。

“更多选项”展开两个目录输入行，右侧浏览按钮列宽为 90；展开区行高由 0 切换为 80，窗口目标客户区高度变为 830，收起后恢复 750，仍受屏幕工作区约束。

## Elevation & Depth

内容区域为平面白底，没有自定义阴影、浮层卡片或渐变。输入边框、窗口边框和系统对话框由 Windows 提供；层级主要依靠文字大小、留白、原生边框与主按钮填色。

## Shapes

主按钮为无边框的平直矩形（`FlatStyle = Flat`），未实现圆角。文本框、下拉框、浏览按钮及链接保留 Windows Forms 原生外观；没有自定义圆角令牌。

## Components

### Primary action

底部唯一的填色主按钮使用 `button-primary` 样式。默认文案为“配置并启动 Claude”；准备中禁用并改为“正在准备，请稍候…”；后台失败或取消后显示“重试配置并启动”。窗口将该按钮设为 `AcceptButton`。原生 hover、focus、disabled 呈现由框架处理，没有另写动画或焦点环。

### Instance selector and fields

原生只选下拉框在“新增一套自定义 API”和已有实例间切换。主要字段按名称、API 基础地址、模型名称、API Key 排列；每个字段具有可见标签与 `AccessibleName`。

Key 使用 `UseSystemPasswordChar`。切换实例会清空 Key 输入，已有实例留空表示保留已保存 Key；提交请求后清空输入。已有实例名称不可编辑。字段缺失时状态区提示，并将焦点移到对应输入。

### Advanced options

链接展开保存位置与代码项目目录。保存位置文本框只读，通过系统文件夹选择对话框修改；代码项目目录可填写或浏览选择。展开内容与主要表单位于同一滚动区。

### Status and progress

状态文字位于表单下部。后台准备时显示原生 Marquee 进度条，主要输入和主按钮禁用，取消链接可用。实际准备任务启动后显示“查看安装日志”链接；预览模式的工作中截图没有启动后台任务，因此没有该日志链接。

失败显示错误文字与重试按钮，保留配置的提示直接写在反馈中。成功文字表示已准备并打开 Claude 进程，不表示已验证真实 API 或模型。后台轮询间隔为 500 毫秒，没有自定义动效时长。

### Cancellation and close

“取消准备”停止本窗口的后台任务，并提示已保存配置保留、可以重试。任务运行时关闭窗口会弹出原生 Yes/No 确认框。该取消入口在可滚动内容区域内，未固定到底部。

## Do's and Don'ts

- **Do** 保留一个主要操作，并让小高度窗口中的主按钮持续可见。
- **Do** 使用原生控件状态、可见标签与明确状态文字说明当前动作。
- **Do** 将 Key 保持为密文输入，保持日志与截图不包含真实 Key。
- **Do** 以当前系统主题和 DPI 下的实际窗口检查布局。
- **Don't** 将原生控件误写为网页组件或声称存在移动端断点。
- **Don't** 为记录当前界面而添加不存在的圆角、阴影、色阶或动效。
- **Don't** 把“已打开 Claude”描述成真实 API 验证成功。

本次视觉记录对照了 `F:\Codex\work\claude-proxy-gui-audit\` 中的 `idle-final.png`、`working-final.png`、`failed-final.png`、`small-final.png`。它们覆盖初始、准备中、失败和小高度窗口；不构成真实服务调用或干净新机安装证据。

`.impeccable/design.json` 仅携带当前设计叙述。该 sidecar 的 HTML/CSS 预览机制不适用于 Windows Forms，故组件数组为空；没有构造网页替身或补造色阶。
