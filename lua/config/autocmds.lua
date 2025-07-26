-----------------------------------------------------------
-- Autocommand functions
-----------------------------------------------------------

-- Define autocommands with Lua APIs
-- See: :h api-autocmd, :h augroup
-- https://neovim.io/doc/user/autocmd.html

local augroup = vim.api.nvim_create_augroup   -- Create/get autocommand group
local autocmd = vim.api.nvim_create_autocmd   -- Create autocommand

-----------------------------------------------------------
-- General settings
-----------------------------------------------------------

-- Automatically disable 'paste' mode when leaving insert mode
autocmd("InsertLeave", {
    pattern = "*",
    command = "silent! set nopaste",
})

-- autocmd("InsertEnter", {
--     pattern = "*",
--     command = "set paste",
-- })

autocmd("FileType", {
    pattern = "*",
    command = "setlocal formatoptions-=c formatoptions-=r formatoptions-=o",
})

-- Automatically fix unmatched indentation 
-- autocmd("BufWritePost", {
--     pattern = "*",
--     command = "normal! gg=G"
-- })
--
-- vim.api.nvim_create_autocmd("CursorMoved", {
--     pattern = "*",
--     callback = function()
--         vim.w.cursor_pos = vim.api.nvim_win_get_cursor(0)
--     end
-- })
-- autocmd("BufWritePost", {
--     pattern = "*",
--     callback = function()
--         -- Restore the cursor position after saving the file
--         if vim.b.cursor_pos then
--             pcall(vim.api.nvim_win_set_cursor, 0, vim.b.cursor_pos)  -- Use pcall to prevent errors
--         end
--     end
-- })
