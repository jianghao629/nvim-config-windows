return {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	event = "VeryLazy",
	config = function()
		-- 离线包模式下 stylua 由 install.ps1 自带（offline_paths.txt 已加入 PATH），
		-- 在线模式才用 mason 自动安装。
		if vim.g.nvim_config_offline ~= true then
			local registry_ok, registry = pcall(require, "mason-registry")
			if registry_ok then
				local ok, package = pcall(registry.get_package, "stylua")
				if ok and package and not package:is_installed() then
					package:install()
				end
			end
		end

		local null_ls = require("null-ls")
		null_ls.setup({
			sources = {
				null_ls.builtins.formatting.stylua,
			},
		})
	end,
	keys = {
		{ "<leader>lf", vim.lsp.buf.format },
	},
}
