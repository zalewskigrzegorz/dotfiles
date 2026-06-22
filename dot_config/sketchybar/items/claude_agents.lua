local colors = require("colors")
local settings = require("settings")

-- Persistent Claude agent presence chip: ⏳<waiting> ●<running>. Hidden when no
-- agents are live. Backed by the shared state dir via the claude_agents.sh
-- plugin; click jumps to the waiting-only tmux picker.
local claude = sbar.add("item", "claude_agents", {
    position = "right",
    drawing = false,
    icon = {
        drawing = false
    },
    label = {
        color = colors.red,
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = 13.0
        }
    },
    update_freq = 5,
    script = "$CONFIG_DIR/plugins/claude_agents.sh",
    click_script = os.getenv("HOME") .. "/Code/dotfiles/bin/tmux-window-jump --waiting"
})

claude:subscribe({"routine", "forced"}, function()
    claude:set({})
end)
