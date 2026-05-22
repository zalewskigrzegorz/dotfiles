-- Mocha Neon claude_sessions widget — event-driven, no polling.
-- Subscribes to two events:
--   • claude_sessions_changed     fired by bin/claude-watcher on .jsonl FS event
--   • claude_sessions_idle_check  fired by bin/claude-idle-timer every 30s
-- On 0→N waiting transition, fires native macOS notification.
local sbar = require("sketchybar")
local colors = require("colors")

local claude_sessions = sbar.add("item", "widgets.claude_sessions", {
  position = "right",
  icon = {
    string = "🔗",
    color = colors.green,
    font = { family = "Iosevka Nerd Font", style = "Bold", size = 14.0 },
    padding_right = 4,
  },
  label = {
    string = "0",
    color = colors.green,
    font = { family = "Iosevka Nerd Font", style = "Bold", size = 14.0 },
  },
  background = {
    border_width = 2,
    border_color = colors.green,
    color = colors.bar.bg,
    corner_radius = 8,
    height = 24,
  },
  padding_left = 8,
  padding_right = 8,
  click_script = [[
    sess=$(/Users/greg/Code/dotfiles/bin/claude-sessions waiting 2>/dev/null | head -n 1 | awk -F'\t' '{print $1}')
    if [ -n "$sess" ]; then
      /opt/homebrew/bin/tmux switch-client -t "$sess" 2>/dev/null || \
      /usr/bin/open -a Ghostty
    else
      /usr/bin/open -a Ghostty
    fi
  ]],
})

local state_dir = os.getenv("HOME") .. "/.cache/sketchybar"
local state_file = state_dir .. "/claude_sessions_state"
os.execute("mkdir -p " .. state_dir)

local function refresh()
  local handle = io.popen("/Users/greg/Code/dotfiles/bin/claude-sessions --json 2>/dev/null")
  if not handle then return end
  local json = handle:read("*a")
  handle:close()

  local total, waiting = 0, 0
  for sessions, wait in (json or ""):gmatch('"waiting":(%a+)') do
    -- waiting is "true" or "false"; count each entry
    total = total + 1
    if wait == "true" then waiting = waiting + 1 end
  end
  -- Fallback: count by occurrences of "session_id"
  if total == 0 then
    for _ in (json or ""):gmatch('"session_id":') do
      total = total + 1
    end
  end

  local color = colors.green
  local icon_str = "🔗"
  if waiting > 0 then
    color = colors.yellow
    icon_str = "🔗 " .. waiting .. " 🔔"
  end

  -- Transition detection: fire native notif only on 0→N waiting
  local prev = 0
  local f = io.open(state_file, "r")
  if f then prev = tonumber(f:read("*l")) or 0; f:close() end
  if prev == 0 and waiting > 0 then
    os.execute([[osascript -e 'display notification "Claude is waiting" with title "🦄 Mocha Neon" sound name "Tink"']])
  end
  local fw = io.open(state_file, "w")
  if fw then fw:write(tostring(waiting)); fw:close() end

  claude_sessions:set({
    icon = { string = icon_str, color = color },
    label = { string = tostring(total), color = color },
    background = { border_color = color },
  })
end

claude_sessions:subscribe(
  { "claude_sessions_changed", "claude_sessions_idle_check", "forced", "system_woke" },
  refresh
)

-- Initial render at sketchybar startup
refresh()
