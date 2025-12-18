return { -- Highlight, edit, and navigate code
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	config = function()
		-- Install parsers
		local ensure_installed = {
			"bash",
			"c",
			"diff",
			"html",
			"lua",
			"luadoc",
			"markdown",
			"markdown_inline",
			"latex",
			"query",
			"vim",
			"vimdoc",
		}
		-- Filetypes to skip auto-install (no parser available)
		local ignore_filetypes = {
			["snacks_notif"] = true,
			["snacks_dashboard"] = true,
			["snacks_picker_input"] = true,
		}
		-- Auto-install parsers
		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				local ft = vim.bo.filetype
				if ignore_filetypes[ft] then
					return
				end
				local lang = vim.treesitter.language.get_lang(ft) or ft
				local ok = pcall(vim.treesitter.language.inspect, lang)
				if not ok then
					pcall(function()
						vim.cmd("TSInstall " .. lang)
					end)
				end
			end,
		})
		-- Install specified parsers on startup
		vim.schedule(function()
			for _, lang in ipairs(ensure_installed) do
				local ok = pcall(vim.treesitter.language.inspect, lang)
				if not ok then
					pcall(function()
						vim.cmd("TSInstall! " .. lang)
					end)
				end
			end
		end)
	end,
}
