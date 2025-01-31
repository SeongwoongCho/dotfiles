-- Set leader keys
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Reload vimrc
vim.keymap.set("n", "<leader>R", ":so $MYVIMRC<CR>", { desc = "Reload vimrc" })

-- Turn off search highlight
vim.keymap.set("n", "@", ":noh<CR>", { desc = "Turn off search highlight" })

-- Copy & Paste
vim.keymap.set("n", "<F8>", ":set paste!<CR>")

-- Toggle line numbers
vim.keymap.set("n", "<F9>", ":set invnumber<CR>", { desc = "Toggle line number" })

-- Save file
vim.keymap.set("n", "<leader>s", ":w<CR>", { desc = "Save file" })

-- Navigate buffers
vim.keymap.set("n", "[b", ":bprevious<CR>", { desc = "Go to previous buffer" })
vim.keymap.set("n", "]b", ":bnext<CR>", { desc = "Go to next buffer" })

-- Keep selection after indenting in visual mode
vim.keymap.set("v", "<", "<gv", { desc = "Keep selection after indenting" })
vim.keymap.set("v", ">", ">gv", { desc = "Keep selection after indenting" })

-- Insert ipdb breakpoint for Python debugging
vim.keymap.set("n", "<Leader>b", "Oimport os; import ipdb; ipdb.set_trace(context=15)<Esc>", { desc = "Insert ipdb breakpoint" })
vim.keymap.set("n", "<Leader>v", "oimport os; import ipdb; ipdb.set_trace(context=15)<Esc>", { desc = "Insert ipdb breakpoint" })
