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

-- Notify sketchybar-watcher that config finished loading so it can re-push
-- workspace items (item.1..10, apple) that sketchybar wipes on every reload.
local ready_cmd = os.getenv("HOME") .. "/Code/dotfiles/bin/sketchybar-watcher/sketchybar-watcher notify --event sketchybar_ready"
os.execute(ready_cmd .. " &")

-- Single-shot delayed --update to nudge items into the render queue after
-- brew services start (works around init race where items land empty on first launch).
-- --update re-renders without re-running sketchybarrc, so no infinite loop risk.
os.execute("(sleep 1 && /opt/homebrew/bin/sketchybar --update) >/dev/null 2>&1 &")

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
