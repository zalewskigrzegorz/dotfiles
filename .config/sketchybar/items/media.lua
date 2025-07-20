local icons = require("icons")
local colors = require("colors")

local whitelist = {
    ["Spotify"] = true,
    ["Music"] = true
};

local media_cover = sbar.add("item", {
    position = "right",
    background = {
        image = {
            string = "media.artwork",
            scale = 0.85
        },
        color = colors.transparent
    },
    label = {
        drawing = false
    },
    icon = {
        drawing = false
    },
    drawing = false,
    updates = true,
    popup = {
        align = "center",
        horizontal = true
    }
})

local media_artist = sbar.add("item", {
    position = "right",
    drawing = false,
    padding_left = 3,
    padding_right = 0,
    width = 0,
    icon = {
        drawing = false
    },
    label = {
        width = 0,
        font = {
            size = 9
        },
        color = colors.with_alpha(colors.white, 0.6),
        max_chars = 18,
        y_offset = 6
    }
})

local media_title = sbar.add("item", {
    position = "right",
    drawing = false,
    padding_left = 3,
    padding_right = 0,
    icon = {
        drawing = false
    },
    label = {
        font = {
            size = 11
        },
        width = 0,
        max_chars = 16,
        y_offset = -5
    }
})

sbar.add("item", {
    position = "popup." .. media_cover.name,
    icon = {
        string = icons.media.back
    },
    label = {
        drawing = false
    },
    click_script = "osascript -e 'tell application \"Spotify\" to previous track'"
})
sbar.add("item", {
    position = "popup." .. media_cover.name,
    icon = {
        string = icons.media.play_pause
    },
    label = {
        drawing = false
    },
    click_script = "osascript -e 'tell application \"Spotify\" to playpause'"
})
sbar.add("item", {
    position = "popup." .. media_cover.name,
    icon = {
        string = icons.media.forward
    },
    label = {
        drawing = false
    },
    click_script = "osascript -e 'tell application \"Spotify\" to next track'"
})

local interrupt = 0
local function animate_detail(detail)
    if (not detail) then
        interrupt = interrupt - 1
    end
    if interrupt > 0 and (not detail) then
        return
    end

    sbar.animate("tanh", 30, function()
        media_artist:set({
            label = {
                width = detail and "dynamic" or 0
            }
        })
        media_title:set({
            label = {
                width = detail and "dynamic" or 0
            }
        })
    end)
end

-- Function to get media info using osascript
local current_track = ""
local current_artist = ""
local current_state = ""

local function update_media_info()
    -- Check if Spotify is running and playing
    sbar.exec("osascript -e 'tell application \"System Events\" to (name of processes) contains \"Spotify\"'", function(spotify_running)
        if spotify_running:match("true") then
            sbar.exec("osascript -e 'tell application \"Spotify\" to get player state'", function(state)
                state = state:gsub("%s+$", "") -- trim whitespace
                if state:match("playing") then
                    -- Get track info
                    sbar.exec("osascript -e 'tell application \"Spotify\" to get name of current track'", function(title)
                        sbar.exec("osascript -e 'tell application \"Spotify\" to get artist of current track'", function(artist)
                            title = title:gsub("%s+$", "") -- trim whitespace
                            artist = artist:gsub("%s+$", "") -- trim whitespace
                            
                            -- Only update if track changed
                            if title ~= current_track or artist ~= current_artist or state ~= current_state then
                                current_track = title
                                current_artist = artist
                                current_state = state
                                
                                -- Update media display
                                local drawing = true
                                media_artist:set({
                                    drawing = drawing,
                                    label = artist
                                })
                                media_title:set({
                                    drawing = drawing,
                                    label = title
                                })
                                media_cover:set({
                                    drawing = drawing
                                })
                                
                                -- Only animate on track change, not constantly
                                animate_detail(true)
                                interrupt = interrupt + 1
                                sbar.delay(5, animate_detail)
                            end
                        end)
                    end)
                else
                    -- Not playing, hide media if state changed
                    if current_state ~= state then
                        current_state = state
                        current_track = ""
                        current_artist = ""
                        media_artist:set({ drawing = false })
                        media_title:set({ drawing = false })
                        media_cover:set({ drawing = false })
                    end
                end
            end)
        else
            -- Spotify not running, hide media if state changed
            if current_state ~= "stopped" then
                current_state = "stopped"
                current_track = ""
                current_artist = ""
                media_artist:set({ drawing = false })
                media_title:set({ drawing = false })
                media_cover:set({ drawing = false })
            end
        end
    end)
end

-- Update media info every 2 seconds
local media_updater = sbar.add("item", {
    drawing = false,
    updates = true,
    script = "sleep 2",
    update_freq = 2
})

media_updater:subscribe("routine", function()
    update_media_info()
end)

-- Initial update
update_media_info()

media_cover:subscribe("media_change", function(env)
    -- Keep the original logic as fallback
    if whitelist[env.INFO.app] then
        local drawing = (env.INFO.state == "playing")
        media_artist:set({
            drawing = drawing,
            label = env.INFO.artist
        })
        media_title:set({
            drawing = drawing,
            label = env.INFO.title
        })
        media_cover:set({
            drawing = drawing
        })

        if drawing then
            animate_detail(true)
            interrupt = interrupt + 1
            sbar.delay(5, animate_detail)
        else
            media_cover:set({
                popup = {
                    drawing = false
                }
            })
        end
    end
end)

media_cover:subscribe("mouse.entered", function(env)
    interrupt = interrupt + 1
    animate_detail(true)
end)

media_cover:subscribe("mouse.exited", function(env)
    animate_detail(false)
end)

media_cover:subscribe("mouse.clicked", function(env)
    media_cover:set({
        popup = {
            drawing = "toggle"
        }
    })
end)

media_title:subscribe("mouse.exited.global", function(env)
    media_cover:set({
        popup = {
            drawing = false
        }
    })
end)
