local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
--
-- IMPORTANT: We use os.execute with shell-backgrounding (&) instead of
-- sbar.exec. SbarLua sync exec hangs lua init when the command spawns a
-- long-running daemon (sketchybar v2.23.0 on macOS 26.4.1).
-- Symptom: lua process stuck in __wait4_nocancel, NO items ever register.
-- Workaround: use os.execute with `&` to detach properly.
os.execute("killall cpu_load >/dev/null 2>&1; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0 >/dev/null 2>&1 &")

local cpu = sbar.add("graph", "widgets.cpu", 42, {
    position = "right",
    graph = {
        color = colors.blue
    },
    background = {
        height = 22,
        color = {
            alpha = 0
        },
        border_color = {
            alpha = 0
        },
        drawing = true
    },
    icon = {
        string = icons.cpu
    },
    label = {
        string = "cpu ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0
        },
        align = "right",
        padding_right = 0,
        width = 0,
        y_offset = 4
    },
    padding_right = settings.paddings + 6
})

-- Red for 30 s in a row (15 samples at 2 s) makes the bracket border blink.
-- Only the cpu tick flips the blink, so two 2 s updates do not cancel each other.
local hot = { cpu = 0, mem = 0 }
local blink = false
local function heat(key, is_red)
    hot[key] = is_red and hot[key] + 1 or 0
end
local shown -- last border state sent, so a calm bar sends nothing
local function blink_tick()
    local alarm = hot.cpu >= 15 or hot.mem >= 15
    blink = alarm and not blink
    local state = (alarm and "a" or "") .. (blink and "b" or "")
    if state == shown then
        return
    end
    shown = state
    sbar.set("widgets.cpu.bracket", {
        background = {
            border_color = blink and colors.red or colors.rainbow[#colors.rainbow - 5],
            border_width = alarm and 2 or 1
        }
    })
end

cpu:subscribe("cpu_update", function(env)
    -- Also available: env.user_load, env.sys_load
    local load = tonumber(env.total_load)
    cpu:push({load / 100.})

    local color = colors.blue
    if load > 30 then
        if load < 60 then
            color = colors.yellow
        elseif load < 80 then
            color = colors.orange
        else
            color = colors.red
        end
    end

    cpu:set({
        graph = {
            color = color
        },
        label = "cpu " .. env.total_load .. "%"
    })
    heat("cpu", load >= 80)
    blink_tick()
end)

cpu:subscribe("mouse.clicked", function(env)
    sbar.exec("open -a 'Activity Monitor'")
end)

-- memory in use, as macOS counts it for memory pressure: kern.memorystatus_level is
-- the "free percentage" memory_pressure prints, read in one process
local mem = sbar.add("graph", "widgets.mem", 42, {
    position = "right",
    update_freq = 2,
    graph = { color = colors.blue },
    background = {
        height = 22,
        color = { alpha = 0 },
        border_color = { alpha = 0 },
        drawing = true
    },
    icon = { drawing = false },
    label = {
        string = "mem ??%",
        font = {
            family = settings.font.numbers,
            style = settings.font.style_map["Bold"],
            size = 9.0
        },
        align = "right",
        padding_right = 0,
        width = 0,
        y_offset = 4
    },
    padding_left = 6,
    padding_right = settings.paddings + 6
})

mem:subscribe({"routine", "forced", "system_woke"}, function()
    sbar.exec("sysctl -n kern.memorystatus_level", function(out)
        local free = tonumber(out)
        if not free then
            return
        end
        local used = 100 - free
        heat("mem", used >= 85)
        mem:push({used / 100.})
        mem:set({
            graph = { color = used >= 85 and colors.red or used >= 70 and colors.orange or colors.blue },
            label = string.format("mem %02d%%", used)
        })
    end)
end)

mem:subscribe("mouse.clicked", function()
    sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the cpu item
sbar.add("bracket", "widgets.cpu.bracket", {cpu.name, mem.name}, {
    background = {
        color = colors.bg1,
        border_color = colors.rainbow[#colors.rainbow - 5],
        border_width = 1
    }
})

-- Background around the cpu item
sbar.add("item", "widgets.cpu.padding", {
    position = "right",
    width = settings.group_paddings
})
