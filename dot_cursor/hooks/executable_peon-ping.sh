#!/usr/bin/env bash
set -u

input="$(cat)"
peon="${HOME}/.claude/hooks/peon-ping/peon.sh"
log_dir="${HOME}/.local/state/dotfiles/peon-ping"
log_file="${log_dir}/cursor-hook.log"

mkdir -p "$log_dir"

payload="$(
  INPUT="$input" python3 - <<'PY'
import json
import os

raw = os.environ.get("INPUT", "")
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {"raw_input": raw}

event = data.get("hook_event_name") or data.get("event") or ""
if event:
    data["hook_event_name"] = event

print(json.dumps(data))
PY
)"

if [[ -f "$peon" ]]; then
  printf '%s\n' "$payload" | bash "$peon" >>"$log_file" 2>&1 || true
else
  printf 'peon.sh not found: %s\n' "$peon" >>"$log_file"
fi

printf '{}\n'
