return {
	"mason-org/mason-lspconfig.nvim",
	opts = {},
	dependencies = {
		"mason-org/mason.nvim",
		"neovim/nvim-lspconfig",
	},
	config = function()
		require("mason").setup()

		require("mason-lspconfig").setup({
			ensure_installed = { "clangd", "lua_ls", "pylsp", "jedi_language_server", "bashls" }, -- 원하는 서버 나열
			automatic_installation = true, -- old automatic_enable 대체
		})

		require("mason-lspconfig").setup_handlers({
			function(server_name)
				local capabilities = _G.lsp_capabilities or {}
				vim.lsp.config(server_name, {
					capabilities = capabilities,
				})
			end,
			["clangd"] = function()
				local capabilities = _G.lsp_capabilities or {}
				vim.lsp.enable("clangd")
				vim.lsp.config("clangd", {
					capabilities = capabilities,
					cmd = {
						"clangd",
						"--background-index",
						"--clang-tidy",
						"--header-insertion=iwyu",
						"--completion-style=detailed",
						"--function-arg-placeholders",
						"--fallback-style=llvm",
					},
					init_options = {
						usePlaceholders = true,
						completeUnimported = true,
						clangdFileStatus = true,
					},
				})
			end,
			["lua_ls"] = function()
				local capabilities = _G.lsp_capabilities or {}
				vim.lsp.enable("lua_ls")
				vim.lsp.config("lua_ls", {
					capabilities = capabilities,
					settings = {
						Lua = {
							runtime = {
								version = "LuaJIT",
							},
							diagnostics = {
								globals = { "vim" },
							},
							workspace = {
								library = vim.api.nvim_get_runtime_file("", true),
							},
							telemetry = {
								enable = false,
							},
						},
					},
				})
			end,
			["pylsp"] = function()
				local capabilities = _G.lsp_capabilities or {}
				vim.lsp.enable("pylsp")
				vim.lsp.config("pylsp", {
					capabilities = capabilities,
					settings = {
						pylsp = {
							plugins = {
								jedi_completion = {
									include_params = true,
								},
								pycodestyle = {
									enabled = true,
									ignore = { "E501", "W291", "W391", "W503" },
									maxLineLength = 100,
								},
								pyflakes = {
									enabled = false,
								},
							},
						},
					},
				})
			end,
			["jedi_language_server"] = function()
				vim.lsp.enable("jedi_language_server")
				local capabilities = _G.lsp_capabilities or {}
				vim.lsp.config("jedi_language_server", {
					capabilities = capabilities,
				})
			end,
		})

		local sign = function(opts)
			vim.fn.sign_define(opts.name, {
				texthl = opts.name,
				text = opts.text,
				numhl = "",
			})
		end

		sign({ name = "DiagnosticSignError", text = "✘" })
		sign({ name = "DiagnosticSignWarn", text = "▲" })
		sign({ name = "DiagnosticSignHint", text = "⚑" })
		sign({ name = "DiagnosticSignInfo", text = "" })

		vim.diagnostic.config({
			virtual_text = false,
			severity_sort = true,
			float = {
				border = "rounded",
				source = "always",
			},
		})

		vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })

		vim.lsp.handlers["textDocument/signatureHelp"] =
			vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })
	end,
}
