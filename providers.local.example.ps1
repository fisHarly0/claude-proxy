# ============================================================
#  providers.local.example.ps1
#  自定义 provider 模板 —— 把本文件复制一份改名为
#      providers.local.ps1
#  然后填入你自己的 provider。主脚本启动时会自动合并这些 provider。
#
#  为什么要外置？
#    自动更新会整体覆盖 claude-proxy.ps1，但【永远不会动 providers.local.ps1】。
#    所以你加的 provider 和默认设置在每次更新后都还在。
#
#  API key 建议留占位符 PASTE_YOUR_xxx_HERE（首次运行会提示粘贴，存到 .env），
#  不要直接把真实 key 写进来——除非你确定本文件不会被分享出去。
# ============================================================

$LocalProviders = @{

    # —— 示例：Anthropic 格式（直连，无需 LiteLLM）——
    # "openrouter" = @{
    #     baseUrl   = "https://openrouter.ai/api/v1/anthropic"
    #     apiKey    = "PASTE_YOUR_OPENROUTER_KEY_HERE"
    #     model     = "anthropic/claude-sonnet-4"
    #     smallFast = "anthropic/claude-sonnet-4"
    #     label     = "OpenRouter"
    #     protocol  = "anthropic"
    # }

    # —— 示例：OpenAI 格式（脚本自动起 LiteLLM 转换，需要 Python）——
    # "deepseek" = @{
    #     baseUrl   = "https://api.deepseek.com/v1"
    #     apiKey    = "PASTE_YOUR_DEEPSEEK_KEY_HERE"
    #     model     = "deepseek-chat"
    #     smallFast = "deepseek-chat"
    #     label     = "DeepSeek"
    #     protocol  = "openai"
    # }

}

# 可选：覆盖默认 provider（不传 -Provider 时用哪个）
# $LocalDefaultProvider = "deepseek"
