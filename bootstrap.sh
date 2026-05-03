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
