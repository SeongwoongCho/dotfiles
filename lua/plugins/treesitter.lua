return { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
        -- ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'python', 'luadoc', 'markdown', 'markdown_inline', 'latex', 'query', 'vim', 'vimdoc'},
        ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'latex', 'query', 'vim', 'vimdoc'},
        ignore_install = { "python" },
        -- Autoinstall languages that are not installed
        auto_install = true,
        highlight = {
            enable = true,
            -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
            --  If you are experiencing weird indenting issues, add the language to
            --  the list of additional_vim_regex_highlighting and disabled languages for indent.
            disable = {"lua", "conf"}, -- not working 
            -- disable = { "lua", "conf"},
            additional_vim_regex_highlighting = { 'ruby'},
        },
        indent = { enable = true, disable = { 'ruby' } },
    },
    -- init = function()
    --     vim.api.nvim_create_autocmd("FileType", {
    --         pattern = "*", 
    --         callback = function()
    --             vim.cmd("TSEnable highlight")
    --         end,
    --     })
    -- end
}
