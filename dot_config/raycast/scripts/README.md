# Raycast Script Commands

## Installation

1. Open Raycast.
2. Go to **Raycast Settings** → **Extensions** → **Script Commands**.
3. Click **Add Script Directory**.
4. Select `~/.config/raycast/scripts`.

The dotfiles compatibility hook also copies these scripts into
`~/raycast/script-commands` and
`~/raycast/script-commands/commands/dotfiles` because that is the legacy layout
Raycast may already have configured. It also keeps real script files in
`~/Code/Labs/shortcuts` because older Raycast preferences may still point there.

## Available Scripts

- `clearGithubNotification.sh` - mark GitHub notifications as read.
- `create-new-branch.sh` - update `main` and create a typed branch in the REDACTED_ORG repo.
- `navi-cheatsheets-nu.nu` - search Navi cheatsheets from Raycast.
- `run-e2e-on-github.sh` - trigger GitHub E2E by toggling the `run_e2e` label.
