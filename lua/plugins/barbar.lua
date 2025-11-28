return {
	"romgrk/barbar.nvim",
	dependencies = {
		"lewis6991/gitsigns.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	init = function()
		vim.g.barbar_auto_setup = false
	end,
	opts = {
		animation = true,
		auto_hide = false,
		tabpages = true,
		clickable = true,
		focus_on_close = "left",
		hide = { extensions = false, inactive = false },
		insert_at_end = true,
		insert_at_start = false,
		maximum_padding = 1,
		minimum_padding = 1,
		maximum_length = 30,
		minimum_length = 0,
		semantic_letters = true,
		sidebar_filetypes = {
			NvimTree = true,
		},
		letters = "asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP",
		no_name_title = "[No Name]",
		icons = {
			buffer_index = false,
			buffer_number = false,
			button = "",
			diagnostics = {
				[vim.diagnostic.severity.ERROR] = { enabled = false },
				[vim.diagnostic.severity.WARN] = { enabled = false },
				[vim.diagnostic.severity.INFO] = { enabled = false },
				[vim.diagnostic.severity.HINT] = { enabled = false },
			},
			gitsigns = {
				added = { enabled = false },
				changed = { enabled = false },
				deleted = { enabled = false },
			},
			filetype = {
				custom_colors = false,
				enabled = true,
			},
			separator = { left = "", right = "" },
			separator_at_end = true,
			modified = { button = "●" },
			pinned = { button = "", filename = true },
			preset = "default",
			alternate = { filetype = { enabled = false } },
			current = { buffer_index = false },
			inactive = { button = "✖" },
			visible = { modified = { buffer_number = false } },
		},
	},
	config = function(_, opts)
		require("barbar").setup(opts)

		-- Devicons 아이콘 전경색은 그대로 두고, 배경만 버퍼 상태색으로 칠하기
		local devicons = require("nvim-web-devicons")

		local function bubblegum_paint_devicon_bgs()
			local colors = {
				bg = "#303030",
				bg_alt = "#3a3a3a",
				bg_alt2 = "#444444",
				fg = "#b2b2b2",
				green = "#afd787",
				blue = "#87afd7",
				purple = "#d7afd7",
				red = "#d78787",
			}

			-- barbar가 쓰는 상태 → 배경색 매핑
			local status_bg = {
				Current = colors.green, -- 선택 탭
				Visible = colors.bg_alt2, -- 화면에 보이는 비선택 탭
				Inactive = colors.bg_alt, -- 비활성 탭
				Alternate = colors.bg_alt2, -- :h alternate-file
			}

			-- 개별 DevIcon 하이라이트에 상태별 bg 입히기
			local function tint_one(base_hl, fg)
				for suffix, bg in pairs(status_bg) do
					vim.api.nvim_set_hl(0, base_hl .. suffix, { fg = fg, bg = bg })
				end
			end

			-- 기본 아이콘도 처리
			local _, default_fg = devicons.get_icon_color("a.txt", "txt", { default = true })
			default_fg = default_fg or colors.fg
			tint_one("DevIconDefault", default_fg)

			-- 모든 아이콘에 대해 처리
			for _, ic in pairs(devicons.get_icons()) do
				if ic.name and ic.color then
					tint_one("DevIcon" .. ic.name, ic.color)
				end
			end
		end

		-- 첫 적용
		bubblegum_paint_devicon_bgs()

		-- 컬러스킴/배경(라이트·다크) 바뀔 때 재적용
		vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
			callback = bubblegum_paint_devicon_bgs,
		})
		vim.api.nvim_create_autocmd("OptionSet", {
			pattern = "background",
			callback = function()
				pcall(function()
					require("nvim-web-devicons").refresh()
				end)
				bubblegum_paint_devicon_bgs()
			end,
		})

		-- Bubblegum theme highlights
		local colors = {
			bg = "#303030",
			bg_alt = "#3a3a3a",
			bg_alt2 = "#444444",
			fg = "#b2b2b2",
			green = "#afd787",
			blue = "#87afd7",
			purple = "#d7afd7",
			red = "#d78787",
		}

		-- Current buffer (selected)
		vim.api.nvim_set_hl(0, "BufferCurrent", { fg = colors.bg, bg = colors.green, bold = true })
		vim.api.nvim_set_hl(0, "BufferCurrentIndex", { fg = colors.bg, bg = colors.green, bold = true })
		vim.api.nvim_set_hl(0, "BufferCurrentMod", { fg = colors.bg, bg = colors.green, bold = true })
		vim.api.nvim_set_hl(0, "BufferCurrentSign", { fg = colors.green, bg = colors.bg_alt })
		vim.api.nvim_set_hl(0, "BufferCurrentSignRight", { fg = colors.green, bg = colors.bg_alt })
		vim.api.nvim_set_hl(0, "BufferCurrentTarget", { fg = colors.red, bg = colors.green, bold = true })
		vim.api.nvim_set_hl(0, "BufferCurrentIcon", { bg = colors.green })

		-- Visible buffer (not selected but visible)
		vim.api.nvim_set_hl(0, "BufferVisible", { fg = colors.fg, bg = colors.bg_alt2 })
		vim.api.nvim_set_hl(0, "BufferVisibleIndex", { fg = colors.fg, bg = colors.bg_alt2 })
		vim.api.nvim_set_hl(0, "BufferVisibleMod", { fg = colors.red, bg = colors.bg_alt2 })
		vim.api.nvim_set_hl(0, "BufferVisibleSign", { fg = colors.bg_alt2, bg = colors.bg })
		vim.api.nvim_set_hl(0, "BufferVisibleSignRight", { fg = colors.bg_alt2, bg = colors.bg })
		vim.api.nvim_set_hl(0, "BufferVisibleTarget", { fg = colors.red, bg = colors.bg_alt2, bold = true })
		vim.api.nvim_set_hl(0, "BufferVisibleIcon", { bg = colors.bg_alt2 })

		-- Inactive buffer
		vim.api.nvim_set_hl(0, "BufferInactive", { fg = colors.fg, bg = colors.bg_alt })
		vim.api.nvim_set_hl(0, "BufferInactiveIndex", { fg = colors.fg, bg = colors.bg_alt })
		vim.api.nvim_set_hl(0, "BufferInactiveMod", { fg = colors.red, bg = colors.bg_alt })
		vim.api.nvim_set_hl(0, "BufferInactiveSign", { fg = colors.bg_alt, bg = colors.bg })
		vim.api.nvim_set_hl(0, "BufferInactiveSignRight", { fg = colors.bg_alt, bg = colors.bg })
		vim.api.nvim_set_hl(0, "BufferInactiveTarget", { fg = colors.red, bg = colors.bg_alt, bold = true })
		vim.api.nvim_set_hl(0, "BufferInactiveIcon", { fg = colors.purple, bg = colors.bg_alt })

		-- Tabline fill
		vim.api.nvim_set_hl(0, "BufferTabpageFill", { fg = colors.fg, bg = colors.bg })
		vim.api.nvim_set_hl(0, "BufferTabpages", { fg = colors.bg, bg = colors.green, bold = true })

		-- Offset (for nvim-tree)
		vim.api.nvim_set_hl(0, "BufferOffset", { fg = colors.fg, bg = colors.bg })
	end,
}
