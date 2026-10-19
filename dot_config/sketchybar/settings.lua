local colors = require("colors")
local icons = require("icons")
local app_icon_size = 16.0

return {
    paddings = 3,
    compact = false, -- set by items/compact.lua when the laptop screen is on

    group_paddings = 5,
    modes = {
        main = {
            icon = icons.unicorn,
            color = colors.purple
        },
        service = {
            icon = icons.nuke,
            color = colors.red
        }
    },
    bar = {
        height = 36,
        padding = {
            x = 10,
            y = 0
        },
        background = colors.bar.bg
    },
    items = {
        height = 26,
        gap = 5,
        padding = {
            right = 16,
            left = 12,
            top = 0,
            bottom = 0
        },
        default_color = function(workspace)
            return colors.rainbow[workspace + 1]
        end,
        highlight_color = function(workspace)
            return colors.yellow
        end,
        colors = {
            background = colors.bg1
        },
        corner_radius = 6,
        -- workspace items; items/compact.lua shrinks them on the laptop and restores these
        space = { icon_padding = 12, label_padding = 16, icon_size = 16.0, label_size = app_icon_size }
    },

    icons = "sketchybar-app-font:Regular:" .. string.format("%.1f", app_icon_size), -- alternatively available: NerdFont

    font = {
        text = "JetBrainsMono Nerd Font", -- Used for text
        numbers = "JetBrainsMono Nerd Font", -- Used for numbers
        style_map = {
            ["Regular"] = "Regular",
            ["Semibold"] = "Medium",
            ["Bold"] = "SemiBold",
            ["Heavy"] = "Bold",
            ["Black"] = "ExtraBold"
        }
    }
}
