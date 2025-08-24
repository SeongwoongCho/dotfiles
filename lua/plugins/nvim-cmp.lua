return {
    {
        'hrsh7th/nvim-cmp',
        -- commit = "6c84bc75c64f778e9f1dcb798ed41c7fcb93b639",
        lazy = false,
        priority = 1000,
        dependencies = {
            'neovim/nvim-lspconfig',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-nvim-lsp-signature-help',
            'hrsh7th/cmp-cmdline',
            'onsails/lspkind.nvim',
            'ray-x/cmp-treesitter',
            'L3MON4D3/LuaSnip',
            'saadparwaiz1/cmp_luasnip',
            'petertriho/cmp-git',
            -- 'Exafunction/windsurf.vim'
        },
        -- comments
        event = "InsertEnter",
        config = function()
            -- Store capabilities globally for mason-lspconfig to use
            _G.lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()

            local cmp = require 'cmp'
            local luasnip = require 'luasnip'
            cmp.setup {
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                formatting = {
                    format = require 'lspkind'.cmp_format {
                        mode = "symbol_text",
                        symbol_map = {
                            Text = "󰉿",
                            Method = "󰆧",
                            Function = "󰊕",
                            Constructor = "",
                            Field = "󰜢",
                            Variable = "󰀫",
                            Class = "󰠱",
                            Interface = "",
                            Module = "",
                            Property = "󰜢",
                            Unit = "󰑭",
                            Value = "󰎠",
                            Enum = "",
                            Keyword = "󰌋",
                            Snippet = "",
                            Color = "󰏘",
                            File = "󰈙",
                            Reference = "󰈇",
                            Folder = "󰉋",
                            EnumMember = "",
                            Constant = "󰏿",
                            Struct = "󰙅",
                            Event = "",
                            Operator = "󰆕",
                            TypeParameter = "",
                            Codeium = "󰚩",
                        },
                        menu = {
                            nvim_lsp = "[LSP]",
                            buffer = "[Buffer]",
                            latex_symbols = "[Latex]",
                            luasnip = "[LuaSnip]",
                            Codeium = "[AI]",
                        }
                    }
                },

                window = {
                    completion = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },
                view = {
                    entries = {
                        name = 'custom',
                        selection_order = 'near_cursor'
                    }
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<CR>'] = cmp.mapping.confirm {
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    },
                    -- ['<S-Down>'] = cmp.mapping(function(fallback)
                    --     if cmp.visible() then
                    --         cmp.select_next_item()
                    --     elseif luasnip.expand_or_jumpable() then
                    --         luasnip.expand_or_jump()
                    --     else
                    --         fallback()
                    --     end
                    -- end, { 'i', 's' }),
                    -- ['<S-Up>'] = cmp.mapping(function(fallback)
                    --     if cmp.visible() then
                    --         cmp.select_prev_item()
                    --     elseif luasnip.jumpable(-1) then
                    --         luasnip.jump(-1)
                    --     else
                    --         fallback()
                    --     end
                    -- end, { 'i', 's' }),
                }),
                sources = cmp.config.sources({
                    { name = 'codeium',    priority = 1000 },
                    { name = 'nvim_lsp',   priority = 800 },
                    { name = 'luasnip',    priority = 750 },
                    { name = 'buffer',     priority = 500 },
                    { name = 'path',       priority = 250 },
                    { name = 'treesitter', priority = 300 },
                    { name = 'git',        priority = 200 },
                }),
                experimental = {
                    ghost_text = true,
                },
            }

            -- Setup cmdline completion
            cmp.setup.cmdline({ '/', '?' }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = 'buffer' }
                }
            })

            cmp.setup.cmdline(':', {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = 'path' }
                }, {
                    { name = 'cmdline' }
                })
            })
        end
    }
}
