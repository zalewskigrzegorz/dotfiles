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
-- The item auto-sizes (width=dynamic) to fit truncated text. Body truncation
-- length is per-display, set by sketchybar-watcher on every push (see
-- notif_preview.go::notifPreviewCharsByDisplay). Dark background matches cpu
-- widget; no border for a calmer look.
local notif = sbar.add("item", "notif_preview", {
    position = "right",
    drawing = false,
    width = "dynamic",
    scroll_texts = false,
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
})

notif:subscribe("mouse.clicked", function()
    notif:set({ drawing = false, icon = "", label = "" })
end)
