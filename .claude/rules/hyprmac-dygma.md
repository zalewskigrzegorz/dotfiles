---
paths:
  - "bin/hyprmac-config"
  - "dygma/**"
  - "dot_claude/exact_commands/dygma.md"
---

# HyprMac × Dygma: a window "znika" after a layer switch

Bazecor's **Layer Lens** sends `ctrl+<digit>` when the Defy changes layer, and HyprMac binds `ctrl+1`…`ctrl+0` (Hypr key = left Control) to workspaces. So a layer switch jumps the workspace, and the window (Slack) seems to vanish. It was first found under AeroSpace, which had the same bindings; nothing in the code or history shows this link and finding it took ~25 calls (b33cce3d, 2026-10-23).

Diagnose: a `bash` script in the scratchpad that logs the focused window every 0.5 s for ~45 s while Greg switches layers (not an inline zsh loop). Read `focusedWorkspace` from `~/Library/Application Support/HyprMac/state.json` (HyprMac's status export).

Fix options, none chosen yet: turn off the keystroke in Layer Lens settings, move the workspace keybinds off `ctrl+<digit>` (they are merged into HyprMac's config by `bin/hyprmac-config`), or disable Layer Lens. Record the chosen one here.
