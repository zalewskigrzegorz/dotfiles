-- Require the sketchybar module
sbar = require("sketchybar")

-- Set the bar name, if you are using another bar instance than sketchybar
-- sbar.set_bar_name("bottom_bar")

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require("bar")
require("default")
-- require("test")
require("items")
sbar.end_config()

-- Pre-render claude_sessions display file so the widget has data immediately
-- (avoids the widget starting hidden until the first 30s idle tick fires).
os.execute(os.getenv("HOME") .. "/Code/dotfiles/bin/claude-sessions-render >/dev/null 2>&1 &")

-- Notify sketchybar-watcher that config finished loading so it can re-push
-- ephemeral items (e.g. notif_preview) that lose their state on --reload.
local ready_cmd = os.getenv("HOME") .. "/Code/dotfiles/bin/sketchybar-watcher/sketchybar-watcher notify --event sketchybar_ready"
os.execute(ready_cmd .. " &")

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
