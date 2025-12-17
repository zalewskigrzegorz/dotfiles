-- Require the sketchybar module
sbar = require("sketchybar")

-- Set the bar name, if you are using another bar instance than sketchybar
-- sbar.set_bar_name("bottom_bar")

-- kindaVim watcher is managed by LaunchAgent (com.kindavim.watcher.plist)
-- It runs independently of sketchybar/aerospace
-- No need to start it here - it's always running via launchd

-- OLD TIME-BASED LOGIC (disabled - using kindaVim permanently):
-- 0-13h (0:00-13:00) = svim
-- 13-0h (13:00-0:00) = kindavim
-- local hour = tonumber(os.date("%H"))
-- local svim_watcher = os.getenv("HOME") .. "/.config/svim/svim.sh"
-- if hour >= 0 and hour < 13 then
-- 	os.execute("pkill -f kindavim_watcher.sh > /dev/null 2>&1")
-- else
-- 	os.execute("pgrep -f kindavim_watcher.sh > /dev/null || " .. kindavim_watcher .. " > /dev/null 2>&1 &")
-- end

-- Bundle the entire initial configuration into a single message to sketchybar
sbar.begin_config()
require("bar")
require("default")
-- require("test")
require("items")
sbar.end_config()

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
