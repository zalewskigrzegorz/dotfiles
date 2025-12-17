local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- State tracking
local current_state = {
	service_mode = false,
	vim_mode = "",
	vim_active = false,
}

-- Vim mode configuration using SF Symbols
local vim_modes = {
	["N"] = {
		icon = "N",
		color = colors.purple,
	},
	["I"] = {
		icon = "I",
		color = colors.green,
	},
	["V"] = {
		icon = "V",
		color = colors.magenta,
	},
	["C"] = {
		icon = "C", -- Command
		color = colors.red,
	},
	["R"] = {
		icon = "R", -- replece
		color = colors.yellow,
	},
	["_"] = {
		icon = "􀈑", -- other
		color = colors.grey,
	},
}

local apple = sbar.add("item", {
	icon = {
		font = {
			size = 22.0,
		},
		string = settings.modes.main.icon,
		padding_right = 8,
		padding_left = 8,
		highlight_color = settings.modes.service.color,
	},
	label = {
		drawing = false,
	},
	background = {
		color = settings.items.colors.background,
		border_color = settings.modes.main.color,
		border_width = 1,
	},
	padding_left = 1,
	padding_right = 1,
	click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0",
})

-- Function to update the apple icon based on current state
local function update_apple_icon()
	if current_state.service_mode then
		-- Service mode has highest priority
		sbar.animate("tanh", 10, function()
			apple:set({
				background = {
					border_color = settings.modes.service.color,
					border_width = 3,
				},
				icon = {
					highlight = true,
					string = settings.modes.service.icon,
					color = settings.modes.service.color,
				},
			})
		end)
	elseif current_state.vim_active and current_state.vim_mode ~= "" then
		-- Vim mode is active
		-- Note: kindaVim works globally and "insert" is its default mode
		-- If you want to hide "I" (insert) mode, uncomment the condition below
		-- if current_state.vim_mode == "I" then
		--     -- Insert is default, show unicorn instead (fall through to else)
		-- else
		local vim_config = vim_modes[current_state.vim_mode]
		if vim_config then
			sbar.animate("tanh", 10, function()
				apple:set({
					background = {
						border_color = vim_config.color,
						border_width = 2,
					},
					icon = {
						highlight = false,
						string = vim_config.icon,
						color = vim_config.color,
					},
				})
			end)
		end
		-- end (for hiding insert mode)
	else
		-- Default unicorn mode
		sbar.animate("tanh", 10, function()
			apple:set({
				background = {
					border_color = settings.modes.main.color,
					border_width = 1,
				},
				icon = {
					highlight = false,
					string = settings.modes.main.icon,
					color = settings.modes.main.color,
				},
			})
		end)
	end
end

-- Service mode events
apple:subscribe("aerospace_enter_service_mode", function(_)
	current_state.service_mode = true
	update_apple_icon()
end)

apple:subscribe("aerospace_leave_service_mode", function(_)
	current_state.service_mode = false
	update_apple_icon()
end)

-- Vim mode events - svim (DISABLED - using kindaVim permanently)
-- apple:subscribe("svim_update", function(env)
-- 	local mode = env.MODE or ""
--
-- 	if mode == "" then
-- 		current_state.vim_active = false
-- 		current_state.vim_mode = ""
-- 	else
-- 		current_state.vim_active = true
-- 		current_state.vim_mode = mode
-- 	end
--
-- 	update_apple_icon()
-- end)

-- Vim mode events - kindaVim (ACTIVE)
-- Note: kindaVim only exposes persistent modes (N, I, V) via environment.json
-- Transient modes (C, R) are not available and cannot be displayed
apple:subscribe("kindavim_update", function(env)
	local mode = env.MODE or ""

	if mode == "" then
		current_state.vim_active = false
		current_state.vim_mode = ""
	else
		current_state.vim_active = true
		current_state.vim_mode = mode
	end

	update_apple_icon()
end)

-- Handle app switching - kindaVim works globally so we don't clear on app switch
-- Only clear when kindaVim process stops (handled by watcher)
apple:subscribe("front_app_switched", function(env)
	-- kindaVim works globally, so we keep its mode visible even when switching apps
	-- The watcher will clear the mode if kindaVim process stops
	
	-- OLD LOGIC (svim disabled):
	-- Terminal apps used svim, but now we only use kindaVim globally
	-- local vim_apps = {
	-- 	["iTerm"] = true,
	-- 	["Terminal"] = true,
	-- 	["Ghostty"] = true,
	-- }
end)

-- Padding to the right of the main button
sbar.add("item", {
	width = 7,
})
