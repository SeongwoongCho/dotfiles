return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-telescope/telescope-media-files.nvim" },
	keys = {
		{
			"<C-p>",
			-- function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
			function()
				-- Find the root directory of the nearest Git repository
				local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
				if git_root and vim.fn.isdirectory(git_root) == 1 then
					-- If a Git root directory is found, search files from there
					require("telescope.builtin").find_files({ cwd = git_root })
				else
					-- If no Git directory is found, search from the current working directory
					require("telescope.builtin").find_files({ cwd = vim.fn.getcwd() })
				end
			end,
			desc = "Find Plugin File",
		},
		{
			"<C-o>",
			function()
				-- Find the root directory of the nearest Git repository
				local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
				if git_root and vim.fn.isdirectory(git_root) == 1 then
					-- If a Git root directory is found, search files from there
					require("telescope.builtin").live_grep({ cwd = git_root })
				else
					-- If no Git directory is found, search from the current working directory
					require("telescope.builtin").live_grep({ cwd = vim.fn.getcwd() })
				end
			end,
			desc = "Live Grep",
		},
	},
	-- change some options
	opts = {
		defaults = {
			layout_strategy = "horizontal",
			layout_config = { prompt_position = "top" },
			sorting_strategy = "ascending",
			winblend = 0,
			mappings = {
				i = {
					["<CR>"] = function(prompt_bufnr)
						require("telescope.actions").select_default(prompt_bufnr)
						vim.cmd("stopinsert")
					end,
				},
			},
		},
	},
	config = function()
		-- require("telescope").setup({
		--     extensions = {
		--         media_files = {
		--             -- filetypes whitelist
		--             -- defaults to {"png", "jpg", "mp4", "webm", "pdf"}
		--             filetypes = {"png", "PNG", "webp", "WEBP", "jpg", "JPG", "jpeg", "JPEG"},
		--             -- find command (defaults to `fd`)
		--             -- find_cmd = "rg"
		--         }
		--     },
		-- })
		require("telescope").load_extension("media_files")
	end,
}
