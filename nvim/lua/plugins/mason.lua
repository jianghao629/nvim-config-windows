return {
	"williamboman/mason.nvim",
	event = "VeryLazy",
	opts = {},
	dependencies = {
		"neovim/nvim-lspconfig",
		"williamboman/mason-lspconfig.nvim",
	},
	config = function(_, opts)
		require("mason").setup(opts)

		-- 离线包模式下 LSP 二进制由 install.ps1 自带（offline_paths.txt），
		-- 不去碰 mason registry，避免离线时联网报错。
		local offline = vim.g.nvim_config_offline == true
		local registry = nil
		if not offline then
			local ok, reg = pcall(require, "mason-registry")
			if ok then
				registry = reg
			end
		end

		-- mason 包名 → nvim-lspconfig 服务器名（找不到映射时兜底）
		local fallback_server = {
			["lua-language-server"] = "lua_ls",
			["clangd"] = "clangd",
		}

		local servers = {
			["lua-language-server"] = {
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
					},
				},
			},
			["clangd"] = {},
		}

		local mappings_ok, mappings = pcall(function()
			return require("mason-lspconfig.mappings").get_mason_map()
		end)

		local blink_ok, blink = pcall(require, "blink.cmp")

		for name, config in pairs(servers) do
			-- 在线模式：缺什么装什么；离线包：跳过，直接用自带二进制
			if registry then
				local ok, package = pcall(registry.get_package, name)
				if ok and package and not package:is_installed() then
					package:install()
				end
			end

			local server = (mappings_ok and mappings.package_to_lspconfig[name])
				or fallback_server[name]
				or name

			if blink_ok then
				config.capabilities = blink.get_lsp_capabilities()
			end
			config.on_attach = function(client)
				client.server_capabilities.documentFormattingProvider = false
				client.server_capabilities.documentRangeFormattingProvider = false
			end
			vim.lsp.config(server, config)
			vim.lsp.enable(server)
		end

		vim.diagnostic.config({
			virtual_text = true,
			-- virtual_lines = true,
			update_in_insert = true,
		})
	end,
}
