local colors = require("colors")
local settings = require("settings")

-- Idle agents waiting on a background Monitor (deploy, CI): `5 ◔ platform apply ok`.
-- Hidden when none. PUSH-driven by bin/agent-monitors (launchd, every 15 s),
-- which writes ~/.cache/agent-monitors.json and `--set`s this item (a hidden item gets no events).
local path = os.getenv("HOME") .. "/.cache/agent-monitors.json"

local item = sbar.add("item", "agent_monitors", {
    position = "right",
    drawing = false,
    padding_left = settings.group_paddings,
    padding_right = settings.group_paddings,
    icon = { drawing = false },
    label = {
        color = colors.yellow,
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
        border_color = colors.yellow,
        border_width = 1
    }
})

local function refresh()
    local f = io.open(path)
    local s = f and f:read("a") or "[]"
    if f then f:close() end
    local parts = {}
    for ws, ev in s:gmatch('"ws":"(.-)".-"event":"(.-)"') do
        local short = ev:match("^(.-):") or ev
        parts[#parts + 1] = ws .. " ◔" .. (short ~= "" and (" " .. short:sub(1, 28)) or "")
    end
    if #parts == 0 then
        item:set({ drawing = false })
    else
        item:set({ drawing = true, label = { string = table.concat(parts, "  ") } })
    end
end

refresh() -- show the last known state right after a reload
