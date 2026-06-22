local colors = require("colors")
local settings = require("settings")

-- Claude agent presence chip:  <blocked>  <waiting>  <running>. Hidden when no
-- agents need you elsewhere. PUSH-driven by bin/claude-agent-chip (called from the
-- agent hooks on every state change + a tmux window-switch hook) — sbarlua's
-- routine/update_freq timer never fired for this item, so there is no timer here.
-- Click → jump to the agent that needs you (bin/tmux-window-jump).
sbar.add("item", "claude_agents", {
    position = "right",
    drawing = false,
    icon = { drawing = false },
    label = {
        color = colors.red,
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = 13.0
        }
    },
    click_script = os.getenv("HOME") .. "/Code/dotfiles/bin/tmux-window-jump"
})
