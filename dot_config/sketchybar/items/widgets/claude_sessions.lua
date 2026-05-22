-- Mocha Neon claude_sessions widget — event-driven via fswatch + 30s idle ticker.
local sbar = require("sketchybar")
local colors = require("colors")

local claude_sessions = sbar.add("item", "widgets.claude_sessions", {
  position = "right",
  icon = {
    string = "󰙵",  -- nf-md-creation U+F0675 sparkle — verified renders in Iosevka
    color = colors.mauve,
    font = { family = "Iosevka Nerd Font", style = "Bold", size = 14.0 },
    padding_right = 6,
  },
  label = {
    string = "...",
    color = colors.mauve,
    font = { family = "Iosevka Nerd Font", style = "Bold", size = 14.0 },
  },
  background = {
    border_width = 2,
    border_color = colors.mauve,
    color = colors.bar.bg,
    corner_radius = 8,
    height = 24,
  },
  padding_left = 12,
  padding_right = 12,
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
os.execute("mkdir -p '" .. state_dir .. "'")

local function refresh()
  -- Delegate to `claude-sessions inline` which returns a single ready-to-display line.
  -- Examples: "0"  |  "2"  |  "2 dotfiles"  |  "2 +dotfiles  1 "
  local handle = io.popen("/Users/greg/Code/dotfiles/bin/claude-sessions inline 2>/dev/null")
  if not handle then return end
  local line = handle:read("*l") or ""
  handle:close()

  -- Total count = first token
  local total = tonumber(line:match("^(%d+)") or "0") or 0

  -- Waiting count: look for a digit before the bell glyph  (nf-fa-bell U+F0F4)
  -- inline may emit "2 +dotfiles  1 " — the number before the bell is waiting count.
  -- Also handle simple numeric-only output where waiting = 0.
  local waiting_count = 0
  local bell_num = line:match("(%d+)%s*\xef\x83\xb4")  -- UTF-8 bytes for U+F0F4
  if bell_num then
    waiting_count = tonumber(bell_num) or 0
  end
  -- Fallback: if line contains the bell at all, at least 1 is waiting
  if waiting_count == 0 and line:find("\xef\x83\xb4") then
    waiting_count = 1
  end

  local label_text = (total > 0) and line or "0"
  local color = (waiting_count > 0) and colors.magenta or colors.mauve

  claude_sessions:set({
    icon = { color = color },
    label = { string = label_text, color = color },
    background = { border_color = color },
  })

  -- Native macOS notification on 0→N waiting transition
  local prev = 0
  local f = io.open(state_file, "r")
  if f then prev = tonumber(f:read("*l")) or 0; f:close() end
  if prev == 0 and waiting_count > 0 then
    os.execute("osascript -e 'display notification \"Claude is waiting\" with title \"\u{F0675} Mocha Neon\" sound name \"Tink\"'")
  end
  local fw = io.open(state_file, "w")
  if fw then fw:write(tostring(waiting_count)); fw:close() end
end

claude_sessions:subscribe(
  { "claude_sessions_changed", "claude_sessions_idle_check", "forced", "system_woke" },
  refresh
)

-- Initial render at sketchybar startup
refresh()
