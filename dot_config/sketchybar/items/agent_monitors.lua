local colors = require("colors")
local settings = require("settings")

-- Idle agents waiting on a background Monitor (deploy, CI):
-- `5 ◔ Prod: Platform security apply ✓ · Deploy BH Prod attempt 3`. Hidden when none.
-- PUSH-driven by bin/agent-monitors (launchd, every 15 s), which `--set`s this
-- item. A hidden item gets no events, so there is nothing to subscribe to.
sbar.add("item", "agent_monitors", {
    position = "right",
    drawing = false,
    padding_left = settings.group_paddings,
    padding_right = settings.group_paddings,
    icon = { drawing = false },
    label = {
        color = colors.yellow,
        padding_left = 8,
        padding_right = 8,
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = 13.0
        }
    },
    background = {
        color = colors.bg1,
        height = 26,
        corner_radius = 6,
        border_color = colors.yellow,
        border_width = 1
    }
})
