return 
{
    'davidhalter/jedi-vim',
    config = function()
        local g = vim.g
        
        g["jedi#goto_command"] = "<leader>d"
        g["jedi#goto_assignments_command"] = "<leader>g"
        g["jedi#completions_enabled"] = 1
        g["jedi#show_call_signatures"] = 1
        g["jedi#show_call_signatures_delay"] = 50
        g["jedi#use_tabs_not_buffers"] = 0
        g["jedi#smart_auto_mappings"] = 0
        g["jedi#popup_on_dot"] = 0
        g["jedi#auto_close_doc"] = 1
    
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "python",
            callback = function()
                vim.opt_local.completeopt:remove("preview")
            end
        })
    end
}
