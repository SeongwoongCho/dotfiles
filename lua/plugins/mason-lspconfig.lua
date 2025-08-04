return {
    "mason-org/mason-lspconfig.nvim",
    opts = {},
    dependencies = {
        "mason-org/mason.nvim",
        "neovim/nvim-lspconfig",
    },
    config = function()
        require("mason").setup()

        require("mason-lspconfig").setup({
            ensure_installed = { "clangd", "lua_ls", "pylsp", "jedi_language_server" }, -- 원하는 서버 나열
            automatic_installation = true,                                              -- old automatic_enable 대체
        })

        local sign = function(opts)
            vim.fn.sign_define(opts.name, {
                texthl = opts.name,
                text = opts.text,
                numhl = ''
            })
        end

        sign({ name = 'DiagnosticSignError', text = '✘' })
        sign({ name = 'DiagnosticSignWarn', text = '▲' })
        sign({ name = 'DiagnosticSignHint', text = '⚑' })
        sign({ name = 'DiagnosticSignInfo', text = '' })

        vim.diagnostic.config({
            virtual_text = false,
            severity_sort = true,
            float = {
                border = 'rounded',
                source = 'always',
            },
        })

        vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
            vim.lsp.handlers.hover,
            { border = 'rounded' }
        )

        vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
            vim.lsp.handlers.signature_help,
            { border = 'rounded' }
        )
    end
}
