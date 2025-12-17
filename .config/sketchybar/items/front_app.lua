local colors = require("colors")
local settings = require("settings")

local front_app = sbar.add("item", "front_app", {
    display = "active",
    icon = {
        drawing = false
    },
    label = {
        font = {
            style = settings.font.style_map["Bold"],
            size = 13.0
        }
    },
    updates = true
})

front_app:subscribe("front_app_switched", function(env)
    -- Ignore kindaVim from front app display
    if env.INFO == "kindaVim" then
        return
    end
    
    front_app:set({
        label = {
            string = env.INFO
        }
    })
end)

