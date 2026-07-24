local colors = require("colors")
local settings = require("settings")

-- Caffeine Manager (~/.local/state/caffeine-manager) writes a status file and
-- ships its own plugin script; the script sets icon (☕/☾) + label itself.
local plugin = os.getenv("HOME") .. "/.local/state/caffeine-manager/sketchybar/caffeine.sh"

local caffeine = sbar.add("item", "widgets.caffeine", {
    position = "right",
    update_freq = 5,
    icon = {
        font = "SF Pro:Semibold:14.0"
    },
    label = {
        font = {
            family = settings.font.numbers
        }
    }
})

caffeine:subscribe({"routine", "forced", "system_woke"}, function()
    sbar.exec("NAME=" .. caffeine.name .. " " .. plugin)
end)

caffeine:subscribe("mouse.clicked", function()
    sbar.exec("open -a 'Caffeine Manager'")
end)

sbar.add("bracket", "widgets.caffeine.bracket", {caffeine.name}, {
    background = {
        color = colors.bg1,
        border_color = colors.rainbow[#colors.rainbow - 1],
        border_width = 1
    }
})

sbar.add("item", "widgets.caffeine.padding", {
    position = "right",
    width = settings.group_paddings
})
