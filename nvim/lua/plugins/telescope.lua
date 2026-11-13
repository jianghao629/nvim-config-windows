return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = function()
                -- Windows 离线包没有预编译的 libfzf.dll，也不要求装 cmake/MSVC，
                -- 这里只在 cmake 可用时才尝试编译（联网环境/手动 :Lazy build）。
                if vim.fn.executable("cmake") == 1 then
                    vim.fn.system("cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build")
                end
            end,
        },
    },
    cmd = "Telescope",
    opts = {
        extensions = {
            fzf = {
                fuzzy = true,
                override_generic_sorter = true,
                override_file_sorter = true,
                case_mode = "smart_case",
            },
        },
    },
    config = function(_, opts)
        local telescope = require "telescope"
        telescope.setup(opts)
        -- fzf 原生扩展不存在时静默回退到默认排序器（功能不受影响）
        pcall(function()
            telescope.load_extension("fzf")
        end)
    end,
}
