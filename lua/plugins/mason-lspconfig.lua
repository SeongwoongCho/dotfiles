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
            ensure_installed = { "clangd", "lua_ls", "pylsp" }, -- 원하는 서버 나열
            automatic_installation = true,                      -- old automatic_enable 대체
        })

        -- jedi-language-server 자동 설치 함수
        local function ensure_jedi()
            if vim.fn.executable("jedi-language-server") == 0 then
                vim.notify("⚙️  jedi-language-server가 설치되어 있지 않아 pip으로 설치합니다...", vim.log.levels.INFO)
                -- 시스템에 따라 pip3 / python3 -m pip 중 하나 선택하세요
                local cmd = "python3 -m pip install --user jedi-language-server"
                -- 또는 local cmd = "pip3 install --user jedi-language-server"
                local result = os.execute(cmd)
                if result ~= 0 then
                    vim.notify("❗️ jedi-language-server 설치에 실패했습니다. 수동으로 설치해주세요.", vim.log.levels.ERROR)
                else
                    vim.notify("✅ jedi-language-server 설치 완료!", vim.log.levels.INFO)
                end
            end
        end

        ensure_jedi()

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
