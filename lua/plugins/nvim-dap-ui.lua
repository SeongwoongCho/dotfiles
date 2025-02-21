return {
    "rcarriga/nvim-dap-ui", 
    dependencies = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"}, 
    -- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#ccrust-via-vscode-cpptools
    config = function()
        local dap = require('dap')
        local dapui = require('dapui')
        vim.fn.sign_define('DapBreakpoint', {text='●', texthl='red', linehl='', numhl=''}) 
        
        dap.adapters.cppdbg = {
            id = 'cppdbg',
            type = 'executable',
            command = '/usr/bin/OpenDebugAD7',
        }
        dap.configurations.cpp = {
            {
                name = "Launch file",
                type = "cppdbg",
                request = "launch",
                args = function()
                    return vim.split(vim.fn.input('Input arguments: '), ' ')
                end,
                program = function()
                    return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
                end,
                cwd = '${workspaceFolder}',
                stopAtEntry = true,
            },
            -- {
            --     name = 'Attach to gdbserver :1234',
            --     type = 'cppdbg',
            --     request = 'launch',
            --     MIMode = 'gdb',
            --     miDebuggerServerAddress = 'localhost:1234',
            --     miDebuggerPath = '/usr/bin/gdb',
            --     cwd = '${workspaceFolder}',
            --     program = function()
            --         return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
            --     end,
            -- },
            -- setupCommands = {  
            --     { 
            --         text = '-enable-pretty-printing',
            --         description =  'enable pretty printing',
            --         ignoreFailures = false 
            --     },
            -- }
        }
        dap.configurations.c = dap.configurations.cpp
        dap.configurations.rust = dap.configurations.cpp
    
        dapui.setup()
        dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close()
        end

        -- keymaps
        vim.g.maplocalleader = "."
        vim.keymap.set("n", "?", "<cmd>lua require('dapui').toggle()<cr>", {desc = "Toggle debugger"} )
        vim.keymap.set("n", "<localleader>ss", ":DapContinue<cr>", {desc = "Start debugger"})
        vim.keymap.set("n", "<localleader>rr", ":DapRestartFrame<cr>", {desc = "Restart debugger"})
        vim.keymap.set("n", "<localleader>tt", ":DapTerminate<cr>", {desc = "Terminate debugger"})

        vim.keymap.set("n", "<localleader>b", ":DapToggleBreakpoint<cr>", {desc = "Setting Breakingpoint to the current line"} )
        vim.keymap.set("n", "<localeader>c", ":DapContinue<cr>", {desc = "Start debugger or Stepping through the code"} )
        vim.keymap.set("n", "<localleader>s", ":DapStepInto<cr>", {desc = "Stepping into the code"} ) 
        vim.keymap.set("n", "<localleader>n", ":DapStepOver<cr>", {desc = "Stepping over the code"} ) 
    end
}
