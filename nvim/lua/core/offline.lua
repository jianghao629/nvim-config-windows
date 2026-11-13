-- 离线包支持：install.ps1 会生成 <stdpath('data')>/offline_paths.txt，
-- 里面是随包附带的 LSP/格式化工具目录。启动时把它们加入 PATH，
-- 这样 clangd / lua-language-server / stylua 都能直接按命令名找到。
-- 文件不存在时（例如 git clone 后在线安装）则完全不做任何事。
local data_dir = vim.fn.stdpath("data")
local paths_file = data_dir .. "/offline_paths.txt"

if vim.fn.filereadable(paths_file) ~= 1 then
    return
end

vim.g.nvim_config_offline = true

local sep = jit.os == "Windows" and ";" or ":"
local current = vim.env.PATH or ""
for _, line in ipairs(vim.fn.readfile(paths_file)) do
    local dir = vim.trim(line)
    if dir ~= "" and vim.fn.isdirectory(dir) == 1 and not current:find(dir, 1, true) then
        current = dir .. sep .. current
    end
end
vim.env.PATH = current
