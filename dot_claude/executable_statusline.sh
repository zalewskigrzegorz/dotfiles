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

# Duration format scales with magnitude:
#   < 1h   → "0m45s" / "37m12s"   (minute precision)
#   < 1d   → "5h23m"               (drop seconds, add hours)
#   ≥ 1d   → "2d05h"               (drop minutes, add days)
# A 1049-minute session was reading as "1049m16s" which nobody parses at a glance.
total_s=$(( dur_ms / 1000 ))
if   (( total_s < 3600 ));   then dur_fmt=$(printf '%dm%02ds' $(( total_s / 60 )) $(( total_s % 60 )))
elif (( total_s < 86400 ));  then dur_fmt=$(printf '%dh%02dm' $(( total_s / 3600 )) $(( (total_s % 3600) / 60 )))
else                              dur_fmt=$(printf '%dd%02dh' $(( total_s / 86400 )) $(( (total_s % 86400) / 3600 )))
fi

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
      else if (n >= 1e4) printf "%dK",   n / 1e3   # 10K+ → integer K
      else if (n >= 1e3) printf "%.1fK", n / 1e3   # 1.0K–9.9K → one decimal
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

# Compaction segment — three states:
#   1) "compacted Xm ago" (mauve) — last isCompactSummary within last 30min
#   2) " auto Nx" / " manual Nx" — total count + last trigger when older
#   3) (omitted) — never compacted in this transcript
comp_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  comp_info=$(jq -rs '
    [.[] | select(.isCompactSummary == true)] as $cs |
    if ($cs | length) == 0 then "none"
    else
      ($cs | length) as $n |
      ($cs | last) as $last |
      ($last.timestamp // "") as $ts |
      ($last.compactMetadata.trigger // "manual") as $trig |
      "\($n)|\($ts)|\($trig)"
    end
  ' "$transcript" 2>/dev/null || echo none)
  if [ "$comp_info" != "none" ] && [ -n "$comp_info" ]; then
    comp_count=${comp_info%%|*}
    rest=${comp_info#*|}
    comp_ts=${rest%%|*}
    comp_trig=${rest#*|}
    # parse ISO ts → epoch (gnu/bsd date both, fallback 0)
    if [ -n "$comp_ts" ]; then
      comp_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${comp_ts%.*}" +%s 2>/dev/null \
                || date -d "$comp_ts" +%s 2>/dev/null || echo 0)
    else
      comp_epoch=0
    fi
    age=$(( now_ts - comp_epoch ))
    if [ "$comp_epoch" -gt 0 ] && [ "$age" -lt 1800 ]; then
      # < 30min ago — fresh, prominent badge
      if (( age < 60 )); then age_fmt="just now"
      elif (( age < 600 )); then age_fmt="$((age / 60))m ago"
      else age_fmt="$((age / 60))m ago"
      fi
      comp_seg="${SEP}${LABEL}󰑨 compacted ${age_fmt}${N}"
    else
      # older — show count + last trigger
      comp_seg="${SEP}${O}󰑨 ${comp_trig} ×${comp_count}${N}"
    fi
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
    # Auto-compact imminence warning — Claude Code auto-compacts somewhere
    # between 90–95% of context. Surface this BEFORE it happens so user
    # knows a compaction is coming, not just "ctx is high".
    if [ "$ctx_pct" -ge 90 ]; then
      ctx_seg="${ctx_seg} ${R}${B}󰁪 auto-compact imminent${N}"
    elif [ "$ctx_pct" -ge 80 ]; then
      ctx_seg="${ctx_seg} ${O}󰁪 compact soon${N}"
    fi
  fi
fi
[ -z "$ctx_seg" ] && [ "$over200k" = "true" ] && ctx_seg="${SEP}${R}ctx >200k${N}"

if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  lines_seg="${SEP}${MINT}${B}+$(fmt_count "$added")${N} ${R}${B}-$(fmt_count "$removed")${N}"
else
  lines_seg=""
fi

style_seg=""
[ -n "$style" ] && [ "$style" != "default" ] && style_seg="${SEP}${GOLD}${style}${N}"

# Full session title (aiTitle) — read straight from the transcript, so it is
# NOT truncated like the tmux window name (the hook trims that to ~16 chars).
win_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  ai_title=$(grep '"type":"ai-title"' "$transcript" 2>/dev/null | tail -1 \
               | jq -r '.aiTitle // empty' 2>/dev/null)
  [ -n "$ai_title" ] && win_seg="${SEP}${MINT}󰖯 ${ai_title}${N}"
fi

printf '%s%s%s%s%s%s%s%s%s%s' \
  "$model_seg" "$proj_seg" "$dur_seg" \
  "$tool_seg" "$comp_seg" \
  "$wait_seg" "$ctx_seg" "$lines_seg" "$style_seg" "$win_seg"
