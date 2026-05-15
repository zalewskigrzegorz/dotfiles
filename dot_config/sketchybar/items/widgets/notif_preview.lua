local colors = require("colors")
local settings = require("settings")

-- notif_preview is driven by sketchybar-watcher (notif_preview.go).
-- The watcher polls the NotificationCenter sqlite DB every 3s and pushes the
-- newest notification's icon + truncated body into this item's label.
-- Clicking the item clears it locally (the watcher will re-push if there's a
-- newer notification within the next poll).
local notif = sbar.add("item", "notif_preview", {
    position = "right",
    drawing = false,
    icon = {
        drawing = false,
    },
    label = {
        string = "",
        max_chars = 80,
        font = settings.icons,
        color = colors.white,
        padding_left = 8,
        padding_right = 8,
    },
    background = {
        color = colors.bg2,
        height = 22,
        corner_radius = 6,
        border_color = colors.grey,
        border_width = 1,
    },
    padding_right = settings.paddings,
})

notif:subscribe("mouse.clicked", function()
    notif:set({ drawing = false, label = "" })
end)
