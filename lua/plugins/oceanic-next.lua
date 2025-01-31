return {
    "roflolilolmao/oceanic-next.nvim" ,
    config = function()
       local g = vim.g
       g.oceanic_next_terminal_bold = 1
       g.oceanic_next_terminal_italic = 1
    end,
    init = function()
        vim.cmd.colorscheme 'OceanicNext'
    end,
    dependencies = {
        "flazz/vim-colorschemes",
    }
}
