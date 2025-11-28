return {
	"rcarriga/nvim-dap-ui",
	dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
	opts = {
		layouts = {
			{
				elements = {
					{ id = "console", size = 0.5 },
					{ id = "repl", size = 0.5 },
				},
				position = "left",
				size = 50,
			},
			{
				elements = {
					{ id = "scopes", size = 0.50 },
					{ id = "breakpoints", size = 0.20 },
					{ id = "stacks", size = 0.15 },
					{ id = "watches", size = 0.15 },
				},
				position = "bottom",
				size = 15,
			},
		},
	},
	-- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#ccrust-via-vscode-cpptools
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

		local function read_launch_json()
			local launch_file = vim.fn.getcwd() .. "/.vscode/launch.json"
			local file = io.open(launch_file, "r")

			if file then
				local content = file:read("*a") -- 전체 파일 읽기
				file:close()
				local data, _, err = json.decode(content) -- JSON 파싱
				if err then
					print("Error parsing launch.json: " .. err)
					return nil
				end

				-- "configurations" 배열에서 첫 번째 항목 가져오기 (필요하면 인덱스 조정 가능)
				local config = data.configurations and data.configurations[1]
				if config then
					return config
				end
			end
			print("launch.json not found or invalid")
			return nil
		end

		local function ensure_launch_json()
			local launch_file = vim.fn.getcwd() .. "/.vscode/launch.json"

			-- launch.json 파일이 존재하는지 확인
			if vim.fn.filereadable(launch_file) == 1 then
				return
			end

			-- 디폴트 JSON 설정 내용
			local default_config = [[
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "/absolute/path/to/executable",
            "args": ["arg1", "arg2", "arg3"],
            "cwd": "${workspaceFolder}",
            "stopAtEntry": true
        }
    ]
}
            ]]

			-- .vscode 폴더 생성 (없으면)
			vim.fn.mkdir(vim.fn.getcwd() .. "/.vscode", "p")

			-- launch.json 생성
			local file = io.open(launch_file, "w")
			if file then
				file:write(default_config)
				file:close()
				print("Created default launch.json")
			else
				print("Error: Could not create launch.json")
			end
		end

		vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "red", linehl = "", numhl = "" })

		dap.adapters.cppdbg = {
			id = "cppdbg",
			type = "executable",
			command = "/usr/bin/OpenDebugAD7",
		}
		dap.configurations.cpp = {} -- this automatically read .vscode/launch.json
		-- dap.configurations.cpp = {
		--     {
		--         name = function()
		--             local config = read_launch_json()
		--             return config and config.name or "Launch"
		--         end,
		--         type = function()
		--             local config = read_launch_json()
		--             return config and config.type or "cppdbg"
		--         end,
		--         request = function()
		--             local config = read_launch_json()
		--             return config and config.request or "launch"
		--         end,
		--         args = function()
		--             local config = read_launch_json()
		--             return config and config.args or {}
		--         end,
		--         program = function()
		--             local config = read_launch_json()
		--             return config and config.program or vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
		--         end,
		--         cwd = function()
		--             local config = read_launch_json()
		--             return config and config.cwd or "${workspaceFolder}"
		--         end,
		--         stopAtEntry = function()
		--             local config = read_launch_json()
		--             return config and config.stopAtEntry or true
		--         end,
		--     },
		-- }
		-- dap.configurations.cpp = {
		-- {
		--     name = "Launch",
		--     type = "cppdbg",
		--     request = "launch",
		--     args = function()
		--         local config = read_launch_json()
		--         return config and config.args or {}
		--     end,
		--     program = function()
		--         local config = read_launch_json()
		--         return config and config.program or vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
		--     end,
		--     cwd = "${workspaceFolder}",
		--     stopAtEntry = true
		-- },
		-- }

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
		vim.keymap.set("n", "?", "<cmd>lua require('dapui').toggle()<cr>", { desc = "Toggle debugger" })
		vim.keymap.set("n", "<localleader>ss", ":DapContinue<cr>", { desc = "Start debugger" })
		vim.keymap.set("n", "<localleader>rr", ":DapRestartFrame<cr>", { desc = "Restart debugger" })
		vim.keymap.set("n", "<localleader>tt", ":DapTerminate<cr>", { desc = "Terminate debugger" })

		vim.keymap.set(
			"n",
			"<localleader>b",
			":DapToggleBreakpoint<cr>",
			{ desc = "Setting Breakingpoint to the current line" }
		)
		vim.keymap.set(
			"n",
			"<localeader>c",
			":DapContinue<cr>",
			{ desc = "Start debugger or Stepping through the code" }
		)
		vim.keymap.set("n", "<localleader>s", ":DapStepInto<cr>", { desc = "Stepping into the code" })
		vim.keymap.set("n", "<localleader>n", ":DapStepOver<cr>", { desc = "Stepping over the code" })

		vim.api.nvim_create_autocmd("VimEnter", {
			callback = ensure_launch_json,
		})
	end,
}
