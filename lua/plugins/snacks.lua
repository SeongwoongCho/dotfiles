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

                -- only inverse properties that are enabled in default configuration
                -- Snacks.bigfile.enabled = not Snacks.bigfile.enabled
                -- Snacks.dashboard.enabled = not Snacks.dashboard.enabled
                Snacks.indent.enabled = not Snacks.indent.enabled 
                -- Snacks.input.enabled = not Snacks.input.enabled
                -- Snacks.picker.enabled = not Snacks.picker.enabled                
                -- Snacks.notifier.enabled = not Snacks.notifier.enabled
                -- Snacks.quickfile.enabled = not Snacks.quickfile.enabled
                -- Snacks.statuscolumn.enabled = not Snacks.statuscolumn.enabled
            end, { noremap = true, silent = true })

        end
    }

