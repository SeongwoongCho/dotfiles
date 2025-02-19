return {
    'neoclide/coc.nvim',
    config = function()
        vim.keymap.set("n", "<leader>d", "<Plug>(coc-definition)")
    end
}
