local settings = require("settings")

-- Laptop layout: when the built-in screen is the only one, widgets drop their text and
-- the front app title is dropped, so nothing sits under the notch.
-- shortcut: decides per bar, not per display, so with the lid open next to a monitor
-- the laptop gets the full layout and some items hide under the notch; add per-display
-- items if that bothers.
local compact_below = 1800
local space = settings.items.space

local watcher = sbar.add("item", "compact.watcher", { drawing = false, updates = true })

local function apply(compact)
    local show = not compact
    -- battery and calendar read this on their next update. --update fires "forced",
    -- which re-runs check(), so it must only run on a real change or it loops forever.
    if settings.compact ~= compact then
        settings.compact = compact
        sbar.exec("sketchybar --update")
    end
    -- no room for the app title next to the notch
    sbar.set("front_app", { drawing = show, display = "active" })
    -- only the label: volume1/mic1 run the scripts that update the icons, and
    -- updates = "when_shown" would stop them if the whole item were hidden
    sbar.set("widgets.volume1", { label = { drawing = show } })
    sbar.set("widgets.mic1", { label = { drawing = show } })
    sbar.set("workspace.dell_ultra_sep", { drawing = show })
    -- 10 workspaces have to fit left of the notch (~650 pt)
    for i = 1, 10 do
        sbar.set("item." .. i, {
            icon = {
                padding_left = compact and 6 or space.icon_padding,
                font = { size = compact and 13.0 or space.icon_size }
            },
            label = {
                padding_right = compact and 8 or space.label_padding,
                font = { size = compact and 12.0 or space.label_size }
            }
        })
    end
    -- spacer items between groups; 5 is the default.lua padding
    local pad = compact and 2 or 5
    sbar.exec("sketchybar --set '/.*padding/' padding_left=" .. pad .. " padding_right=" .. pad)
end

local function check()
    sbar.exec("sketchybar --query displays", function(displays)
        local small, big = false, false
        if type(displays) == "table" then
            for _, d in ipairs(displays) do
                if d.frame and d.frame.w < compact_below then
                    small = true
                elseif d.frame then
                    big = true
                end
            end
        end
        apply(small and not big)
    end)
end

watcher:subscribe({ "forced", "display_change", "system_woke" }, check)
check()
