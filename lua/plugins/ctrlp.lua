return 
{
    'ctrlpvim/ctrlp.vim',
    config = function()
        local g = vim.g 
    
        vim.opt.runtimepath:prepend('~/.vim/bundle/ctrlp.vim')
        vim.opt.wildignore:append('*/tmp/*,*.so,*.swp,*.zip')
        g.ctrlp_user_command = {'.git/', 'git --git-dir=%s/.git ls-files -oc --exclude-standard'}
        g.ctrlp_custom_ignore = {file = '\\v\\.(pyc|so|dll)$'}
    end
}
