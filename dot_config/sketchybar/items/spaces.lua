local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- Workspace labels and highlight state are updated by sketchybar-watcher via --set (no Lua logic)

local workspace_order = {
    "chat", "term", "code", "notes", "web",
    "test", "mail", "media", "misc", "mac"
}

local workspace_icons = {
    ["chat"] = "󰭻", ["web"] = "󰖟", ["term"] = "󰆍", ["code"] = "", ["media"] = "󰝚",
    ["test"] = "󰙨", ["misc"] = "󰉋", ["notes"] = "󰂺", ["mail"] = "󰇮", ["mac"] = "󰍹"
}

local workspace_colors = {
    ["chat"] = colors.bright_green, ["web"] = colors.blue, ["term"] = colors.orange,
    ["code"] = colors.magenta, ["media"] = colors.bright_red, ["test"] = colors.yellow,
    ["misc"] = colors.grey, ["notes"] = colors.green, ["mail"] = colors.red, ["mac"] = colors.white
}

-- Initial highlight only; the watcher re-pushes it as soon as it hears from bin/hyprmac-bar-bridge.
local f = io.open("/tmp/hyprmac-bar/focused")
local current_workspace = f and f:read("*l") or nil
if f then f:close() end
local focused_color = colors.purple

-- Two sets: item.N (full size, monitors) and item.N.s (small, laptop screen).
-- items/compact.lua decides which display each set draws on; the watcher updates both.
local full = settings.items.space
local small = { icon_padding = 6, label_padding = 8, icon_size = 13.0, label_size = 12.0 }

local function add_workspace(i, workspace, suffix, size)
    local selected = workspace == current_workspace
    local workspace_color = workspace_colors[workspace] or colors.grey

    local space = sbar.add("item", "item." .. i .. suffix, {
        icon = {
            font = { family = "JetBrainsMono Nerd Font", size = size.icon_size },
            string = workspace_icons[workspace] or workspace,
            padding_left = size.icon_padding,
            padding_right = 6,
            color = selected and focused_color or workspace_color,
            highlight_color = focused_color,
            highlight = selected
        },
        label = {
            padding_right = size.label_padding,
            color = selected and focused_color or workspace_color,
            highlight_color = focused_color,
            font = { family = "sketchybar-app-font", style = "Regular", size = size.label_size },
            y_offset = -1,
            highlight = selected
        },
        padding_right = 1,
        padding_left = 1,
        background = {
            color = settings.items.colors.background,
            border_width = 1,
            height = settings.items.height,
            border_color = selected and focused_color or workspace_color
        },
        popup = {
            background = { border_width = 5, border_color = colors.black }
        }
    })

    sbar.add("item", "item." .. i .. suffix .. "padding", { script = "", width = settings.items.gap })

    if i == 5 and suffix == "" then
        sbar.add("item", "workspace.dell_ultra_sep", {
            label = {
                string = "│",
                font = { family = settings.font.text, size = 14.0 },
                color = colors.dark_grey,
                padding_left = 4,
                padding_right = 4
            },
            icon = { drawing = false },
            background = { drawing = false },
            padding_left = 2,
            padding_right = 2
        })
    end

    local space_popup = sbar.add("item", {
        position = "popup." .. space.name,
        padding_left = 5,
        padding_right = 0,
        background = {
            drawing = true,
            image = { corner_radius = 9, scale = 0.2 }
        }
    })

    -- Left click switched workspaces through aerospace; HyprMac cannot be driven from
    -- outside yet (zacharytgray/HyprMac#44), so only the middle-click preview is left.
    space:subscribe("mouse.clicked", function(env)
        if env.BUTTON == "other" then
            space_popup:set({ background = { image = space.name } })
            space:set({ popup = { drawing = "toggle" } })
        end
    end)

    space:subscribe("mouse.exited", function(_)
        space:set({ popup = { drawing = false } })
    end)
end

for i, workspace in ipairs(workspace_order) do
    add_workspace(i, workspace, "", full)
end
for i, workspace in ipairs(workspace_order) do
    add_workspace(i, workspace, ".s", small)
end
