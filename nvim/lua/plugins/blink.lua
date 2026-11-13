return {
    "saghen/blink.cmp",
    dependencies = {
        "rafamadriz/friendly-snippets",
    },
    event = "VeryLazy",
    opts = {
        -- 离线包没有 Rust 版模糊匹配库，用 Lua 实现（功能一致，速度略慢）
        fuzzy = {
            implementation = "lua",
        },
        completion = {
            documentation = {
                auto_show = true
            }
        },
        keymap = {
            preset = "super-tab",
        },
        sources = {
            default = { "path", "snippets", "buffer", "lsp"},
        },
        cmdline = {
            sources = function ()
                local cmd_type = vim.fn.getcmdtype()
                if cmd_type == "/" then
                    return { "buffer" }
                end
                if cmd_type == ":" then
                    return { "cmdline" }
                end
                return {}
            end,

            keymap = {
                preset = "super-tab"
            },
            completion = {
                menu = {
                    auto_show = true
                }
            }
        },
    }
}
