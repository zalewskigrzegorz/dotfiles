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

-- No initial highlight: the watcher pushes it on sketchybar_ready from HyprMac's state.json.
local current_workspace = nil
local focused_color = colors.purple

-- HyprMac workspace number behind each name (bin/hyprmac-config keeps the same map).
local hyprmac_ws = { chat = 1, term = 4, code = 7, notes = 10, web = 2, test = 5, mail = 8, media = 3, misc = 6, mac = 9 }
-- The fork's debug build answers hyprmac:// while its PRs wait upstream; with -b the release
-- app, which also claims the scheme, is never launched by a click.
local hyprmac_bundle = "com.zachgray.HyprMac.debug"

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

    -- monitor boundaries in the HyprMac key order: Dell 1-4 | Samsung 5-7 | laptop 8-0
    local sep = ({ [4] = "workspace.dell_ultra_sep", [7] = "workspace.ultra_mac_sep" })[i]
    if sep and suffix == "" then
        sbar.add("item", sep, {
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

    -- Left click: switch to the workspace and focus a window there; clicking again cycles them.
    space:subscribe("mouse.clicked", function(env)
        if env.BUTTON == "other" then
            space_popup:set({ background = { image = space.name } })
            space:set({ popup = { drawing = "toggle" } })
        elseif hyprmac_ws[workspace] then
            sbar.exec(string.format('open -g -b %s "hyprmac://focus?workspace=%d"', hyprmac_bundle, hyprmac_ws[workspace]))
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
