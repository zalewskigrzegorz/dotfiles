#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"
repo_url="${DOTFILES_REPO:-git@github.com:zalewskigrzegorz/dotfiles.git}"

if [[ -z "$profile" ]]; then
  case "$(uname -s)" in
    Darwin) profile="workstation" ;;
    Linux) profile="homelab" ;;
    *) profile="workstation" ;;
  esac
fi

case "$profile" in
  workstation|homelab) ;;
  *)
    echo "Unknown profile: $profile" >&2
    echo "Usage: $0 [workstation|homelab]" >&2
    exit 2
    ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
fi

source_dir=""
if [[ -f ".chezmoiignore" && -d ".git" ]]; then
  source_dir="$(pwd)"
fi

chezmoi_config_dir="$HOME/.config/chezmoi"
mkdir -p "$chezmoi_config_dir"
{
  if [[ -n "$source_dir" ]]; then
    printf 'sourceDir = "%s"\n\n' "$source_dir"
  fi
  cat <<TOML
# Pin the umask so directory modes do not depend on WHICH shell ran chezmoi.
# Unpinned, chezmoi inherits the caller's umask: an apply from a umask-077
# context writes every managed dir 0700, the next apply from umask-022 wants
# 0755 back, and \`chezmoi status\` fills with ~800 rows of pure mode churn that
# buries real drift (see dot_config/nushell/autoload/chezmoi.nu on why --force
# used to be the only way past it). 0o022 → dirs 0755, files 0644; \`private_*\`
# entries still get 0700/0600.
umask = 0o022

[data]
profile = "$profile"
TOML
} > "$chezmoi_config_dir/chezmoi.toml"

if [[ -n "$source_dir" ]]; then
  chezmoi init --source "$source_dir"
else
  chezmoi init "$repo_url"
fi

chezmoi apply
