#!/usr/bin/env bash
set -euo pipefail

apps_file="${1:-docs/setapp-apps.md}"

if [[ ! -f "$apps_file" ]]; then
  echo "Setapp app list not found: $apps_file" >&2
  exit 2
fi

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Setapp apps are macOS-only."
  exit 0
fi

missing=0

while IFS= read -r app; do
  [[ -n "$app" ]] || continue

  found=false
  for base in "/Applications/Setapp" "/Applications"; do
    if [[ -d "$base/$app.app" ]]; then
      found=true
      break
    fi
  done

  if [[ "$found" == true ]]; then
    printf "ok      %s\n" "$app"
  else
    printf "missing %s\n" "$app"
    missing=$((missing + 1))
  fi
done < <(sed -nE 's/^- \[[ xX]\] (.+)$/\1/p' "$apps_file")

if [[ "$missing" -gt 0 ]]; then
  echo
  echo "$missing Setapp app(s) missing. Install them from Setapp after signing in."
  exit 1
fi
