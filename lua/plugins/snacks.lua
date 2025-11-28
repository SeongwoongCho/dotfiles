return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		bigfile = { enabled = true },
		dashboard = {
			enabled = true,
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "startup" },
			},
			preset = {
				keys = {
					{ icon = " ", key = "r", desc = "Session Search", action = ":AutoSession search" },
					{ icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
					{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
					{ icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.picker.grep()" },
					{
						icon = " ",
						key = "c",
						desc = "Config",
						action = ":lua Snacks.picker.files({cwd = vim.fn.stdpath('config')})",
					},
					{ icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
			},
		},
		indent = { enabled = true },
		scope = { enabled = false },
		input = { enabled = true },
		picker = { enabled = true },
		notifier = { enabled = true },
		quickfile = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		words = { enabled = false },

		styles = {
			notification = {
				wo = { wrap = false }, -- Wrap notifications
			},
		},
	},
	init = function()
		vim.keymap.set("n", "<F9>", function()
			vim.cmd("set invnumber")
			vim.cmd("let &signcolumn = ( &signcolumn == 'yes' ? 'no' : 'yes' )")
			Snacks.indent.enabled = not Snacks.indent.enabled
		end, { noremap = true, silent = true, desc = "Toggle line numbers, sign column, and indent guides" })
	end,
}
