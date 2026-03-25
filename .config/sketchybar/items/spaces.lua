local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- Workspace labels and highlight state are updated by sketchybar-watcher via --set (no Lua logic)

local workspace_order = {
    "chat", "term", "code", "misc", "notes",
    "web", "media", "test", "mail", "mac"
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

local current_workspace = get_current_workspace()
local focused_color = colors.purple

for i, workspace in ipairs(workspace_order) do
    local selected = workspace == current_workspace
    local workspace_color = workspace_colors[workspace] or colors.grey

    local space = sbar.add("item", "item." .. i, {
        icon = {
            font = { family = "Iosevka Nerd Font", size = 16.0 },
            string = workspace_icons[workspace] or workspace,
            padding_left = 12,
            padding_right = 6,
            color = selected and focused_color or workspace_color,
            highlight_color = focused_color,
            highlight = selected
        },
        label = {
            padding_right = 16,
            color = selected and focused_color or workspace_color,
            highlight_color = focused_color,
            font = settings.icons,
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

    sbar.add("item", "item." .. i .. "padding", { script = "", width = settings.items.gap })

    if i == 5 then
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

    space:subscribe("mouse.clicked", function(env)
        if env.BUTTON == "other" then
            space_popup:set({ background = { image = "item." .. i } })
            space:set({ popup = { drawing = "toggle" } })
        else
            sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{window-id}' --json", function(windows)
                if windows and #windows > 0 then
                    sbar.exec("aerospace list-windows --focused --format '%{window-id}' --json", function(focused)
                        local current_window_id = focused and focused[1] and focused[1]["window-id"]
                        local next_window_id = nil
                        for wi, window in ipairs(windows) do
                            if window["window-id"] == current_window_id then
                                next_window_id = windows[wi + 1] and windows[wi + 1]["window-id"] or windows[1]["window-id"]
                                break
                            end
                        end
                        if not next_window_id then
                            next_window_id = windows[1]["window-id"]
                        end
                        sbar.exec("aerospace focus --window-id " .. next_window_id)
                    end)
                else
                    sbar.exec("aerospace workspace " .. workspace)
                end
            end)
        end
    end)

    space:subscribe("mouse.exited", function(_)
        space:set({ popup = { drawing = false } })
    end)
end
