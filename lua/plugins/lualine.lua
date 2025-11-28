local bubblegum_theme = {
	normal = {
		a = { fg = "#303030", bg = "#afd787", gui = "bold" },
		b = { fg = "#b2b2b2", bg = "#3a3a3a" },
		c = { fg = "#afd787", bg = "#444444" },
	},
	insert = {
		a = { fg = "#303030", bg = "#87afd7", gui = "bold" },
		b = { fg = "#b2b2b2", bg = "#3a3a3a" },
		c = { fg = "#87afd7", bg = "#444444" },
	},
	visual = {
		a = { fg = "#303030", bg = "#d7afd7", gui = "bold" },
		b = { fg = "#b2b2b2", bg = "#3a3a3a" },
		c = { fg = "#d7afd7", bg = "#444444" },
	},
	replace = {
		a = { fg = "#303030", bg = "#d78787", gui = "bold" },
		b = { fg = "#b2b2b2", bg = "#3a3a3a" },
		c = { fg = "#d78787", bg = "#444444" },
	},
	command = {
		a = { fg = "#303030", bg = "#87afd7", gui = "bold" },
		b = { fg = "#b2b2b2", bg = "#3a3a3a" },
		c = { fg = "#87afd7", bg = "#444444" },
	},
	inactive = {
		a = { fg = "#b2b2b2", bg = "#444444", gui = "bold" },
		b = { fg = "#b2b2b2", bg = "#444444" },
		c = { fg = "#b2b2b2", bg = "#444444" },
	},
}

return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		options = {
			icons_enabled = true,
			theme = bubblegum_theme,
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			disabled_filetypes = {
				statusline = {},
				winbar = {},
			},
			ignore_focus = {},
			always_divide_middle = true,
			globalstatus = false,
			refresh = {
				statusline = 1000,
				tabline = 1000,
				winbar = 1000,
			},
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "branch", "diff", "diagnostics" },
			lualine_c = { { "filename", path = 1 } },
			lualine_x = { "encoding", "fileformat", "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
		inactive_sections = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = { { "filename", path = 1 } },
			lualine_x = { "location" },
			lualine_y = {},
			lualine_z = {},
		},
		tabline = {
			lualine_a = { "buffers" },
			lualine_b = {},
			lualine_c = {},
			lualine_x = {},
			lualine_y = {},
			lualine_z = {},
		},
		winbar = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = {},
			lualine_x = {},
			lualine_y = {},
			lualine_z = {},
		},
		inactive_winbar = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = {},
			lualine_x = {},
			lualine_y = {},
			lualine_z = {},
		},
		extensions = { "quickfix" },
	},
}
