return {
	"nvim-tree/nvim-tree.lua",
	version = "*",
	lazy = false,
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("nvim-tree").setup({})
		vim.keymap.set("n", '"', function()
			require("nvim-tree.api").tree.toggle()
		end, { desc = "Toggle file explorer" })
	end,
}
