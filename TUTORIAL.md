# claude-proxy 小白教程

## 这个项目是什么？能用来做什么？

**一句话解释：** claude-proxy 让你在 Claude Code 里用其他 AI 服务（比如 DeepSeek、Gemini、通义千问）。

**稍微详细一点：**
Claude Code 是一个 AI 编程助手，原本只能连接 Anthropic 官方的 API。但你可能有其他 AI 服务的 API key（比如 DeepSeek 便宜、Gemini 有免费额度、通义千问国内速度快），你想在 Claude Code 里用它们。

claude-proxy 就是一个"中间人"——它帮你配置好环境变量，让 Claude Code 以为自己在跟 Anthropic 对话，实际上请求被转发到了你指定的 AI 服务。

**你不需要懂任何编程知识**，只要跟着下面的步骤操作就行。

> 想看所有命令行参数和技术细节？见 [README.md](./README.md)。

---

## 我需要什么前置知识？

**几乎不需要。** 你只需要会：

1. 下载文件
2. 双击文件
3. 复制粘贴（API key）
4. 按回车

如果你知道什么是"命令行"和"PowerShell"，那更好；如果不知道，也没关系，教程会一步步教你。

---

## 第零步：我该用哪个 AI？

第一次用就选默认的 **DeepSeek**，最省事。下面是几个常见选择：

| AI | 注册网址 | 需要什么 | 在哪拿 key | 对应命令 | 备注 |
|----|----------|----------|------------|----------|------|
| **DeepSeek（默认推荐）** | https://platform.deepseek.com/api_keys | 手机号注册，实名后充值（额度以官网为准） | "API keys"页面，点新建 | 直接双击 `setup.bat`（默认就是它） | 国内直连、便宜、**无需装 Python**（走 Anthropic 直连） |
| MiMo（小米） | 需到小米 MiMo 平台确认 | 视平台而定 | 平台控制台 | `-Provider mimo` | 国内直连 |
| Google Gemini | https://aistudio.google.com/apikey | Google 账号（通常需要梯子） | 点 "Create API key" | 见 README"添加 provider" | 有免费额度，但要先在 `providers.local.ps1` 里启用，且首次会装 Python+LiteLLM |

> 不确定就用默认 DeepSeek：双击 `setup.bat`，按提示去上面的网址申请一把 key 粘进来即可。**不要在教程里记额度/价格数字**，一切以官网为准。

---

## 第一步：下载文件

1. 打开这个项目的 GitHub 页面：https://github.com/fisHarly0/claude-proxy
2. 点击绿色的 **"Code"** 按钮
3. 选择 **"Download ZIP"**
4. 解压下载的 ZIP 文件，把里面的文件放到一个你方便找到的文件夹（比如 `D:\claude-proxy`）

> **为什么用 Download ZIP，而不是单个文件另存为？**
> 主脚本 `claude-proxy.ps1` 对文件编码很敏感（需要 UTF-8 BOM）。用浏览器"另存为"单个文件，常常会把编码弄坏，导致中文乱码、双击闪退。Download ZIP 拿到的是原始字节，不会坏。

运行只需要这两个文件（ZIP 里都有）：
- `setup.bat` —— 一键启动器
- `claude-proxy.ps1` —— 主脚本

（`providers.local.example.ps1` 是想加更多 AI 时才用的模板，可选。）

---

## 第二步：双击 setup.bat

找到你刚才解压的文件夹，双击 `setup.bat`。

**会发生什么：**

1. 一个黑色窗口会弹出来
2. 脚本会自动检测你的电脑有没有装 Node.js（Claude Code 需要它）
3. 如果没装，脚本会自动帮你装（通过 winget，Windows 自带的包管理器）
4. 脚本会检测有没有 Claude Code CLI，没装也会自动装
5. 脚本会检测有没有 Git（可选，不影响启动）
6. 最后，脚本会提示你粘贴 API key

> **第一次会比较久**（要联网下载安装）。装东西的时候窗口可能"看起来没动静"，**这是正常的，请耐心等待、不要关闭窗口**。默认的 DeepSeek 走直连，不需要装 Python，会快不少。

**你需要做的唯一一件事：** 当看到提示让你粘贴 API key 时，把你申请到的 key 粘贴进去，按回车。

> **注意：粘贴时屏幕上看不到任何字符，这是故意的**（防止 key 被旁人/截图看到）。你正常粘贴、直接回车就行。保存成功后会显示 key 的末 4 位供你核对。

> **API key 是什么？** 就像一个密码，证明你有权使用某个 AI 服务。去对应 AI 服务商的官网申请（见上面"第零步"的表格）。

粘贴后，key 会被保存到同目录的 `.env` 文件里。下次启动就不会再问你了。

---

## 第三步：开始使用

如果一切顺利，你会看到类似这样的信息（版本号以实际为准）：

```
  ════════ Claude Code 代理 ════════
   版本     : v1.2.0
   Provider : deepseek (DeepSeek)
   模型     : deepseek-v4-pro
   协议     : Anthropic (直连)
   端点     : https://api.deepseek.com/anthropic
   工作目录 : C:\Users\你的用户名\Desktop
   配置目录 : C:\Users\你的用户名\.claude-deepseek (隔离)
  ══════════════════════════════════
```

然后 Claude Code 就启动了，你可以正常使用它。

**验证代理是否生效：** 在 Claude Code 里输入 `/model`，显示的模型名应该与上面一致。

---

## 进阶用法

### 使用不同的 AI 服务

默认使用 DeepSeek。想用其他的，在命令行里指定（也可以 `setup.bat -Provider mimo` 这样传给启动器）：

```powershell
# 使用 MiMo
.\claude-proxy.ps1 -Provider mimo
```

> **注意：** 首次使用某个 **OpenAI 格式**的 provider（如 Gemini、Moonshot）时，脚本会自动安装 Python 和 LiteLLM（一个协议转换工具）。这是正常的，只需要等一会儿。默认的 DeepSeek 和 MiMo 是直连，不需要这些。

### 查看所有可用的 provider

```powershell
.\claude-proxy.ps1 -List
```

### 添加自己的 AI 服务

如果你想用一个不在默认列表里的 AI 服务：

1. 把 `providers.local.example.ps1` 复制一份，改名为 `providers.local.ps1`
2. 用记事本（推荐 VS Code）打开 `providers.local.ps1`
3. 找到一个被 `#` 注释掉的示例，取消注释（删掉每行开头的 `#`）
4. 把里面的占位符替换成你的真实信息：
   - `baseUrl` → 你的 API 地址
   - `apiKey` → 留 `PASTE_YOUR_..._HERE` 即可，首次运行会提示你粘贴
   - `model` → 你想用的模型名
   - `protocol` → OpenAI 格式填 `"openai"`，Anthropic 格式填 `"anthropic"`
5. 保存文件
6. 运行 `.\claude-proxy.ps1 -Provider 你起的名字`

> **为什么改 `providers.local.ps1` 而不是主脚本？** 因为更新（`-Update`）会覆盖主脚本 `claude-proxy.ps1`，但**永远不会动 `providers.local.ps1`**。你加的 provider 在每次更新后都还在。所以**不要去改 `claude-proxy.ps1`**。

### 临时用一个不在列表里的 AI 服务

不想改文件，临时用一下：

```powershell
.\claude-proxy.ps1 -Provider custom -BaseUrl "https://api.example.com/v1" -ApiKey "sk-你的key" -Model "模型名" -Protocol openai
```

### 指定工作目录

想让 Claude Code 启动后直接在某个项目目录下工作：

```powershell
.\claude-proxy.ps1 -WorkDir "C:\my\project"
```

### 跳过依赖检查加速启动

如果你已经把 Node.js、Claude Code、Git 都装好了：

```powershell
.\claude-proxy.ps1 -SkipChecks
```

### 更新脚本

默认每 12 小时检查一次，发现新版**只提示、不会自动更新**。想更新时手动运行：

```powershell
.\claude-proxy.ps1 -Update
```

或者直接去 GitHub 重新 Download ZIP（如果你更在意安全，推荐这种）。

---

## 安全小提示

- **API key 等于账号密码。** 别把整个文件夹（含 `.env`）打包发给别人、传网盘、上传到 GitHub。
- 求助时只发**报错文字**，不要截到含 key 的窗口。
- 录入 key 时屏幕看不到字符是正常的（防偷看）。

---

## 遇到问题怎么办？

### 问题 1：双击 setup.bat 后提示"无法加载脚本"

**原因：** Windows 默认禁止运行 PowerShell 脚本。

**解决方法：** `setup.bat` 通常会自动处理。如果仍不行，打开 PowerShell（在开始菜单搜索 "PowerShell"），运行：
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```
然后输入 `Y` 确认，再重新双击 `setup.bat`。（若被公司/学校的组策略锁定，这一步可能也无效，需要联系管理员。）

### 问题 2：提示找不到 Node.js / Claude Code

**原因：** 这些软件还没装，或者刚装完 PATH 没生效。

**解决方法：**
1. 脚本会自动帮你装，等它装完
2. 如果装完后还是找不到，**关闭当前窗口，重新双击 `setup.bat`**
3. 脚本有自动重开机制（最多 3 次），大多数情况不需要手动操作

### 问题 3：粘贴 API key 后提示"key 未设置"

**原因：** 可能粘贴时是空的，或者 key 本身不对。

**解决方法：**
1. 重新运行脚本，在提示处重新粘贴（注意：屏幕看不到字符是正常的，正常粘贴+回车即可）
2. 确认你复制的是完整的 key
3. 或者手动编辑 `.env` 文件，把 key 填进去（格式：`DEEPSEEK_API_KEY=你的key`）

### 问题 4：LiteLLM 启动失败（仅 OpenAI 格式 provider）

**原因：** Python 没装好，或者 LiteLLM 安装失败。

**解决方法：**
1. 关掉窗口，重新双击 `setup.bat` 再试一次（多半是网络问题）
2. 手动安装 LiteLLM：打开 PowerShell，运行 `pip install litellm`
3. 如果 `pip` 命令找不到，说明 Python 没装好，去 https://www.python.org/downloads/ 下载安装
4. 默认的 DeepSeek 不用 LiteLLM，可以先用它

### 问题 5：启动后 Claude Code 说"认证失败"

**原因：** API key 不对，或者过期了。

**解决方法：**
1. 检查你的 API key 是否正确、是否有效（去服务商官网确认）
2. 如果 key 过期了，申请一个新的
3. 编辑 `.env` 文件，把旧 key 替换成新的

### 问题 6：更新后自定义 provider 丢了

**原因：** 不应该发生。`providers.local.ps1` 不会被更新覆盖。

**解决方法：** 检查 `providers.local.ps1` 文件是否还在；如果不在了，可能是误删了，重新从 `providers.local.example.ps1` 复制一份。

### 问题 7：想回退到旧版本

**解决方法：** `-Update` 更新时旧版会按版本号备份为 `claude-proxy.<旧版本>.bak`。在文件夹里找到它，把当前 `claude-proxy.ps1` 改个名，把 `.bak` 文件改名回 `claude-proxy.ps1` 即可。

### 问题 8：中文乱码 / 双击闪退

**原因：** 多半是用浏览器"另存为"单独下载文件，把编码/换行符弄坏了。

**解决方法：**
- **最稳的办法是用 Download ZIP 取文件，不要逐个另存。**
- 如果一定要手动改：`claude-proxy.ps1` 必须是 **UTF-8 with BOM**，`setup.bat` 必须是 **CRLF 换行**。推荐用 VS Code 编辑，底部状态栏可以看到和修改编码/换行符。

### 问题 9：还是不行

1. 检查你的 Windows 版本（需要 Win10 或 Win11）
2. 去 GitHub 项目的 Issues 页面搜索你的问题，或者提一个新 Issue
3. 提 Issue 时请附上（**注意不要截到 API key**）：
   - 你的 Windows 版本
   - 完整的错误信息（截图或复制文字）
   - 你运行的命令
