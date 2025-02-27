return {
    'neoclide/coc.nvim',
    config = function()
        vim.keymap.set("n", "<leader>d", "<Plug>(coc-definition)")
        vim.keymap.set("n", "<leader>g", "<Plug>(coc-references)")
    end
}
