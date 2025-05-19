return {
    'neoclide/coc.nvim',
    branch = 'release', 
    config = function()
        vim.keymap.set("n", "<leader>d", "<Plug>(coc-definition)")
    end
}
