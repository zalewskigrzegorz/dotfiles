# New Mac

The order that worked when NeuroMancer was replaced by Wintermute (2026-10-19).
Steps 1–3 happen on the old Mac, the rest on the new one.

## Before: on the old Mac

1. **Hand over two files** that are not in the repo: `~/.config/chezmoi/chezmoi.toml`
   (vault name, `privateEnvVars`, `[onepassword] mode = "service-account"`; no secrets)
   and the service-account token `~/.config/op/sa-token`. The token is also in
   1Password as "Service Account Auth Token". Easiest transfer: SSH (step 6), or
   iCloud Drive for the toml only.
2. **Raycast:** set an export passphrase under Settings → Advanced → Export first
   (export itself never asks for one), then "Export Settings & Data". Copying the
   Raycast data folder does not work, the database is encrypted with a Keychain key.
3. **Browser extensions:** Comet drops copied extensions on a new machine (the
   extension list is signed per machine). Export what has settings: Vimium,
   uBlock Origin Lite, SponsorBlock, Stylus. Tampermonkey had one KSeF script.

## On the new Mac

4. `xcode-select --install`, then clone over HTTPS (no SSH key yet):
   `git clone https://github.com/zalewskigrzegorz/dotfiles.git ~/Code/dotfiles`
5. `cd ~/Code/dotfiles && ./bootstrap.sh workstation` (stage 00 caches sudo itself).
   The first apply skips the private restore, that is expected.
6. Turn on Remote Login and add `curl -fsSL https://github.com/zalewskigrzegorz.keys >> ~/.ssh/authorized_keys`,
   so the old Mac can push files and run commands. The new Mac's default shell
   becomes nushell: wrap remote commands as `ssh host sh -s <<'EOF' … EOF` and use
   `rsync -s --rsync-path=/opt/homebrew/bin/rsync`.
7. Put `chezmoi.toml` in `~/.config/chezmoi/` (add `setapp = true`) and the token
   in `~/.config/op/sa-token` (mode 600), then `chezmoi apply`.
8. `chsh -s /opt/homebrew/bin/nu` (after adding it to `/etc/shells`). Touch ID for
   sudo comes from stage 13 when apply runs in a terminal.
9. 1Password app → Settings → Developer → **Use the SSH agent**. The GitHub key was
   a file, not in 1Password, so the new Mac got its own: `ssh-keygen -t ed25519`,
   then `gh auth login -p ssh` uploads it. Add it to the lab's `authorized_keys`.
10. If `gh` was logged in after the first apply, rerun
    `bash run_onchange_after_35-gh-extensions.sh` (stage 35 skips when gh is logged out).
11. Setapp: the lab AdGuard blocked `setapp.com`/`devmate.com`; allow rules now exist.
    "No internet" in Setapp/Safari was a stale system proxy `127.0.0.1:9090` from
    Proxyman: `networksetup -setwebproxystate <service> off` (and `-setsecurewebproxystate`).
12. App data that copies fine as folders (app closed on both Macs): Comet profile
    (logins and extensions do not survive), Stream Deck, Insomnia, Jam SQL Studio,
    Firefox Developer Edition, and Setapp apps' Preferences/Application Support/Containers.
13. Comet: reinstall extensions from the Web Store, import the exports from step 3,
    link sync via `comet://settings/synchronisation` ("Start new sync" / "Join sync").
14. Clone the repos you work in (bazgroly, home-lab, homeassistant-config, the work monorepo).

Afterwards: regenerate the 1Password Secret Key if it was typed anywhere, and turn
Remote Login off.
