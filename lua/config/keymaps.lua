-- Set leader keys (The localleader is currently only used in debugger (nvim-dap-ui))
vim.g.mapleader = ","
vim.g.maplocalleader = "."

-- Reload vimrc
vim.keymap.set("n", "<leader>R", ":so $MYVIMRC<CR>", { desc = "Reload vimrc" })

-- Turn off search highlight
vim.keymap.set("n", "@", ":noh<CR>", { desc = "Turn off search highlight" })

-- Copy & Paste
vim.keymap.set("n", "<F8>", ":set paste!<CR>")

-- vim.keymap.set("n", "<D-v>", "i<C-r>+<Esc>", { noremap = true, silent = true }) -- Command + V for macOS
-- vim.keymap.set("n", "<C-v>", "i<C-r>+<Esc>", { noremap = true, silent = true }) -- Ctrl + V for Windows/Linux

-- Toggle line numbers
vim.keymap.set("n", "<F9>", ":set invnumber<CR>", { desc = "Toggle line number" })

-- Save file
vim.keymap.set("n", "<leader>s", ":w<CR>", { desc = "Save current file" })

-- Navigate buffers
vim.keymap.set("n", "[b", ":bprevious<CR>", { desc = "Go to previous buffer" })
vim.keymap.set("n", "]b", ":bnext<CR>", { desc = "Go to next buffer" })

-- Keep selection after indenting in visual mode
vim.keymap.set("v", "<", "<gv", { desc = "Indent line left" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent line right" })

-- Insert ipdb breakpoint for Python debugging
vim.keymap.set(
	"n",
	"<leader>b",
	"O__import__('ipdb').set_trace(context=15)<Esc>",
	{ desc = "Insert ipdb breakpoint above" }
)
vim.keymap.set(
	"n",
	"<leader>v",
	"o__import__('ipdb').set_trace(context=15)<Esc>",
	{ desc = "Insert ipdb breakpoint below" }
)

-- go to the previous line after go-to-deifinition
vim.keymap.set("n", "<leader>g", "<C-o>", { desc = "Go to previous location" })

-- yanking
vim.keymap.set("n", "y", '"+y', { noremap = true })
vim.keymap.set("n", "yy", '"+yy', { noremap = true })
vim.keymap.set("v", "y", '"+y', { noremap = true })

-- Visual mode: search and replace selected text in entire file
local function visual_search_replace()
	-- Get the visually selected text
	vim.cmd('noau normal! "vy"')
	local search_text = vim.fn.getreg("v")

	-- Escape special characters for search pattern
	search_text = vim.fn.escape(search_text, "/\\")

	-- Prompt for replacement text
	local replace_text = vim.fn.input("Replace with: ")
	if replace_text == "" then
		return
	end

	-- Escape special characters for replacement text
	replace_text = vim.fn.escape(replace_text, "/\\&~")

	-- Execute the substitution
	vim.cmd(string.format("%%s/%s/%s/g", search_text, replace_text))
end

vim.keymap.set("x", "<leader>s", visual_search_replace, { desc = "Search and replace selected text in entire file" })
