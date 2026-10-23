---
paths:
  - "dot_config/aerospace/**"
  - "dygma/**"
  - "dot_claude/exact_commands/dygma.md"
---

# AeroSpace × Dygma: a window "znika" after a layer switch

Bazecor's **Layer Lens** sends `ctrl+<digit>` when the Defy changes layer, and `aerospace.toml` binds `ctrl-1`…`ctrl-9` to workspaces. So a layer switch jumps the workspace, and the window (Slack) seems to vanish. Nothing in the code or history shows this link; finding it took ~25 calls (b33cce3d, 2026-10-23).

Diagnose: a `bash` script in the scratchpad that logs `aerospace list-windows --focused` every 0.5 s for ~45 s while Greg switches layers (not an inline zsh loop).

Fix options, none chosen yet: turn off the keystroke in Layer Lens settings, move the workspace bindings off `ctrl+<digit>` in `aerospace.toml`, or disable Layer Lens. Record the chosen one here.
