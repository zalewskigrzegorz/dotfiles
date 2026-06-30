#!/usr/bin/env bash
# Install the herdr plugins this setup relies on. Idempotent — skips any already
# installed. Edit the PLUGINS list to add/remove (run_onchange re-fires on change).
#
# Plugin install clones + builds from GitHub and registers with a RUNNING herdr
# server, so on a fresh machine this no-ops until herdr has been launched once;
# re-run with `chezmoi apply` (or `bin/sync`) afterwards.
set -e

# chezmoi runs hooks with a minimal PATH — surface herdr + build toolchains.
for d in \
  "/opt/homebrew/bin" \
  "/home/linuxbrew/.linuxbrew/bin" \
  "${HOME}/.local/bin" \
  "${HOME}/.cargo/bin" \
; do
  [[ -d "$d" ]] && PATH="$d:$PATH"
done
export PATH

command -v herdr >/dev/null 2>&1 || { echo "herdr-plugins sync: herdr not on PATH — skipping."; exit 0; }
herdr status >/dev/null 2>&1 || { echo "herdr-plugins sync: no running herdr server — launch herdr, then \`chezmoi apply\` to install."; exit 0; }

PLUGINS=(
  persiyanov/herdr-reviewr            # code-review sidebar: diff + inline comments -> agent (prefix+r)
  zom-2018/herdr-ntfy-notify          # ntfy push when an agent goes blocked/done (needs an ntfy server)
  thanhdat77/herdr-picker-plus        # unified fuzzy picker: workspaces/ssh/zoxide/agents (prefix+t) — Rust build
  rjyo/herdr-window-title-sync        # sets OS window title (Ghostty/Moshi) from agent/prompt — needs bun, event-driven
  astkaasa/herdr-tokscale-dashboard   # token-usage + cost dashboard (prefix+m) — needs tokscale via TOKSCALE_CMD
)

# NOTE: dcolinmorgan/herdr-push was removed. The Mac feeds the relay via the
# bun worker (com.greg.herdr-worker, run_onchange_after_46) which connects
# OUTBOUND over WebSocket and pushes full host snapshots + serves read/respond
# locally. Kandji reverts macOS Remote Login, so inbound SSH-poll of the Mac is
# unstable; the worker is the Kandji-proof replacement. The lab is polled locally
# by the relay (host="minis"). See docs/herdr.md.

installed="$(herdr plugin list 2>/dev/null || true)"
for p in "${PLUGINS[@]}"; do
  if printf '%s' "$installed" | grep -q "$p"; then
    echo "herdr-plugins: $p already installed."
  else
    echo "herdr-plugins: installing $p ..."
    herdr plugin install "$p" --yes || echo "  ⚠️  failed: $p (missing build deps? re-run later)"
  fi
done

# Local (in-repo) plugins: chezmoi renders the source into ~/.config/herdr/plugins-src,
# and we `herdr plugin link` it (no GitHub clone, no build — pure nu). Keyed by plugin_id.
declare -A LOCAL_PLUGINS=(
  [greg.herdr-pick]="${HOME}/.config/herdr/plugins-src/herdr-pick"   # url/file picker -> prefix+u / prefix+f
)
for id in "${!LOCAL_PLUGINS[@]}"; do
  if printf '%s' "$installed" | grep -q "$id"; then
    echo "herdr-plugins: $id already linked."
  else
    echo "herdr-plugins: linking $id ..."
    herdr plugin link "${LOCAL_PLUGINS[$id]}" || echo "  ⚠️  failed to link: $id"
  fi
done

# Per-plugin config that must exist for the plugin to work. tokscale needs a
# tokscale binary; we don't install one, so point it at `bunx tokscale@latest`
# (bun is in the Brewfile). Written once; left alone if already present.
tk_cfg_dir="$(herdr plugin config-dir tokscale.dashboard 2>/dev/null || true)"
if [[ -n "$tk_cfg_dir" && ! -f "$tk_cfg_dir/config.env" ]]; then
  mkdir -p "$tk_cfg_dir"
  printf 'TOKSCALE_CMD="bunx tokscale@latest"\n' > "$tk_cfg_dir/config.env"
  echo "herdr-plugins: wrote tokscale config.env (TOKSCALE_CMD=bunx)."
fi
