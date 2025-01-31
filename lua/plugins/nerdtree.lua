return {
    "preservim/nerdtree",
    config = function()
    	vim.keymap.set("n", "\"", ":NERDTreeToggle<CR>", { noremap = true, silent = true })
    end,
    dependencies = {
        "3rd/image.nvim" 
    }
}
