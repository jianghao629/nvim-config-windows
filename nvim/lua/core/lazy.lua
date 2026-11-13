local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://gh-proxy.com/https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

if not vim.uv.fs_stat(lazypath) then
    vim.notify(
        "lazy.nvim 未安装且无法联网下载，已跳过插件加载。\n"
            .. "请联网后重新启动 Neovim，或使用 nvim-config 离线包运行 install.bat。",
        vim.log.levels.ERROR
    )
    return
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    git = {
        url_format = "https://gh-proxy.com/https://github.com/%s.git",
    },
    -- 离线开箱即用：启动时不要自动联网检查更新 / 下载缺失插件。
    -- 需要更新插件时手动执行 :Lazy sync（需联网 + git）。
    checker = { enabled = false },
    install = { missing = false },
    change_detection = { enabled = false },
    performance = {
        rtp = {
            -- Linux 系统级运行时目录，Windows 上不存在
            paths = jit.os ~= "Windows" and { "/usr/lib/nvim" } or {},
        },
    },
})
