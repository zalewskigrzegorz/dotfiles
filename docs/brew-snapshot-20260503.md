# Brew bundle reference

Historical filename kept for links; contents track **`brew/Brewfile.current`** and **`dot_Brewfile.tmpl`**. Last aligned with repo: **2026-05-08**.

## Which file is authoritative?

| File | Role |
|------|------|
| **`dot_Brewfile.tmpl`** | Rendered by chezmoi. Defines taps, formulae, and **workstation macOS casks** for a normal bootstrap (`brew bundle` after apply). |
| **`brew/Brewfile.current`** | Broader snapshot: same cask set (with explicit tap prefixes where used), **extra CLI formulae** not in the minimal template, **VS Code** extensions, plus `cargo` / `npm` entries. Use when reproducing a full dev machine. |

Workstation GUI apps live under the `{{ if eq $profile "workstation" }}` block in `dot_Brewfile.tmpl`. Optional **`setapp`** cask is gated by chezmoi data.

## Formulae (`brew/Brewfile.current`)

Alphabetical by token (tap-qualified names kept as in the bundle):

```text
aria2
asdf
awscli
bash
bat
btop
carapace
cmake
coreutils
deno
direnv
dnsmasq
dust
eza
fd
felixkratz/formulae/borders
felixkratz/formulae/sketchybar
ffmpeg
fish
fnm
fzf
gawk
gh
git
git-delta
gitleaks
gnu-sed
gnupg
go
goaccess
hashicorp/tap/nomad
hashicorp/tap/terraform
hashicorp/tap/vault
htop
hyperfine
idoavrah/homebrew/tftui
jorgerojas26/lazysql/lazysql
jq
just
k6
lazydocker
lazygit
libpq
lnav
logdy
lua
lynx
mise
mkcert
mysql-client
navi
neovim
nnnkkk7/tap/lazyactions
nowplaying-cli
nss
nushell
oven-sh/bun/bun
pam-reattach
peonping/tap/peon-ping
pkgconf
podman
podman-compose
postgresql@14
rclone
ripgrep
rust
sesh
spotify_player
spotifyd
starship
stow
superfile
switchaudio-osx
television
terminal-notifier
tilt
timrogers/tap/litra
tmux
tree
trufflehog
uv
valkyrie00/bbrew/bbrew
vivid
wget
yq
zig
zoxide
zstd
```

## Casks (`brew/Brewfile.current`)

Alphabetical by install name. `aerospace` and `sql-tap` use explicit taps in the bundle file.

```text
1password
1password-cli
bitwarden
chipmunk
clop
comet
datagrip
docker-desktop
firefox@developer-edition
font-fantasque-sans-mono-nerd-font
font-fira-code
font-fira-code-nerd-font
font-hack-nerd-font
font-iosevka-nerd-font
font-opendyslexic-nerd-font
ghostty
google-chrome
google-drive
insomnia
keycastr
logi-options+
mickamy/tap/sql-tap
nikitabobko/tap/aerospace
obsidian
rapidapi
raycast
remarkable
sf-symbols
slack
spotify
superwhisper
via
vlc
wooshy
zed
```

Removed from management (no longer in the bundle): `dbeaver-community`, `discord`, `gitkraken`, `gitkraken-cli`, `iterm2`, `jetbrains-toolbox`, `notion`, `steam`, `steelseries-gg`.

## VS Code / other bundle entries

`brew/Brewfile.current` also pins **VS Code extensions** (`vscode "..."`), **`cargo "mcp-server-nu"`**, and **`npm "corepack"`**. See the file for the full list; it is intentionally long and changes with editor setup.
