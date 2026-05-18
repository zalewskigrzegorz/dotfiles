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
-- Fixed width keeps the bar from jumping when previews appear/disappear and
-- forces scroll_texts to kick in on longer messages instead of dynamically
-- resizing the item. 500px fits comfortably on built-in retina, the dell, and
-- the ultrawide; adjust here if you change monitor setup.
local notif = sbar.add("item", "notif_preview", {
    position = "right",
    drawing = false,
    width = 500,
    scroll_texts = true,
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
        max_chars = 130,
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
        color = colors.bg2,
        height = 22,
        corner_radius = 6,
        border_color = colors.grey,
        border_width = 1,
    },
    padding_right = settings.paddings,
})

notif:subscribe("mouse.clicked", function()
    notif:set({ drawing = false, icon = "", label = "" })
end)
