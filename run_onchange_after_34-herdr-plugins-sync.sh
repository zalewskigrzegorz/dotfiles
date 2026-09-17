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
  thanhdat77/herdr-navigator          # unified fuzzy picker: workspaces/ssh/zoxide/agents (prefix+t) — Rust build.
                                      # NEVER pass --ref: its README still pins v0.3.3, where focusing an agent
                                      # passed terminal_id to `herdr agent focus`, which only resolves pane_id
                                      # or name — every agent jump died with agent_not_found. Fixed by v0.3.6.
  rjyo/herdr-window-title-sync        # sets OS window title (Ghostty/Moshi) from agent/prompt — needs bun, event-driven
  astkaasa/herdr-tokscale-dashboard   # token-usage + cost dashboard (prefix+m) — needs tokscale via TOKSCALE_CMD
  kryptamine/herdr-auto-title         # tab titles that follow the work in each tab — Go build, startup daemon
  shibayu36/herdr-equalize-panes      # auto `select-layout -E` on pane split/close/exit
  ChmaraX/herdr-nvim                  # nvim sidebar + agent-file picker + code annotations -> agent (prefix+e / prefix+o)
  AltanS/collie                       # phone PWA over the tailnet: which agent is blocked, answer it, push (see below)
)

# Plugins we deliberately dropped. The install loop never uninstalls, so without
# this a machine that already has one keeps it forever.
RETIRED=(
  persiyanov.reviewr                  # code-review sidebar; opened itself on worktree.created, unused (2026-09-17)
  herdr-picker-plus                   # renamed upstream to thanhdat77/herdr-navigator at v0.3.2 (2026-09-17)
  herdr-scratchpad                    # trialled 2026-09-17 and dropped: nvim already covers composing
                                      # anything long, so a second buffer earned nothing.
  hhdebb.herdr-radar                  # trialled 2026-09-17 and dropped the same day: to group the Agents list
                                      # it must own [theme.custom] + [ui.sidebar.*] whole (it refuses to merge —
                                      # a twice-declared TOML table kills every plugin). Its palette left the
                                      # spaces list too dim to scan and the rows ate more height than the
                                      # grouping was worth. Do not reinstall without re-reading that trade.
  zom-2018.herdr-ntfy-notify          # never configured (empty config dir since 2026-06-29) and there is no
                                      # ntfy server on the lab — it forked node on every agent_status_changed
                                      # to exit doing nothing. Removed 2026-09-17.
)

# NOTE: dcolinmorgan/herdr-push was removed. The whole remote-respond stack
# (lab herdr-relay + herdr-pwa containers, Mac com.greg.herdr-worker LaunchAgent,
# run_onchange_after_46) was removed 2026-07-23 — Claude Code's native Remote
# Connection covers the phone use case. herdr itself stays on BOTH machines
# (Mac + lab multiplexer); only the relay/PWA/worker service is gone.

installed="$(herdr plugin list 2>/dev/null || true)"
for id in "${RETIRED[@]}"; do
  if printf '%s' "$installed" | grep -q "$id"; then
    echo "herdr-plugins: uninstalling retired $id ..."
    herdr plugin uninstall "$id" || echo "  ⚠️  failed to uninstall: $id"
  fi
done

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

# Collie serves a remote-control surface for every agent on this host, so the
# identity gate is not optional: `tailscale serve` injects Tailscale-User-Login
# and Collie rejects anyone who is not COLLIE_TRUSTED_USER. Derive that login
# from the live tailscale state rather than hardcoding it — this repo is public.
# Written once; an existing .env is left alone. Collie tightens it to 0600 itself.
#
# Two steps still need a human and are NOT automated: "Enable HTTPS" once in the
# tailnet admin console (https://login.tailscale.com/admin/dns), and `bin/collie
# pair` to enrol a phone — the code is shown once and lives 10 minutes. Note that
# issuing the first code is also what switches write-enforcement ON; before that,
# any tailnet device can drive your agents.
co_cfg_dir="$(herdr plugin config-dir herdr.collie 2>/dev/null || true)"
if [[ -n "$co_cfg_dir" && ! -f "$co_cfg_dir/.env" ]] && command -v tailscale >/dev/null 2>&1; then
  ts_login="$(tailscale status --json 2>/dev/null \
    | jq -r '.User[(.Self.UserID|tostring)].LoginName // empty' 2>/dev/null || true)"
  if [[ -n "$ts_login" ]]; then
    mkdir -p "$co_cfg_dir"
    printf 'COLLIE_TRUSTED_USER=%s\nCOLLIE_MUX=herdr\n' "$ts_login" > "$co_cfg_dir/.env"
    chmod 600 "$co_cfg_dir/.env"
    echo "herdr-plugins: wrote collie .env (trusted user from the tailnet login)."
  else
    echo "herdr-plugins: ⚠️  collie .env not written — tailscale is down or not logged in."
  fi
fi

# `collie start` is what writes the LaunchAgent (herdr.collie, RunAtLoad) and
# raises `tailscale serve`. Installing the plugin alone leaves a dead binary, so
# a rebuilt machine needs this. Idempotent: a running bridge just reports itself.
if herdr plugin list 2>/dev/null | grep -q 'herdr.collie'; then
  herdr plugin action invoke start --plugin herdr.collie >/dev/null 2>&1 \
    && echo "herdr-plugins: collie bridge up (launchd + tailscale serve)." \
    || echo "herdr-plugins: ⚠️  collie start failed — enable HTTPS on the tailnet, then re-run."
fi
