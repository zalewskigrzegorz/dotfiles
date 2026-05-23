local settings = require("settings")
local colors = require("colors")

-- Padding item required because of bracket
sbar.add("item", {
    position = "right",
    width = settings.group_paddings
})

local cal = sbar.add("item", {
    icon = {
        color = colors.white,
        padding_left = 8,
        font = {
            family = settings.font.text, -- FiraCode Nerd Font Mono
            style = settings.font.style_map["Regular"],
            size = 16.0, -- match the visual weight of cpu/battery icons
        }
    },
    label = {
        color = colors.white,
        padding_right = 8,
        width = 96, -- wider than 80 so "05/23 02:23" doesn't truncate
        align = "right",
        font = {
            family = settings.font.numbers, -- FiraCode Nerd Font Mono (NOT sketchybar-app-font)
            style = settings.font.style_map["Regular"],
            size = 12.0, -- same scale as notif_preview label
        }
    },
    position = "right",
    update_freq = 30,
    padding_left = settings.group_paddings,
    padding_right = settings.group_paddings,
    background = {
        color = colors.bg1, -- solid base — was bg2 (surface grey) which made it drift
        height = 26, -- match bracketed widget group (settings.items.height)
        corner_radius = 6,
        border_color = colors.yellow, -- gold — semantic: time. Per-chip varied accent.
        border_width = 1
    }
})

-- Double border for calendar using a single item bracket
-- sbar.add("bracket", { cal.name }, {
--   background = {
--     color = colors.transparent,
--     height = 30,
--     border_color = colors.grey,
--   }
-- })

-- Padding item required because of bracket
sbar.add("item", {
    position = "right",
    width = settings.group_paddings
})

cal:subscribe({"forced", "routine", "system_woke"}, function(env)
    cal:set({
        icon = "",
        label = os.date("%m/%d %H:%M")
    })
end)
