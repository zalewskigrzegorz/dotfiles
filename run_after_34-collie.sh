#!/usr/bin/env bash
# Runs on every apply: a first run with tailscale down retries next time.
# Collie: the phone PWA over the tailnet (which agent is blocked, answer it,
# push), driving tuios natively (COLLIE_MUX=tuios, needs tuios >= 0.8.3).
#
# Standalone install, not a tuios plugin: `tuios plugins install` refuses to run
# inside a pane and a plugin waits for a per-machine approval dialog, so
# `chezmoi apply` could not reproduce it. Pairings live in ~/.local/state/collie
# for both installs, so a phone paired under the old herdr plugin stays paired.
set -e

# chezmoi runs hooks with a minimal PATH — surface tuios, collie and tailscale.
for d in \
  "/opt/homebrew/bin" \
  "/home/linuxbrew/.linuxbrew/bin" \
  "${HOME}/.local/bin" \
  "/Applications/Tailscale.app/Contents/MacOS" \
; do
  [[ -d "$d" ]] && PATH="$d:$PATH"
done
export PATH

command -v tuios >/dev/null 2>&1 || { echo "collie: tuios not on PATH — skipping."; exit 0; }

# The release script verifies its sha256, installs to ~/.local/share/collie and
# links ~/.local/bin/collie. It leaves an existing install alone.
if ! command -v collie >/dev/null 2>&1; then
  echo "collie: installing ..."
  curl -fsSL https://colliepwa.dev/install.sh | sh \
    || { echo "collie: ⚠️  install failed — re-run \`chezmoi apply\` later."; exit 0; }
fi

# Collie serves a remote-control surface for every agent on this host, so the
# identity gate is not optional: `tailscale serve` injects Tailscale-User-Login
# and Collie rejects anyone who is not COLLIE_TRUSTED_USER. Derive that login
# from the live tailscale state rather than hardcoding it — this repo is public.
# Written once; later runs only switch the mux keys to tuios.
#
# The .env lives in herdr's plugin config dir even on a standalone install:
# Collie reads that path before ~/.config/collie, and a Mac that ran the herdr
# plugin already has one there with COLLIE_MUX=herdr.
#
# The bridge runs under launchd/systemd, whose env may lack XDG_RUNTIME_DIR or
# carry a different one, so pin the daemon socket here with tuios's own rule:
# $XDG_RUNTIME_DIR/tuios, else /run/user/<uid>/tuios on Linux, else /tmp/tuios-<uid>.
# The same goes for the tailnet host: launchd's PATH has no tailscale.
#
# Two steps still need a human and are NOT automated: "Enable HTTPS" once in the
# tailnet admin console (https://login.tailscale.com/admin/dns), and `collie
# pair` to enrol a phone — the code is shown once and lives 10 minutes. Issuing
# the first code is also what switches write-enforcement ON.
co_env="${HOME}/.config/herdr/plugins/config/herdr.collie/.env"
uid="$(id -u)"
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  sock_dir="${XDG_RUNTIME_DIR}/tuios"
elif [[ "$(uname -s)" == Linux && -O "/run/user/${uid}" ]]; then
  sock_dir="/run/user/${uid}/tuios"
else
  sock_dir="/tmp/tuios-${uid}"
fi
mux_lines="COLLIE_MUX=tuios
COLLIE_MUX_ENDPOINT_TUIOS=${sock_dir}/tuios.sock"
if [[ -f "$co_env" ]]; then
  if ! grep -qx 'COLLIE_MUX=tuios' "$co_env"; then
    sed -i.bak -e '/^COLLIE_MUX=/d' -e '/^COLLIE_MUX_ENDPOINT_TUIOS=/d' "$co_env" && rm -f "$co_env.bak"
    printf '%s\n' "$mux_lines" >> "$co_env"
    echo "collie: .env switched to mux tuios."
    mux_changed=1
  fi
elif command -v tailscale >/dev/null 2>&1; then
  ts_json="$(tailscale status --json 2>/dev/null || true)"
  ts_login="$(printf '%s' "$ts_json" | jq -r '.User[(.Self.UserID|tostring)].LoginName // empty' 2>/dev/null || true)"
  ts_host="$(printf '%s' "$ts_json" | jq -r '.Self.DNSName // empty | rtrimstr(".")' 2>/dev/null || true)"
  if [[ -n "$ts_login" && -n "$ts_host" ]]; then
    mkdir -p "$(dirname "$co_env")"
    printf 'COLLIE_TRUSTED_USER=%s\n%s\nCOLLIE_TAILSCALE_HOSTS=%s\n' "$ts_login" "$mux_lines" "$ts_host" > "$co_env"
    chmod 600 "$co_env"
    echo "collie: wrote .env (trusted user from the tailnet login, mux tuios)."
  else
    echo "collie: ⚠️  .env not written — tailscale is down or not logged in."
  fi
fi

# The old herdr-plugin Collie runs under the same launchd label, driving herdr.
# `collie start` would take that bridge for its own and leave it running.
old_plist="${HOME}/Library/LaunchAgents/herdr.collie.plist"
if [[ -f "$old_plist" ]] && grep -q '/herdr/plugins/github-installations/' "$old_plist"; then
  launchctl bootout "gui/$(id -u)/herdr.collie" 2>/dev/null || true
  rm -f "$old_plist"
  echo "collie: removed the herdr-plugin bridge."
fi

# `collie start` writes the service (launchd herdr.collie / systemd --user
# collie) and raises `tailscale serve`. Idempotent: a running bridge just
# reports itself. No stdin, so a first-run question can never hang the apply.
if [[ -f "$co_env" ]]; then
  # A running bridge keeps its old env, so a mux switch needs a restart.
  verb=start
  [[ -n "${mux_changed:-}" ]] && verb=restart
  collie "$verb" </dev/null >/dev/null 2>&1 \
    && echo "collie: bridge up (service + tailscale serve)." \
    || echo "collie: ⚠️  collie start failed — enable HTTPS on the tailnet, then \`collie doctor\`."
fi
