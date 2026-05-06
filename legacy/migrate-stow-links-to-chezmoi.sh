#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/migrate-stow-links-to-chezmoi.sh [--apply] [--repo PATH]

Removes only legacy Stow symlinks that point into this dotfiles repo.
Without --apply it prints what would change.
USAGE
}

apply=false
repo=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=true
      ;;
    --repo)
      repo="${2:?missing value for --repo}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$repo" ]]; then
  repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

repo_real="$(cd "$repo" && pwd -P)"
timestamp="$(date +%Y%m%d_%H%M%S)"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
backup_dir="${state_home}/dotfiles/stow-link-migration-${timestamp}"
report="${backup_dir}/links.txt"

paths=(
  "$HOME/.claude"
  "$HOME/.cursor/settings.json"
  "$HOME/.config/aerospace"
  "$HOME/.config/borders"
  "$HOME/.config/btop"
  "$HOME/.config/carapace"
  "$HOME/.config/cursor"
  "$HOME/.config/flipperdevices.com"
  "$HOME/.config/gh"
  "$HOME/.config/gh-dash"
  "$HOME/.config/ghostty"
  "$HOME/.config/lazy-github"
  "$HOME/.config/lazydocker"
  "$HOME/.config/lazygit"
  "$HOME/.config/lynx"
  "$HOME/.config/navi"
  "$HOME/.config/nushell"
  "$HOME/.config/nvim"
  "$HOME/.config/raycast"
  "$HOME/.config/sketchybar"
  "$HOME/.config/spotify-player"
  "$HOME/.config/starship"
  "$HOME/.config/superfile"
  "$HOME/.config/svim"
  "$HOME/.config/television"
  "$HOME/.config/tmux"
  "$HOME/.config/zellij"
  "$HOME/.config/zed"
  "$HOME/nushell-mcp.json"
)

is_repo_link() {
  local path="$1"
  [[ -L "$path" ]] || return 1

  local target
  target="$(readlink "$path")"
  if [[ "$target" != /* ]]; then
    target="$(cd "$(dirname "$path")" && pwd -P)/$target"
  fi
  target="$(python3 -c 'import os, sys; print(os.path.normpath(sys.argv[1]))' "$target")"

  [[ "$target" == "$repo_real"/* ]]
}

mkdir -p "$backup_dir"
{
  echo "# Stow link migration"
  echo
  echo "repo: $repo_real"
  echo "apply: $apply"
  echo "date: $(date '+%Y-%m-%dT%H:%M:%S%z')"
  echo
} > "$report"

found=false
for path in "${paths[@]}"; do
  if is_repo_link "$path"; then
    found=true
    target="$(readlink "$path")"
    printf '%s -> %s\n' "$path" "$target" | tee -a "$report"
    if [[ "$apply" == true ]]; then
      rm "$path"
    fi
  elif [[ -e "$path" && ! -L "$path" ]]; then
    printf 'skip non-symlink: %s\n' "$path" | tee -a "$report"
  fi
done

if [[ "$found" == false ]]; then
  echo "No legacy Stow symlinks pointing into $repo_real were found." | tee -a "$report"
fi

if [[ "$apply" == true ]]; then
  echo "Removed legacy Stow symlinks. Report: $report"
else
  echo "Dry run only. Re-run with --apply to remove listed links. Report: $report"
fi
