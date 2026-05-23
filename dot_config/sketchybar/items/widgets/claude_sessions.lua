-- Mocha Neon claude_sessions widget — event-driven via fswatch + 30s idle ticker.
local sbar = require("sketchybar")
local colors = require("colors")

-- settings is needed for the universal chip token (font/padding alignment).
local settings = require("settings")

local claude_sessions = sbar.add("item", "widgets.claude_sessions", {
  position = "right",
  icon = {
    string = "󰧑",  -- nf-md-creation U+F0675 sparkle — verified renders in Iosevka
    color = colors.mauve,
    font = { family = "Iosevka Nerd Font", style = "Bold", size = 14.0 },
    padding_left = 8,
    padding_right = 6,
  },
  label = {
    string = "...",
    color = colors.mauve,
    -- Switch from Iosevka size 14 to FiraCode size 12 so this label matches
    -- the rest of the chip family (battery / cpu / calendar / notif_preview).
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 12.0,
    },
    padding_left = 0,
    padding_right = 8,
  },
  -- Universal chip token: solid bg1, height 22, mauve border 1px, radius 6.
  -- Previously: border_width=2 (thicker), height=26 (taller), color=bar.bg
  -- (the 82%-alpha translucent base) — caused this chip to stand out wrongly.
  background = {
    border_width = 1,
    border_color = colors.mauve,
    color = colors.bg1,
    corner_radius = 6,
    height = 22,
  },
  padding_left = settings.group_paddings,
  padding_right = settings.group_paddings,
  click_script = [[
    sess=$(/Users/greg/Code/dotfiles/bin/claude-sessions --json 2>/dev/null | /opt/homebrew/bin/jq -r '[.[] | select(.waiting)] | .[0].tmux_session // empty')
    if [ -n "$sess" ]; then
      /opt/homebrew/bin/tmux switch-client -t "$sess" 2>/dev/null || /usr/bin/open -a Ghostty
    else
      /usr/bin/open -a Ghostty
    fi
  ]],
})

local state_dir = os.getenv("HOME") .. "/.cache/sketchybar"
local state_file = state_dir .. "/claude_sessions_state"
os.execute("mkdir -p '" .. state_dir .. "'")

-- Resolve display file path once at module load (avoids shell spawn on each refresh).
-- macOS launchers often don't export UID; fall back to `id -u` once here.
local _uid = os.getenv("UID")
if not _uid then
  local h = io.popen("id -u")
  if h then _uid = h:read("*l"); h:close() end
end
local display_file = "/tmp/claude-sessions-display-" .. (_uid or "502") .. ".txt"

local function refresh()
  -- Read pre-rendered display string written by claude-sessions-render (sub-ms, no shell spawn).
  -- Format mirrors `claude-sessions inline`:
  --   file empty / missing  → no sessions, hide widget
  --   "D 1"                 → 1 session in 'dotfiles'
  --   "D\u{2AEF}R 2"        → 2 sessions across projects
  --   "D\u{2AEF}R 1!"       → waiting (trailing "!")
  local label_text = ""
  local f = io.open(display_file, "r")
  if f then
    label_text = f:read("*l") or ""
    f:close()
  end

  if label_text == "" then
    -- Hide widget entirely when no sessions
    claude_sessions:set({ drawing = "off" })
    local fw = io.open(state_file, "w")
    if fw then fw:write("0"); fw:close() end
    return
  end

  -- Detect waiting by trailing "!"
  local waiting_count = (label_text:find("!%s*$")) and 1 or 0
  local color = (waiting_count > 0) and colors.magenta or colors.mauve

  claude_sessions:set({
    drawing = "on",
    icon = { color = color },
    label = { string = label_text, color = color },
    background = { border_color = color },
  })

  -- Native macOS notification on 0→N waiting transition
  local prev = 0
  local f2 = io.open(state_file, "r")
  if f2 then prev = tonumber(f2:read("*l")) or 0; f2:close() end
  if prev == 0 and waiting_count > 0 then
    os.execute("osascript -e 'display notification \"Claude is waiting\" with title \"\u{F0675} Mocha Neon\" sound name \"Tink\"' 2>/dev/null")
  end
  local fw = io.open(state_file, "w")
  if fw then fw:write(tostring(waiting_count)); fw:close() end
end

claude_sessions:subscribe(
  { "claude_sessions_changed", "claude_sessions_idle_check", "forced", "system_woke", "routine" },
  refresh
)

-- DO NOT call refresh() synchronously here — io.popen on claude-sessions
-- can hang sketchybar init and leave sbar.end_config() unreached, which
-- silently aborts ALL item registration. Initial render happens via
-- 'routine' tick (sketchybar fires it at update_freq) and via the
-- claude-watcher / claude-idle-timer triggers. We also fire a one-shot
-- trigger from the shell after sketchybar is fully up (see sketchybarrc).
