#!/usr/bin/env bash
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "claude"')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
dur_ms=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // 0')
api_ms=$(printf '%s' "$input" | jq -r '.cost.total_api_duration_ms // 0')
added=$(printf '%s' "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // 0')
over200k=$(printf '%s' "$input" | jq -r '.exceeds_200k_tokens // false')
style=$(printf '%s' "$input" | jq -r '.output_style.name // ""')

mm=$(( dur_ms / 60000 ))
ss=$(( (dur_ms % 60000) / 1000 ))
dur_fmt=$(printf '%dm%02ds' "$mm" "$ss")

api_s=$(( api_ms / 1000 ))
api_fmt="${api_s}s"

cost_fmt=$(printf '$%.2f' "$cost")

if [ "$over200k" = "true" ]; then
  ctx=' | ctx >200k'
else
  ctx=''
fi

if [ -n "$style" ] && [ "$style" != "default" ]; then
  style_fmt=" | $style"
else
  style_fmt=''
fi

printf '%s | %s | session %s (api %s) | +%s -%s%s%s' \
  "$model" "$cost_fmt" "$dur_fmt" "$api_fmt" "$added" "$removed" "$ctx" "$style_fmt"
