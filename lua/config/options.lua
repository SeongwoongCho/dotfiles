vim.opt.shell = "/bin/zsh"
vim.opt.syntax = "on"
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.ruler = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.fixeol= false
vim.opt.endofline = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.background = "dark"
vim.o.guicursor = "n-v-c-sm:block,i-ci-ve:block,r-cr-o:hor20"

-- Can be ignored
-- vim.opt.t_Co = 256
vim.opt.termguicolors = true
vim.opt.encoding = 'utf-8'
vim.opt.compatible = false

-- misc
vim.opt.visualbell = true
vim.opt.history = 1000
vim.opt.undolevels = 1000
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.wrap = false          -- no line wrapping
vim.opt.textwidth = 0           -- no line wrapping
vim.opt.splitbelow = true       -- split bottom window if needed
vim.opt.lazyredraw = true       -- don't update screen during macro and script execution
vim.opt.equalalways = false
vim.opt.signcolumn = 'yes'

-- clipboard
-- vim.opt.clipboard:append("unnamedplus")
vim.g.clipboard = "osc52"
