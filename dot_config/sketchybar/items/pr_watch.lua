local colors = require("colors")
local settings = require("settings")

-- Actionable-PR chip:  <fix N>  <merge N>  <new-comment N>. Hidden when no PR of
-- mine needs action. PUSH-driven by bin/pr-watch (launchd, every 3 min) — no
-- timer here. border_color is set per-poll by pr-watch
-- (red=needs fix, gold=new comment, green=ready to merge).
-- Click (bin/pr-watch-open): LEFT → popup listing my open PRs from the
-- pr-watch cache (row click opens the PR in the browser); RIGHT → gh-dash
-- in a herdr workspace.
sbar.add("item", "pr_watch", {
    position = "right",
    drawing = false,
    padding_left = settings.group_paddings,
    padding_right = settings.group_paddings,
    icon = { drawing = false },
    label = {
        color = colors.green,
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
        border_color = colors.green,
        border_width = 1
    },
    popup = {
        align = "right",
        background = {
            color = colors.bg1,
            border_color = colors.grey,
            border_width = 1,
            corner_radius = 6
        }
    },
    click_script = os.getenv("HOME") .. "/Code/dotfiles/bin/pr-watch-open"
})
