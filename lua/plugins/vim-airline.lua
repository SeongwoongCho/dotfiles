return {
   'vim-airline/vim-airline',
    init = function()
        local g = vim.g

        g['airline#extensions#tabline#enabled'] = 1
        g['airline#extensions#tabline#show_buffers'] = 1 
        g['airline#extensions#tabline#formatter'] = 'unique_tail'
        g.airline_theme = 'bubblegum'
        g.airline_section_b = '%{strftime("%a %H:%M:%S %Y-%m-%d")}'
        vim.opt.laststatus = 2
    end,
    dependencies = {
        'vim-airline/vim-airline-themes'
    }
}
