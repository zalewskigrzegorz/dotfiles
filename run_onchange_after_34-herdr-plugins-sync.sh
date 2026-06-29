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
)

installed="$(herdr plugin list 2>/dev/null || true)"
for p in "${PLUGINS[@]}"; do
  if printf '%s' "$installed" | grep -q "$p"; then
    echo "herdr-plugins: $p already installed."
  else
    echo "herdr-plugins: installing $p ..."
    herdr plugin install "$p" --yes || echo "  ⚠️  failed: $p (missing build deps? re-run later)"
  fi
done
