#!/usr/bin/env bash
# Install the `gh` CLI extensions this setup relies on. Idempotent — skips any
# already installed, and one failing install never fails the whole apply.
# Edit the EXTENSIONS list to add/remove (run_onchange re-fires on change).
#
# Extensions live in per-user state (~/.local/share/gh/extensions) that chezmoi
# does not track, so this list is the ONLY record of them — without it a fresh
# machine has no gh-dash and no `gh stack`, and `work pr` loses half its rows.
#
# Not a sync: extensions installed ad hoc are left alone (nothing is
# uninstalled here). Upgrades are manual — `gh extension upgrade --all`.
set -e

# chezmoi runs hooks with a minimal PATH — surface brew's gh on both platforms
# before the `command -v gh` check (macOS /opt/homebrew, lab linuxbrew).
for d in \
  "/opt/homebrew/bin" \
  "/home/linuxbrew/.linuxbrew/bin" \
  "${HOME}/.local/bin" \
; do
  [[ -d "$d" ]] && PATH="$d:$PATH"
done
export PATH

command -v gh >/dev/null 2>&1 || { echo "gh-extensions: gh not on PATH — skipping."; exit 0; }
gh auth status >/dev/null 2>&1 || { echo "gh-extensions: gh not authenticated — run \`gh auth login\`, then \`chezmoi apply\` to install."; exit 0; }

EXTENSIONS=(
  github/gh-stack           # native stacked PRs — backs the `work pr` stack sub-picker
  dlvhdr/gh-dash            # PR/issue dashboard TUI — config in dot_config/private_gh-dash, wrapper `dash`
  rnorth/gh-combine-prs     # combine matching PRs (e.g. dependabot batches) into one
  vilmibm/gh-contribute     # suggest an issue to work on in a given repo
  github/gh-copilot         # `gh copilot suggest` / `explain`
  sgoedecke/gh-standup      # GitHub-activity standup report (GitHub Models/Copilot)
  HaywardMorihara/gh-tidy   # checkout+pull default branch, git gc, prune merged local branches
)

# `gh extension list` is TSV: "gh <alias>\t<owner>/<repo>\t<version>". No --json
# flag exists, so parse field 2 and compare case-insensitively (owners like
# HaywardMorihara are echoed back with their original casing).
installed="$(gh extension list 2>/dev/null | awk -F'\t' '{print tolower($2)}' || true)"

failed=0
for ext in "${EXTENSIONS[@]}"; do
  if printf '%s\n' "$installed" | grep -qxF "$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"; then
    echo "gh-extensions: $ext already installed."
    continue
  fi
  echo "gh-extensions: installing $ext ..."
  if ! gh extension install "$ext"; then
    echo "  ⚠️  failed: $ext (rate limit, or no release build for this platform?)"
    failed=$((failed + 1))
  fi
done

[[ "$failed" -eq 0 ]] || echo "gh-extensions: $failed extension(s) not installed — re-run \`chezmoi apply\` to retry."
exit 0
