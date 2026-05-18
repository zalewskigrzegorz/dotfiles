local colors = require("colors")
local settings = require("settings")

-- notif_preview is driven by sketchybar-watcher (notif_preview.go).
-- The watcher polls the NotificationCenter sqlite DB every 3s and pushes the
-- newest notification's icon (sketchybar-app-font glyph) + body text into this
-- item. Clicking clears it locally; the watcher will re-push if a newer notif
-- arrives within the next poll.
--
-- The icon and label use DIFFERENT fonts on purpose:
--   icon  -> sketchybar-app-font   (renders :slack:, :default:, etc.)
--   label -> FiraCode Nerd Font Mono (renders real readable text)
-- Compact bar item shows app icon + truncated body. On hover, sketchybar's
-- native popup opens with the full body — same pattern as wifi/battery —
-- so we never burn render cycles scrolling text on the bar itself.
local notif = sbar.add("item", "notif_preview", {
    position = "right",
    drawing = false,
    width = "dynamic",
    icon = {
        drawing = true,
        font = settings.icons, -- sketchybar-app-font:Regular:16.0
        string = "",
        color = colors.white,
        padding_left = 6,
        padding_right = 4,
    },
    label = {
        string = "",
        font = {
            family = settings.font.text, -- FiraCode Nerd Font Mono
            style = settings.font.style_map["Regular"],
            size = 12.0,
        },
        color = colors.white,
        padding_left = 0,
        padding_right = 8,
    },
    background = {
        color = colors.bg1,
        height = 22,
        corner_radius = 6,
        border_color = colors.bg1,
        border_width = 0,
    },
    padding_right = settings.paddings,
    popup = {
        align = "center",
    },
})

-- Single popup row carrying the full (untruncated) body text. Watcher pushes
-- both the compact label on `notif_preview` AND this row's label on every
-- notification.
sbar.add("item", "notif_preview.popup.body", {
    position = "popup." .. notif.name,
    icon = { drawing = false },
    label = {
        string = "",
        max_chars = 240,
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Regular"],
            size = 13.0,
        },
        color = colors.white,
        padding_left = 12,
        padding_right = 12,
    },
})

notif:subscribe("mouse.clicked", function()
    notif:set({ drawing = false, icon = "", label = "", popup = { drawing = false } })
end)

notif:subscribe("mouse.entered", function()
    notif:set({ popup = { drawing = true } })
end)

notif:subscribe("mouse.exited", function()
    notif:set({ popup = { drawing = false } })
end)
