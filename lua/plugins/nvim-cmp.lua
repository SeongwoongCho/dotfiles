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
        event = "InsertEnter",
        config = function()
            local lspconfig = require('lspconfig')
            local lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()
            lspconfig.lua_ls.setup({
                capabilities = lsp_capabilities,
            })
            lspconfig.jedi_language_server.setup { capabilities = capabilities }
            lspconfig['pylsp'].setup {
                capabilities = capabilities,
                settings = {
                    pylsp = {
                        plugins = {
                            jedi_completion = {
                                include_params = true,
                            },

                            -- PEP8 체크 (pycodestyle) 플러그인 옵션
                            pycodestyle = {
                                enabled = true,
                                -- 아래에 무시할 PEP8/pycodestyle 코드를 넣으세요
                                ignore = { "E501", "W291", "W391", "W503" },
                                -- 한 줄 최대 길이 제한 변경 (기본 79)
                                maxLineLength = 100,
                            },
                            pyflakes = {
                                enabled = false,
                            }
                        },
                    },
                },
            }

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
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<CR>'] = cmp.mapping.confirm {
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    },
                    ['<Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                    ['<S-Tab>'] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { 'i', 's' }),
                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp',   priority = 1000 },
                    { name = 'codeium',    priority = 800 },
                    { name = 'luasnip',    priority = 750 },
                    { name = 'buffer',     priority = 500 },
                    { name = 'path',       priority = 250 },
                    { name = 'treesitter', priority = 300 },
                    { name = 'git',        priority = 200 },
                })
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
