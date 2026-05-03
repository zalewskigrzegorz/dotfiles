# Stow Links Before Chezmoi

Captured before removing legacy Stow symlinks.

## macOS Workstation

- `~/.claude -> ~/Code/dotfiles/.claude`
- `~/.config/aerospace -> ~/Code/dotfiles/.config/aerospace`
- `~/.config/borders -> ~/Code/dotfiles/.config/borders`
- `~/.config/btop -> ~/Code/dotfiles/.config/btop`
- `~/.config/carapace -> ~/Code/dotfiles/.config/carapace`
- `~/.config/cursor -> ~/Code/dotfiles/.config/cursor`
- `~/.config/flipperdevices.com -> ~/Code/dotfiles/.config/flipperdevices.com`
- `~/.config/gh -> ~/Code/dotfiles/.config/gh`
- `~/.config/ghostty -> ~/Code/dotfiles/.config/ghostty`
- `~/.config/lazy-github -> ~/Code/dotfiles/.config/lazy-github`
- `~/.config/lazydocker -> ~/Code/dotfiles/.config/lazydocker`
- `~/.config/lazygit -> ~/Code/dotfiles/.config/lazygit`
- `~/.config/lynx -> ~/Code/dotfiles/.config/lynx`
- `~/.config/navi -> ~/Code/dotfiles/.config/navi`
- `~/.config/nushell -> ~/Code/dotfiles/.config/nushell`
- `~/.config/nvim -> ~/Code/dotfiles/.config/nvim`
- `~/.config/sketchybar -> ~/Code/dotfiles/.config/sketchybar`
- `~/.config/spotify-player -> ~/Code/dotfiles/.config/spotify-player`
- `~/.config/starship -> ~/Code/dotfiles/.config/starship`
- `~/.config/superfile -> ~/Code/dotfiles/.config/superfile`
- `~/.config/svim -> ~/Code/dotfiles/.config/svim`
- `~/.config/television -> ~/Code/dotfiles/.config/television`
- `~/.config/tmux -> ~/Code/dotfiles/.config/tmux`
- `~/.config/zed -> ~/Code/dotfiles/.config/zed`
- `~/nushell-mcp.json -> ~/Code/dotfiles/nushell-mcp.json`

## Debian Homelab

Host: `greg@192.168.50.10`

- `~/.config/aerospace -> /opt/dotfiles/.config/aerospace`
- `~/.config/ghostty -> /opt/dotfiles/.config/ghostty`
- `~/.config/nushell -> /opt/dotfiles/.config/nushell`
- `~/.config/nvim -> /opt/dotfiles/.config/nvim`
- `~/.config/tmux -> /opt/dotfiles/.config/tmux`
- `~/.config/sketchybar` missing
- `~/.claude` missing

Use `legacy/migrate-stow-links-to-chezmoi.sh --apply --repo <repo>` on each host before the first `chezmoi apply`. Reports are written under `~/.local/state/dotfiles/`.
