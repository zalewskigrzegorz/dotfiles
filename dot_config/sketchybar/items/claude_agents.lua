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
    -- Item-level padding (NOT separate padding items): collapses with the chip
    -- when drawing=off, so no phantom gap between battery and calendar when idle.
    padding_left = settings.group_paddings,
    padding_right = settings.group_paddings,
    icon = { drawing = false },
    label = {
        color = colors.red,
        padding_left = 8,
        padding_right = 8,
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = 13.0
        }
    },
    -- Pill identical to the other widgets; border_color is set per-state by
    -- bin/claude-agent-chip (red=blocked, gold=waiting, green=running).
    background = {
        color = colors.bg1,
        height = 26,
        corner_radius = 6,
        border_color = colors.red,
        border_width = 1
    },
    click_script = os.getenv("HOME") .. "/Code/dotfiles/bin/tmux-window-jump"
})
