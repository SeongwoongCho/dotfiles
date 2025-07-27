return 
    {
        "folke/snacks.nvim",
        priority = 1000,
        lazy = false,
        ---@type snacks.Config
        opts = {
            -- your configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
            bigfile = { enabled = true },
            dashboard = { enabled = true },
            indent = { enabled = true},
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
                    wo = { wrap = false } -- Wrap notifications
                }
            }
        },
        init = function()
            vim.keymap.set("n", "<F9>", function()
                vim.cmd("set invnumber")
                vim.cmd("let &signcolumn = ( &signcolumn == 'yes' ? 'no' : 'yes' )")
                Snacks.indent.enabled = not Snacks.indent.enabled
            end, { noremap = true, silent = true, desc = "Toggle line numbers, sign column, and indent guides" })

        end
    }

