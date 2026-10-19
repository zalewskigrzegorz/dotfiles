-- Laptop layout: on the built-in screen alone, widgets drop their text and the
-- front app moves right of the notch ("e"), so nothing sits under the notch.
-- shortcut: decides per bar, not per display; with the lid open next to a monitor
-- the full layout stays on, add per-display items if that combo gets used.
local compact_below = 1800

local watcher = sbar.add("item", "compact.watcher", { drawing = false, updates = true })

local function apply(compact)
    local show = not compact
    sbar.set("front_app", { position = compact and "e" or "left" })
    sbar.set("widgets.wifi1", { drawing = show })
    sbar.set("widgets.wifi2", { drawing = show })
    sbar.set("widgets.volume1", { drawing = show })
    sbar.set("widgets.mic1", { drawing = show })
    sbar.set("widgets.battery", { label = { drawing = show } })
    sbar.set("workspace.dell_ultra_sep", { drawing = show })
    -- 10 workspaces have to fit left of the notch (~650 pt)
    for i = 1, 10 do
        sbar.set("item." .. i, {
            icon = { padding_left = compact and 4 or 8 },
            label = { padding_right = compact and 6 or 12 }
        })
    end
end

local function check()
    sbar.exec("sketchybar --query displays", function(displays)
        local compact = type(displays) == "table" and #displays == 1
            and displays[1].frame and displays[1].frame.w < compact_below
        apply(compact)
    end)
end

watcher:subscribe({ "forced", "display_change", "system_woke" }, check)
check()
