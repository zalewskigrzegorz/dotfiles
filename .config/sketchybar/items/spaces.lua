local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}

-- Define workspace order matching Aerospace keyboard layout
local workspace_order = {
    "chat",   -- ctrl-1
    "web",    -- ctrl-2
    "term",   -- ctrl-3
    "code",   -- ctrl-4
    "media",  -- ctrl-5
    "test",   -- ctrl-6
    "misc",   -- ctrl-7
    "notes",  -- ctrl-8
    "mail",   -- ctrl-9
    "mac"     -- ctrl-0
}

-- Nerd font icons for each workspace
local workspace_icons = {
    ["chat"] = "󰭻",
    ["web"] = "󰖟",
    ["term"] = "󰆍",
    ["code"] = "",
    ["media"] = "󰝚",
    ["test"] = "󰙨",
    ["misc"] = "󰉋",
    ["notes"] = "󰂺",
    ["mail"] = "󰇮",
    ["mac"] = "󰍹"
}

-- Color scheme for each workspace
local workspace_colors = {
    ["chat"] = colors.bright_green,    
    ["web"] = colors.blue,       
    ["term"] = colors.orange,    
    ["code"] = colors.magenta,      
    ["media"] = colors.bright_red,  
    ["test"] = colors.yellow,    
    ["misc"] = colors.grey,      
    ["notes"] = colors.green, 
    ["mail"] = colors.red,       
    ["mac"] = colors.white      
}

local current_workspace = get_current_workspace()
local function split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
        table.insert(result, each)
    end
    return result
end

for i, workspace in ipairs(workspace_order) do
    local selected = workspace == current_workspace
    local workspace_color = workspace_colors[workspace] or colors.grey
    local focused_color = colors.purple -- Purple for focused
    
    local space = sbar.add("item", "item." .. i, {
        icon = {
            font = {
                family = "Iosevka Nerd Font",
                size = 16.0
            },
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
            background = {
                border_width = 5,
                border_color = colors.black
            }
        }
    })

    spaces[i] = space

    -- Define the icons for open apps on each space initially
    sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{app-name}' --json ", function(apps)
        local icon_line = ""
        local no_app = true
        for j, app in ipairs(apps) do
            no_app = false
            local app_name = app["app-name"]
            local lookup = app_icons[app_name]
            local icon = ((lookup == nil) and app_icons["default"] or lookup)
            icon_line = icon_line .. " " .. icon
        end

        if no_app then
            icon_line = " —"
        end

        sbar.animate("tanh", 10, function()
            space:set({
                label = icon_line
            })
        end)
    end)

    -- Padding space between each item
    sbar.add("item", "item." .. i .. "padding", {
        script = "",
        width = settings.items.gap
    })

    -- Item popup
    local space_popup = sbar.add("item", {
        position = "popup." .. space.name,
        padding_left = 5,
        padding_right = 0,
        background = {
            drawing = true,
            image = {
                corner_radius = 9,
                scale = 0.2
            }
        }
    })

    space:subscribe("aerospace_workspace_change", function(env)
        local selected = env.FOCUSED_WORKSPACE == workspace
        local color = selected and focused_color or workspace_color
        
        sbar.animate("tanh", 15, function()
            space:set({
                icon = {
                    highlight = selected,
                    color = color
                },
                label = {
                    highlight = selected,
                    color = color
                },
                background = {
                    border_color = color,
                    border_width = selected and 3 or 1  
                }
            })
        end)
        
        if selected then
            sbar.animate("sin", 30, function()
                space:set({
                    background = {
                        color = colors.with_alpha(color, 0.1)
                    }
                })
            end)
        else
            space:set({
                background = {
                    color = colors.transparent
                }
            })
        end
    end)

    space:subscribe("mouse.clicked", function(env)
        if env.BUTTON == "other" then
            space_popup:set({
                background = {
                    image = "item." .. i
                }
            })
            space:set({
                popup = {
                    drawing = "toggle"
                }
            })
        else
            sbar.exec("aerospace workspace " .. workspace)
        end
    end)

    space:subscribe("mouse.exited", function(_)
        space:set({
            popup = {
                drawing = false
            }
        })
    end)
end

local space_window_observer = sbar.add("item", {
    drawing = false,
    updates = true
})

-- Handles the small icon indicator for spaces / menus changes
space_window_observer:subscribe("space_windows_change", function(env)
    for i, workspace in ipairs(workspace_order) do
        sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{app-name}' --json ", function(apps)
            local icon_line = ""
            local no_app = true
            for j, app in ipairs(apps) do
                no_app = false
                local app_name = app["app-name"]
                local lookup = app_icons[app_name]
                local icon = ((lookup == nil) and app_icons["default"] or lookup)
                icon_line = icon_line .. " " .. icon
            end

            if no_app then
                icon_line = " —"
            end

            sbar.animate("tanh", 10, function()
                spaces[i]:set({
                    label = icon_line
                })
            end)
        end)
    end
end)

space_window_observer:subscribe("aerospace_focus_change", function(env)
    for i, workspace in ipairs(workspace_order) do
        sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{app-name}' --json ", function(apps)
            local icon_line = ""
            local no_app = true
            for j, app in ipairs(apps) do
                no_app = false
                local app_name = app["app-name"]
                local lookup = app_icons[app_name]
                local icon = ((lookup == nil) and app_icons["default"] or lookup)
                icon_line = icon_line .. " " .. icon
            end

            if no_app then
                icon_line = " —"
            end

            sbar.animate("tanh", 10, function()
                spaces[i]:set({
                    label = icon_line
                })
            end)
        end)
    end
end)


