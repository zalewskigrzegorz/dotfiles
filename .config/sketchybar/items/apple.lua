local settings = require("settings")

-- Apple item: state (service/kindaVim/default) is set by sketchybar-watcher via --set
local apple = sbar.add("item", "apple", {
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

-- Padding to the right of the main button
sbar.add("item", {
	width = 7,
})
