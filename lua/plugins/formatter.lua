return {
	"stevearc/conform.nvim",
	opts = {
		notify_on_error = true,
		format_on_save = {
			timeout_ms = 5000,
			lsp_fallback = true,
		},
		formatters_by_ft = {
			bash = { "shfmt" },
			sh = { "shfmt" },
			lua = { "stylua" },
			python = { "black" },
			cpp = { "clang-format" },
			c = { "clang-format" },
			objc = { "clang-format" },
			objcpp = { "clang-format" },
		},
	},
}
