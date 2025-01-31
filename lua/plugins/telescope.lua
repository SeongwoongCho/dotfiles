return {
    'nvim-telescope/telescope.nvim',
    keys = {
        {
            "<C-p>",
            -- function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
            function()
                -- Find the root directory of the nearest Git repository
                local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
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
            ":Telescope live_grep<CR>",
            desc = "Live Grep"
        }
    },
    -- change some options
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
}
  --
  -- {
  --   "nvim-telescope/telescope.nvim",
  --   keys = {
  --     -- add a keymap to browse plugin files
  --     -- stylua: ignore
  --     {
  --       "<leader>fp",
  --       function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
  --       desc = "Find Plugin File",
  --     },
  --   },

  -- },

