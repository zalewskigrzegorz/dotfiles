local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}

-- Cache for app notifications to avoid excessive calls
local app_notifications = {}

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

-- Function to update app notifications cache
local function update_app_notifications()
    sbar.exec("$CONFIG_DIR/helpers/get_app_notifications.nu", function(result)
        -- Clear previous notifications
        app_notifications = {}
        
        if result and result ~= "" then
            -- Parse the result: app_name:notification_indicator
            for line in result:gmatch("[^\r\n]+") do
                local app_name, notification = line:match("([^:]+):(.+)")
                if app_name and notification then
                    app_notifications[app_name] = notification
                end
            end
        end
    end)
end

-- Function to get notification indicator for an app
local function get_notification_indicator(app_name)
    local notification = app_notifications[app_name]
    if notification then
        -- Remove quotes if present and return the actual notification content
        notification = notification:gsub('"', '')
        return notification  -- Return actual notification (numbers, badges, etc.)
    end
    return ""
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
            local app_name = app["app-name"]
            
            -- Ignore kindaVim from workspace icons
            if app_name == "kindaVim" then
                goto continue
            end
            
            no_app = false
            local lookup = app_icons[app_name]
            local icon = ((lookup == nil) and app_icons["default"] or lookup)
            local notification = get_notification_indicator(app_name)
            
            -- Add notification indicator if present
            if notification ~= "" then
                icon_line = icon_line .. " " .. icon .. notification
            else
                icon_line = icon_line .. " " .. icon
            end
            
            ::continue::
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
            -- Get windows in this workspace and cycle through them
            sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{window-id}' --json", function(windows)
                if windows and #windows > 0 then
                    -- Get current focused window
                    sbar.exec("aerospace list-windows --focused --format '%{window-id}' --json", function(focused)
                        local current_window_id = focused and focused[1] and focused[1]["window-id"]
                        local next_window_id = nil
                        
                        -- Find next window to focus (cycle through)
                        for i, window in ipairs(windows) do
                            if window["window-id"] == current_window_id then
                                -- Focus next window, or first if we're at the end
                                next_window_id = windows[i + 1] and windows[i + 1]["window-id"] or windows[1]["window-id"]
                                break
                            end
                        end
                        
                        -- If current window not in this workspace, focus first window
                        if not next_window_id then
                            next_window_id = windows[1]["window-id"]
                        end
                        
                        -- Focus the window
                        sbar.exec("aerospace focus --window-id " .. next_window_id)
                    end)
                else
                    -- No windows, just switch to workspace
                    sbar.exec("aerospace workspace " .. workspace)
                end
            end)
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
    -- Update notifications when windows change
    update_app_notifications()
    
    for i, workspace in ipairs(workspace_order) do
        sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{app-name}' --json ", function(apps)
            local icon_line = ""
            local no_app = true
            for j, app in ipairs(apps) do
                local app_name = app["app-name"]
                
                -- Ignore kindaVim from workspace icons
                if app_name == "kindaVim" then
                    goto continue
                end
                
                no_app = false
                local lookup = app_icons[app_name]
                local icon = ((lookup == nil) and app_icons["default"] or lookup)
                local notification = get_notification_indicator(app_name)
                
                -- Add notification indicator if present
                if notification ~= "" then
                    icon_line = icon_line .. " " .. icon .. notification
                else
                    icon_line = icon_line .. " " .. icon
                end
                
                ::continue::
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
    -- Update notifications when focus changes
    update_app_notifications()
    
    for i, workspace in ipairs(workspace_order) do
        sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{app-name}' --json ", function(apps)
            local icon_line = ""
            local no_app = true
            for j, app in ipairs(apps) do
                local app_name = app["app-name"]
                
                -- Ignore kindaVim from workspace icons
                if app_name == "kindaVim" then
                    goto continue
                end
                
                no_app = false
                local lookup = app_icons[app_name]
                local icon = ((lookup == nil) and app_icons["default"] or lookup)
                local notification = get_notification_indicator(app_name)
                
                -- Add notification indicator if present
                if notification ~= "" then
                    icon_line = icon_line .. " " .. icon .. notification
                else
                    icon_line = icon_line .. " " .. icon
                end
                
                ::continue::
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

-- Add periodic notification checking (every 45 seconds)
local notification_updater = sbar.add("item", {
    drawing = false,
    updates = true,
    update_freq = 45
})

-- Subscribe to multiple events for comprehensive notification updates
notification_updater:subscribe({"routine", "front_app_switched", "system_woke"}, function()
    update_app_notifications()
    
    -- Refresh all workspace labels with updated notifications
    for i, workspace in ipairs(workspace_order) do
        sbar.exec("aerospace list-windows --workspace " .. workspace .. " --format '%{app-name}' --json ", function(apps)
            local icon_line = ""
            local no_app = true
            for j, app in ipairs(apps) do
                local app_name = app["app-name"]
                
                -- Ignore kindaVim from workspace icons
                if app_name == "kindaVim" then
                    goto continue
                end
                
                no_app = false
                local lookup = app_icons[app_name]
                local icon = ((lookup == nil) and app_icons["default"] or lookup)
                local notification = get_notification_indicator(app_name)
                
                -- Add notification indicator if present
                if notification ~= "" then
                    icon_line = icon_line .. " " .. icon .. notification
                else
                    icon_line = icon_line .. " " .. icon
                end
                
                ::continue::
            end

            if no_app then
                icon_line = " —"
            end

            spaces[i]:set({
                label = icon_line
            })
        end)
    end
end)

-- Initial notification update
update_app_notifications()

