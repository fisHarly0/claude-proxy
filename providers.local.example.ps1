# ============================================================
#  providers.local.example.ps1
#  自定义 / 启用更多 provider 的模板 —— 把本文件复制一份改名为
#      providers.local.ps1
#  然后取消注释你想用的那块、或填入你自己的 provider。
#  主脚本启动时会自动合并这些 provider。
#
#  为什么要外置？
#    自动更新（-Update）会整体覆盖 claude-proxy.ps1，但【永远不会动 providers.local.ps1】。
#    所以你加的 provider 和默认设置，在每次更新后都还在。
#
#  protocol 怎么选？
#    - 你的 API 端点兼容 Anthropic 格式 → "anthropic"（直连，无需 Python/LiteLLM）
#    - 你的 API 端点是 OpenAI 格式      → "openai"（脚本自动起 LiteLLM 转换，需要 Python）
#
#  API key 建议留占位符 PASTE_YOUR_xxx_HERE（首次运行会提示粘贴，存到 .env、不回显），
#  不要直接把真实 key 写进来——除非你确定本文件不会被分享出去。
#  signupUrl 是可选项：填上申请 key 的网址，没填好 key 时脚本会打印出来引导你去申请。
# ============================================================

$LocalProviders = @{

    # ───────── Anthropic 格式（直连，无需 LiteLLM）─────────

    # "openrouter" = @{
    #     baseUrl   = "https://openrouter.ai/api/v1/anthropic"
    #     apiKey    = "PASTE_YOUR_OPENROUTER_KEY_HERE"
    #     model     = "anthropic/claude-sonnet-4"
    #     smallFast = "anthropic/claude-sonnet-4"
    #     label     = "OpenRouter"
    #     protocol  = "anthropic"
    #     signupUrl = "https://openrouter.ai/keys"
    # }

    # ───────── OpenAI 格式（脚本自动起 LiteLLM 转换，需要 Python）─────────

    # "gemini" = @{
    #     baseUrl   = "https://generativelanguage.googleapis.com/v1beta/openai"
    #     apiKey    = "PASTE_YOUR_GEMINI_KEY_HERE"
    #     model     = "gemini-2.5-pro"
    #     smallFast = "gemini-2.5-flash"
    #     label     = "Google Gemini"
    #     protocol  = "openai"
    #     signupUrl = "https://aistudio.google.com/apikey"
    # }

    # "moonshot" = @{
    #     baseUrl   = "https://api.moonshot.cn/v1"
    #     apiKey    = "PASTE_YOUR_MOONSHOT_KEY_HERE"
    #     model     = "moonshot-v1-128k"
    #     smallFast = "moonshot-v1-8k"
    #     label     = "Moonshot (Kimi)"
    #     protocol  = "openai"
    #     signupUrl = "https://platform.moonshot.cn/console/api-keys"
    # }

    # "zhipu" = @{
    #     baseUrl   = "https://open.bigmodel.cn/api/paas/v4"
    #     apiKey    = "PASTE_YOUR_ZHIPU_KEY_HERE"
    #     model     = "glm-4-plus"
    #     smallFast = "glm-4-flash"
    #     label     = "智谱 GLM"
    #     protocol  = "openai"
    #     signupUrl = "https://open.bigmodel.cn/usercenter/apikeys"
    # }

    # "qwen" = @{
    #     baseUrl   = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    #     apiKey    = "PASTE_YOUR_QWEN_KEY_HERE"
    #     model     = "qwen-max"
    #     smallFast = "qwen-turbo"
    #     label     = "通义千问"
    #     protocol  = "openai"
    #     signupUrl = "https://dashscope.console.aliyun.com/apiKey"
    # }

}

# 可选：覆盖默认 provider（不传 -Provider 时用哪个）
# $LocalDefaultProvider = "gemini"
