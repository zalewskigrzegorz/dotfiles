local settings = require("settings")

-- Laptop screen vs monitors. One sketchybar, one size per item, so spaces.lua builds two
-- workspace sets and this file pins them: item.N on the monitors, item.N.s (small) on the
-- laptop screen. With monitors attached the laptop bar also drops the wide widgets below,
-- so the right side fits between the notch and the screen edge.
-- When the laptop screen is the only one, widgets also drop their text (settings.compact).
-- shortcut: re-pinned on display_change (active display) and wake only, sketchybar has no
-- monitor-plugged event; after a plug that keeps focus put, any focus change fixes it.
local compact_below = 1800
local wide = {
    "widgets.cpu", "widgets.mem", "widgets.cpu.bracket", "widgets.cpu.padding",
    "widgets.wifi1", "widgets.wifi2", "widgets.wifi.padding", "widgets.wifi.proxy", "widgets.wifi.bracket"
}

local watcher = sbar.add("item", "compact.watcher", { drawing = false, updates = true })

-- display takes a comma list of arrangement ids; an empty list hides the item
local function pin(name, ids)
    if #ids == 0 then
        sbar.set(name, { drawing = false })
    else
        sbar.set(name, { drawing = true, display = table.concat(ids, ",") })
    end
end

local function apply(laptop_ids, big_ids)
    local compact = #big_ids == 0
    local mixed = #laptop_ids > 0 and not compact
    -- battery and calendar read this on their next update. --update fires "forced",
    -- which re-runs check(), so it must only run on a real change or it loops forever.
    if settings.compact ~= compact then
        settings.compact = compact
        sbar.exec("sketchybar --update")
    end
    for i = 1, 10 do
        pin("item." .. i, big_ids)
        pin("item." .. i .. "padding", big_ids)
        pin("item." .. i .. ".s", laptop_ids)
        pin("item." .. i .. ".spadding", laptop_ids)
    end
    pin("workspace.dell_ultra_sep", big_ids)
    pin("workspace.ultra_mac_sep", big_ids)
    for _, name in ipairs(wide) do
        sbar.set(name, { display = mixed and table.concat(big_ids, ",") or "all" })
    end
    -- no room for the app title next to the notch
    sbar.set("front_app", { drawing = not compact, display = mixed and table.concat(big_ids, ",") or "active" })
    -- only the label: volume1/mic1 run the scripts that update the icons, and
    -- updates = "when_shown" would stop them if the whole item were hidden
    sbar.set("widgets.volume1", { label = { drawing = not compact } })
    sbar.set("widgets.mic1", { label = { drawing = not compact } })
    -- spacer items between groups; 5 is the default.lua padding
    local pad = compact and 2 or 5
    sbar.exec("sketchybar --set '/.*padding/' padding_left=" .. pad .. " padding_right=" .. pad)
end

local function check()
    sbar.exec("sketchybar --query displays", function(displays)
        local laptop_ids, big_ids = {}, {}
        if type(displays) == "table" then
            for _, d in ipairs(displays) do
                if d.frame then
                    table.insert(d.frame.w < compact_below and laptop_ids or big_ids, d["arrangement-id"])
                end
            end
        end
        -- a failed query would hide every workspace; keep the last layout instead
        if #laptop_ids + #big_ids == 0 then return end
        apply(laptop_ids, big_ids)
    end)
end

watcher:subscribe({ "forced", "display_change", "system_woke" }, check)
check()
