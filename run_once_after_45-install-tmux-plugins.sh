#!/usr/bin/env bash
set -euo pipefail

# TPM + plugins are not stored in this repo. After chezmoi applies tmux.conf,
# window icons/names from tmux-nerd-font-window-name only appear once plugins
# are installed and the terminal uses a Nerd Font.

TPM_DIR="${HOME}/.config/tmux/plugins/tpm"

if ! command -v git >/dev/null 2>&1; then
  echo "Skipping TPM bootstrap: git not found."
  exit 0
fi

mkdir -p "${HOME}/.config/tmux/plugins"

if [[ ! -f "${TPM_DIR}/tpm" ]]; then
  rm -rf "${TPM_DIR}"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "${TPM_DIR}"
fi

if [[ -x "${TPM_DIR}/scripts/install_plugins.sh" ]]; then
  "${TPM_DIR}/scripts/install_plugins.sh" || true
fi
