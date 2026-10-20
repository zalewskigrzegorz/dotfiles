local colors = require("colors")
local settings = require("settings")

-- Actionable-PR chip:  <fix N>  <merge N>  <new-comment N>. Hidden when no PR of
-- mine needs action. PUSH-driven by bin/pr-watch (launchd, every 3 min) — no
-- timer here. border_color is set per-poll by pr-watch
-- (red=needs fix, gold=new comment, green=ready to merge).
-- Click (bin/pr-watch-open): LEFT → popup listing my open PRs from the
-- pr-watch cache (row click opens the PR in the browser); RIGHT → gh-dash
-- in a herdr workspace.
local pr_watch = sbar.add("item", "pr_watch", {
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

-- the item starts hidden; poll now instead of waiting up to 3 min for launchd
local repoll = "launchctl kickstart gui/$(id -u)/com.greg.pr-watch"
sbar.exec(repoll)

-- Blink while ~/.cache/pr-watch-alerts.json holds unseen events (bin/pr-watch
-- writes it, opening the popup clears it). Color = most important kind.
local alerts_path = os.getenv("HOME") .. "/.cache/pr-watch-alerts.json"
local kind_order = { "ci_fail", "approval", "comment", "ci_start" }
local kind_colors = {
    ci_fail = 0xffff6b9d,
    approval = 0xff50fa7b,
    comment = 0xff8be9fd,
    ci_start = 0xffffd700
}
local alert_color, lit = nil, false

local function top_kind()
    local f = io.open(alerts_path)
    if not f then return nil end
    local s = f:read("a")
    f:close()
    for _, k in ipairs(kind_order) do
        if s:find('"kind":%s*"' .. k .. '"') then return k end
    end
end

sbar.add("event", "pr_watch_alert")
local function on_alert()
    local kind = top_kind()
    local was = alert_color
    alert_color = kind and kind_colors[kind] or nil
    if alert_color then
        pr_watch:set({ drawing = true, update_freq = 1 })
    elseif was then
        pr_watch:set({ update_freq = 0, background = { border_width = 1 } })
        sbar.exec(repoll) -- pr-watch puts its own border color back
    end
end
pr_watch:subscribe("pr_watch_alert", on_alert)
pr_watch:subscribe("routine", function()
    if not alert_color then return end
    lit = not lit
    pr_watch:set({
        background = { border_color = lit and alert_color or colors.bg1, border_width = 2 },
        label = { color = lit and alert_color or colors.grey }
    })
end)
on_alert() -- a trigger sent during config load is lost
