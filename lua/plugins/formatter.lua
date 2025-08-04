return {
    'stevearc/conform.nvim',
    opts = {
        notify_on_error = true,
        format_on_save = {
            timeout_ms = 2000,
            lsp_fallback = true,
        },
        formatters_by_ft = {
            lua = { 'stylua' },
            python = { 'black' },
            cpp = { 'clang-format' },
            c = { 'clang-format' },
            objc = { 'clang-format' },
            objcpp = { 'clang-format' },
        },
    },
}
