#!/usr/bin/env bash
# Claude Code statusline.

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "claude"')
# Compact long model strings so the statusline doesn't burn half the line on
# the model token. Maps common API-style ids to short aliases:
#   "Claude 3.7 Sonnet" / "claude-3-7-sonnet-20241022" → "sonnet 3.7"
#   "Claude 3 Opus" / "claude-3-opus-20240229"         → "opus 3"
#   "Claude 4.7 Opus (1M context)"                     → "opus 4.7 1M"
# Falls through unchanged for already-short names.
case "$model" in
  *[Cc]laude*[Ss]onnet*|*[Ss]onnet*)
    model=$(printf '%s' "$model" | sed -E 's/.*[Cc]laude[- ]*([0-9.]+)[- ]*[Ss]onnet.*/sonnet \1/; s/.*([Ss])onnet[- ]*([0-9.]+).*/\L\1\E\2/' | head -1)
    ;;
  *[Cc]laude*[Oo]pus*|*[Oo]pus*)
    model=$(printf '%s' "$model" | sed -E 's/.*[Cc]laude[- ]*([0-9.]+)[- ]*[Oo]pus.*\(([^)]+)\)/opus \1 \2/; s/.*[Cc]laude[- ]*([0-9.]+)[- ]*[Oo]pus.*/opus \1/; s/.*[Oo]pus[- ]*([0-9.]+).*/opus \1/' | head -1 | tr '[:upper:]' '[:lower:]')
    ;;
  *[Cc]laude*[Hh]aiku*|*[Hh]aiku*)
    model=$(printf '%s' "$model" | sed -E 's/.*[Cc]laude[- ]*([0-9.]+)[- ]*[Hh]aiku.*/haiku \1/; s/.*[Hh]aiku[- ]*([0-9.]+).*/haiku \1/' | head -1 | tr '[:upper:]' '[:lower:]')
    ;;
esac
# Hard cap: trim anything still too long (e.g. unknown future model).
if [ "${#model}" -gt 20 ]; then
  model="${model:0:18}…"
fi
dur_ms=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // 0')
added=$(printf '%s' "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // 0')
over200k=$(printf '%s' "$input" | jq -r '.exceeds_200k_tokens // false')
style=$(printf '%s' "$input" | jq -r '.output_style.name // ""')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')

mm=$(( dur_ms / 60000 )); ss=$(( (dur_ms % 60000) / 1000 ))
dur_fmt=$(printf '%dm%02ds' "$mm" "$ss")

# --- palette (Mocha Neon — Catppuccin Mocha + bumped accents) ---
B=$'\033[1m'
N=$'\033[0m'
FG=$'\033[38;2;240;240;255m'      # #F0F0FF text
LABEL=$'\033[38;2;179;71;255m'    # #B347FF mauve — labels
MUTED=$'\033[38;2;166;173;200m'   # #A6ADC8 subtext
SEPC=$'\033[38;2;88;91;112m'      # #585B70 surface2 — separator
TROUGH=$'\033[38;2;49;50;68m'     # #313244 surface0 — bar empty
TROUGH_BG=$'\033[48;2;49;50;68m'
BG_RESET=$'\033[49m'
ACCENT=$'\033[38;2;179;71;255m'   # #B347FF mauve — model
G=$'\033[38;2;80;250;123m'        # #50FA7B green — success
Y=$'\033[38;2;255;215;0m'         # #FFD700 gold — warning
O=$'\033[38;2;255;140;66m'        # #FF8C42 peach — compaction / pace-warn
R=$'\033[38;2;255;107;157m'       # #FF6B9D red — error / waiting
PINK=$'\033[38;2;255;128;191m'    # #FF80BF pink — project / session
PURPLE=$'\033[38;2;149;128;255m'  # #9580FF lavender
CYAN=$'\033[38;2;139;233;253m'    # #8BE9FD sky — week
MINT=$'\033[38;2;80;250;123m'     # #50FA7B mint — duration / success
AMBER=$'\033[38;2;255;215;0m'     # #FFD700 amber — ctx
GOLD=$'\033[38;2;255;215;0m'      # #FFD700 — style/tools
SEP=" ${SEPC}▌${N} "

now_ts=$(date +%s)

# --- ccusage cache (30s) — session block auto-detect ---
cache_dir="${TMPDIR:-/tmp}/claude-statusline-$UID"
mkdir -p "$cache_dir" 2>/dev/null
cache_file="$cache_dir/ccusage.json"
if [ -f "$cache_file" ]; then
  mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)
  age=$(( now_ts - mtime ))
else
  age=9999
fi
if [ "$age" -gt 30 ] && command -v ccusage >/dev/null 2>&1; then
  ccusage blocks --json --active --offline 2>/dev/null | jq '.blocks[0] // null' > "$cache_file.tmp" 2>/dev/null \
    && mv "$cache_file.tmp" "$cache_file"
fi


# --- helpers ---
fmt_count() {
  local n="${1:-0}"
  [[ -z "$n" || "$n" == "null" ]] && { echo "?"; return; }
  awk -v n="$n" '
    BEGIN {
      if (n >= 1e9)      printf "%.1fG", n / 1e9
      else if (n >= 1e6) printf "%.1fM", n / 1e6
      else if (n >= 1e3) printf "%.0fK", n / 1e3
      else               printf "%d", n
    }
  '
}

pct_elapsed() {
  local start=$1 end=$2
  [ "$end" -le "$start" ] && { echo 0; return; }
  local total=$(( end - start ))
  local done=$(( now_ts - start ))
  (( done < 0 )) && done=0
  (( done > total )) && done=$total
  echo $(( done * 100 / total ))
}

fmt_remain() {
  local s=$1
  (( s < 0 )) && s=0
  local d=$(( s / 86400 )) h=$(( (s % 86400) / 3600 )) m=$(( (s % 3600) / 60 ))
  if (( d > 0 ));   then printf '%dd%02dh' "$d" "$h"
  elif (( h > 0 )); then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

bar() {
  local p=$1 width=12 color_override=${2:-}
  local full=$(( (p * width + 50) / 100 ))
  (( full > width )) && full=$width
  (( full < 0 )) && full=0
  local empty_n=$(( width - full ))
  local color
  if [ -n "$color_override" ]; then color="$color_override"
  elif [ "$p" -ge 90 ]; then color="$R"
  elif [ "$p" -ge 75 ]; then color="$O"
  elif [ "$p" -ge 50 ]; then color="$Y"
  else color="$G"; fi
  local fill="" empty="" i
  for ((i=0; i<full;    i++)); do fill+="▰"; done
  for ((i=0; i<empty_n; i++)); do empty+="▱"; done
  printf '%s%s%s%s%s' "$color" "$fill" "$TROUGH" "$empty" "$N"
}

# --- segments ---
model_seg="${ACCENT}${B}${model}${N}"

proj_seg=""
if [ -n "$cwd" ]; then
  proj_seg="${SEP}${PURPLE}${B}$(basename "$cwd")${N}"
fi

dur_seg="${SEP}${MINT}${dur_fmt}${N}"

# Tool call counter (count tool_use events in transcript)
tool_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  tool_count=$(jq -rs '[.[] | select(.type=="tool_use")] | length' "$transcript" 2>/dev/null || echo 0)
  if [ -n "$tool_count" ] && [ "$tool_count" != "null" ] && [ "$tool_count" -gt 0 ]; then
    tool_seg="${SEP}${GOLD}󰣖 ${tool_count}${N}"
  fi
fi

# Compaction counter — uses test() so it matches multiple possible marker names
comp_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  comp_count=$(jq -rs '[.[] | select(.type | test("^(compact|compaction)$"))] | length' "$transcript" 2>/dev/null || echo 0)
  if [ -n "$comp_count" ] && [ "$comp_count" != "null" ] && [ "$comp_count" -gt 0 ]; then
    comp_seg="${SEP}${O}󰑨 ${comp_count}${N}"
  fi
fi

# Waiting badge — fires when last event is assistant_text_end AND idle > 30s
wait_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  last_type=$(tail -n 1 "$transcript" 2>/dev/null | jq -r '.type // empty' 2>/dev/null || echo "")
  if [[ "$last_type" == "assistant_text_end" ]]; then
    t_mtime=$(stat -f %m "$transcript" 2>/dev/null || stat -c %Y "$transcript" 2>/dev/null || echo 0)
    idle=$(( now_ts - t_mtime ))
    if (( idle > 30 )); then
      m=$(( idle / 60 ))
      if (( m > 0 )); then wait_fmt=$(printf '%dm' "$m"); else wait_fmt=$(printf '%ds' "$idle"); fi
      wait_seg="${SEP}${R}󰂚 wait ${wait_fmt}${N}"
    fi
  fi
fi

# context %
ctx_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  ctx_tokens=$(tail -50 "$transcript" 2>/dev/null | \
    jq -rs '[.[] | select(.message.usage) | .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)] | max // 0' 2>/dev/null)
  if [ -n "$ctx_tokens" ] && [ "$ctx_tokens" != "null" ] && [ "$ctx_tokens" -gt 0 ]; then
    if [ "$over200k" = "true" ]; then ctx_max=1000000; else ctx_max=200000; fi
    ctx_pct=$(( ctx_tokens * 100 / ctx_max ))
    # compaction warning: red ≥85% (compact ~90%), peach ≥60% (warning),
    # green otherwise. Peach instead of yellow to match the warning-vs-info
    # convention used elsewhere in the Mocha Neon stack.
    if   [ "$ctx_pct" -ge 85 ]; then cc="$R"
    elif [ "$ctx_pct" -ge 60 ]; then cc="$O"
    else cc="$G"; fi
    ctx_seg="${SEP}${AMBER}ctx${N} $(bar "$ctx_pct" "$cc") ${cc}${B}${ctx_pct}%${N}"
  fi
fi
[ -z "$ctx_seg" ] && [ "$over200k" = "true" ] && ctx_seg="${SEP}${R}ctx >200k${N}"

if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  lines_seg="${SEP}${MINT}${B}+${added}${N} ${R}${B}-${removed}${N}"
else
  lines_seg=""
fi

style_seg=""
[ -n "$style" ] && [ "$style" != "default" ] && style_seg="${SEP}${GOLD}${style}${N}"

printf '%s%s%s%s%s%s%s%s%s' \
  "$model_seg" "$proj_seg" "$dur_seg" \
  "$tool_seg" "$comp_seg" \
  "$wait_seg" "$ctx_seg" "$lines_seg" "$style_seg"
