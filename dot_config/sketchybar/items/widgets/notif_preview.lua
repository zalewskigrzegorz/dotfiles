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

-- Popup is N stacked rows because sketchybar labels are single-line. Watcher
-- splits the body into ~60-char chunks (word-aware) and writes them into
-- line1..lineN; unused rows get blanked so the popup shrinks to fit.
local popup_lines = 4
local popup_chars_per_line = 60
for i = 1, popup_lines do
    sbar.add("item", "notif_preview.popup.line" .. i, {
        position = "popup." .. notif.name,
        icon = { drawing = false },
        label = {
            string = "",
            max_chars = popup_chars_per_line + 4,
            font = {
                family = settings.font.text,
                style = settings.font.style_map["Regular"],
                size = 13.0,
            },
            color = colors.white,
            padding_left = 12,
            padding_right = 12,
            align = "left",
        },
    })
end

notif:subscribe("mouse.clicked", function()
    notif:set({ drawing = false, icon = "", label = "", popup = { drawing = false } })
end)

notif:subscribe("mouse.entered", function()
    notif:set({ popup = { drawing = true } })
end)

notif:subscribe("mouse.exited", function()
    notif:set({ popup = { drawing = false } })
end)
