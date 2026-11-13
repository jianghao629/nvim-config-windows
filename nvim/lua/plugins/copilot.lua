local function deepseek_api_key()
    local key = vim.env.DEEPSEEK_API_KEY
    if key and key ~= "" then
        return key
    end

    local file = vim.fn.expand("~/.config/deepseek/api_key")
    if vim.fn.filereadable(file) == 1 then
        local lines = vim.fn.readfile(file)
        return lines[1] and vim.trim(lines[1]) or nil
    end
end

local api_key = deepseek_api_key()

return {
    "jianghao629/copilot-deepseek.nvim",
    -- 没有配置 API key 时不加载（离线/无 key 环境不会报错，只是没有 AI 补全）
    enabled = api_key ~= nil,
    event = "InsertEnter",
    opts = {
        backend = "deepseek",
        deepseek = {
            api_key = api_key,
            endpoint = "https://api.deepseek.com/beta/completions",
            model = "deepseek-flash",
            max_tokens = 256, -- 补全短一点（配合下面的 max_lines = 4）
        },
        suggestion = {
            auto_trigger = true,
            max_lines = 4, -- 最多显示/接受 4 行
            trigger_on_accept = false, -- Tab 只在有 ghost text 时接受，否则交给 blink
            keymap = {
                accept = "<Tab>",
            },
        },
        panel = {
            enabled = true, -- <M-CR> 打开补全面板
        },
    },
    config = function(_, opts)
        require("copilot").setup(opts)
    end,
}
