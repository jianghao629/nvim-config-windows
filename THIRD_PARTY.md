# 第三方组件与许可证

本仓库/Windows 离线包包含或安装以下第三方组件，版权归各自作者所有。

| 组件 | 说明 | 许可证 | 上游 |
| --- | --- | --- | --- |
| Neovim (Windows x64) | 编辑器，离线包内置便携版 v0.11.6 | Apache-2.0 + Vim license | https://github.com/neovim/neovim |
| lazy.nvim | 插件管理器 | MIT | https://github.com/folke/lazy.nvim |
| blink.cmp | 补全引擎（离线包使用 Lua 模糊匹配实现） | MIT | https://github.com/saghen/blink.cmp |
| friendly-snippets | 代码片段 | MIT | https://github.com/rafamadriz/friendly-snippets |
| bufferline.nvim | buffer 标签栏 | MIT | https://github.com/akinsho/bufferline.nvim |
| copilot-deepseek.nvim | Copilot 兼容层，DeepSeek FIM 后端（本仓库作者维护） | MIT | https://github.com/jianghao629/copilot-deepseek.nvim |
| lspsaga.nvim | LSP UI | MIT | https://github.com/nvimdev/lspsaga.nvim |
| lualine.nvim | 状态栏 | MIT | https://github.com/nvim-lualine/lualine.nvim |
| mason.nvim / mason-lspconfig.nvim | LSP 包管理（离线包中不联网） | Apache-2.0 / MIT | https://github.com/williamboman/mason.nvim |
| noice.nvim / nui.nvim / nvim-notify | 命令栏与通知 UI | MIT | https://github.com/folke/noice.nvim |
| none-ls.nvim | 格式化接入 | MIT | https://github.com/nvimtools/none-ls.nvim |
| nvim-autopairs / nvim-surround | 编辑辅助 | MIT | https://github.com/windwp/nvim-autopairs |
| nvim-tree.lua / nvim-web-devicons | 文件树与图标 | MIT | https://github.com/nvim-tree/nvim-tree.lua |
| plenary.nvim | Lua 工具库 | MIT | https://github.com/nvim-lua/plenary.nvim |
| telescope.nvim / telescope-fzf-native.nvim | 模糊查找（Windows 离线包未构建 fzf 原生扩展） | MIT | https://github.com/nvim-telescope/telescope.nvim |
| tokyonight.nvim | 配色（Windows Terminal 片段也取自这里） | Apache-2.0 | https://github.com/folke/tokyonight.nvim |
| nvim-lspconfig | LSP 配置集 | Apache-2.0 | https://github.com/neovim/nvim-lspconfig |
| clangd (Windows 23.1.0) | C/C++ LSP | Apache-2.0 with LLVM exceptions | https://github.com/clangd/clangd |
| lua-language-server (Windows 3.19.2) | Lua LSP | MIT | https://github.com/LuaLS/lua-language-server |
| stylua (Windows v2.6.0) | Lua 格式化 | MPL-2.0 | https://github.com/JohnnyMorganz/StyLua |
| ripgrep (Windows) | 全文搜索（离线包附带静态版） | MIT / Unlicense | https://github.com/BurntSushi/ripgrep |
| fd (Windows) | 文件查找（离线包附带静态版） | MIT / Apache-2.0 | https://github.com/sharkdp/fd |
| Maple Mono NF CN | 等宽中英文 + Nerd Font 图标字体 | SIL OFL 1.1 | https://github.com/subframe7536/maple-font |

字体许可全文见 `env/fonts/OFL.txt` 与 `THIRD_PARTY/OFL.txt`。
clangd / lua-language-server / stylua / ripgrep / fd 的完整许可文件随各自的 Windows 发行包一起分发，
可在 `deps/tools/` 对应目录中查看，或访问上面的上游链接。
