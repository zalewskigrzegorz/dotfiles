local colors = require("colors")
local settings = require("settings")

-- Idle agents waiting on a background Monitor (deploy, CI):
-- chip `5 ◔ ✓4` (agent, steps done), click for the detail popup. Hidden when none.
-- PUSH-driven by bin/agent-monitors (launchd, every 15 s), which `--set`s this
-- item. A hidden item gets no events, so there is nothing to subscribe to.
local chip = sbar.add("item", "agent_monitors", {
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
    },
    popup = {
        align = "right",
        background = { color = colors.bg1, border_color = colors.grey, border_width = 1, corner_radius = 6 }
    }
})
chip:subscribe("mouse.clicked", function() chip:set({ popup = { drawing = "toggle" } }) end)

-- detail rows, filled by bin/agent-monitors; the chip click toggles the popup
for i = 0, 3 do
    sbar.add("item", "agent_monitors.row" .. i, {
        position = "popup.agent_monitors",
        drawing = false,
        icon = { drawing = false },
        label = { color = colors.white, font = { family = settings.font.text, size = 12.0 } }
    })
end
