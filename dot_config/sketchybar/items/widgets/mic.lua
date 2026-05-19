local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local popup_width = 250

local mic_percent = sbar.add("item", "widgets.mic1", {
    position = "right",
    icon = {
        drawing = false
    },
    label = {
        string = "??%",
        padding_left = -1,
        font = {
            family = settings.font.numbers
        }
    }
})

local mic_icon = sbar.add("item", "widgets.mic2", {
    position = "right",
    padding_right = -1,
    icon = {
        string = icons.mic.on,
        width = 0,
        align = "left",
        color = colors.grey,
        font = {
            style = settings.font.style_map["Regular"],
            size = 14.0
        }
    },
    label = {
        width = 25,
        align = "left",
        font = {
            style = settings.font.style_map["Regular"],
            size = 14.0
        }
    }
})

local mic_bracket = sbar.add("bracket", "widgets.mic.bracket", {mic_icon.name, mic_percent.name}, {
    background = {
        color = colors.bg1,
        border_color = colors.rainbow[#colors.rainbow - 5],
        border_width = 1
    },
    popup = {
        align = "center"
    }
})

sbar.add("item", "widgets.mic.padding", {
    position = "right",
    width = settings.group_paddings
})

local mic_slider = sbar.add("slider", popup_width, {
    position = "popup." .. mic_bracket.name,
    slider = {
        highlight_color = colors.blue,
        background = {
            height = 6,
            corner_radius = 3,
            color = colors.bg2
        },
        knob = {
            string = "\u{100001}",
            drawing = true
        }
    },
    background = {
        color = colors.bg1,
        height = 2,
        y_offset = -20
    },
    click_script = 'osascript -e "set volume input volume $PERCENTAGE"'
})

local function update_mic()
    sbar.exec('osascript -e "input volume of (get volume settings)"', function(result)
        local volume = tonumber(result) or 0
        local icon = volume > 0 and icons.mic.on or icons.mic.off

        local lead = ""
        if volume < 10 then
            lead = "0"
        end

        mic_icon:set({
            label = icon
        })
        mic_percent:set({
            label = lead .. volume .. "%"
        })
        mic_slider:set({
            slider = {
                percentage = volume
            }
        })
    end)
end

update_mic()
mic_percent:subscribe("routine", update_mic)
mic_percent:subscribe("system_woke", update_mic)

local function mic_collapse_details()
    local drawing = mic_bracket:query().popup.drawing == "on"
    if not drawing then
        return
    end
    mic_bracket:set({
        popup = {
            drawing = false
        }
    })
    sbar.remove('/mic.device\\.*/')
end

local current_mic_device = "None"
local function mic_toggle_details(env)
    if env.BUTTON == "right" then
        sbar.exec("open /System/Library/PreferencePanes/Sound.prefpane")
        return
    end

    local should_draw = mic_bracket:query().popup.drawing == "off"
    if should_draw then
        mic_bracket:set({
            popup = {
                drawing = true
            }
        })
        sbar.exec("SwitchAudioSource -t input -c", function(result)
            current_mic_device = result:sub(1, -2)
            sbar.exec("SwitchAudioSource -a -t input", function(available)
                current = current_mic_device
                local counter = 0

                for device in string.gmatch(available, '[^\r\n]+') do
                    local color = colors.grey
                    if current == device then
                        color = colors.white
                    end
                    sbar.add("item", "mic.device." .. counter, {
                        position = "popup." .. mic_bracket.name,
                        width = popup_width,
                        align = "center",
                        label = {
                            string = device,
                            color = color
                        },
                        click_script = 'SwitchAudioSource -t input -s "' .. device ..
                            '" && sketchybar --set /mic.device\\.*/ label.color=' .. colors.grey ..
                            ' --set $NAME label.color=' .. colors.white

                    })
                    counter = counter + 1
                end
            end)
        end)
    else
        mic_collapse_details()
    end
end

local function mic_scroll(env)
    local delta = env.SCROLL_DELTA
    sbar.exec('osascript -e "set volume input volume (input volume of (get volume settings) + ' .. delta .. ')"',
        update_mic)
end

mic_icon:subscribe("mouse.clicked", mic_toggle_details)
mic_icon:subscribe("mouse.scrolled", mic_scroll)
mic_percent:subscribe("mouse.clicked", mic_toggle_details)
mic_percent:subscribe("mouse.exited.global", mic_collapse_details)
mic_percent:subscribe("mouse.scrolled", mic_scroll)
