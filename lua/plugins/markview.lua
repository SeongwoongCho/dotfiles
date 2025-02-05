return {
    "OXY2DEV/markview.nvim",
    enabled = true,
    lazy = false,
    dependencies = { "echasnovski/mini.icons" },
    ft = { "markdown", "Avante" },
    opts = {
        file_types = { "markdown", "Avante" },
        ignore_buftypes = {},
        max_length = 99999,
    },
    preview = {
        icon_provider = "mini", -- "mini" or "devicons"
    },
    init = function()
        -- https://github.com/OXY2DEV/markview.nvim/blob/main/lua/markview/presets.lua
        local presets = require("markview.presets");
        
        require("markview").setup({
            markdown = {
                headings = presets.headings.arrowed
            }
        });
    end,
}
