return {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
    opts = {
        provider = "copilot",
        auto_suggestions_provider = "copilot", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
        windows = {
            width = 35,
        },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
        "stevearc/dressing.nvim",
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        --- The below dependencies are optional,
        "echasnovski/mini.pick", -- for file_selector provider mini.pick
        "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
        "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
        "ibhagwan/fzf-lua", -- for file_selector provider fzf
        "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
        "github/copilot.vim", -- for providers='copilot'
        -- "zbirenbaum/copilot.lua", -- for providers='copilot'
    },
    mappings = {
        sidebar = {
            apply_all = "A",
            apply_cursor = "a",
            switch_windows = "<Tab>",
            reverse_switch_windows = "<S-Tab>",
        },
    },
    init = function()
        vim.opt.laststatus = 3
        
        -- autocmd keys
        vim.keymap.set("n", "?", ":AvanteFocus<CR>", { noremap = true, silent = true })
    end
}
