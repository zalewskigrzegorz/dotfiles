---
description: a Haiku hook titles Claude tabs; call os-title only when that title would mislead
alwaysApply: true
---

# tuios Tab Title: the Haiku hook owns Claude tabs, `os-title` is the override

The Stop hook `dot_claude/hooks/stop/tuios-claude-title.sh` gives every Claude tab a 3–4 word essence of the task ("Fix: work nie dodaje taba") after the first answer, then at most once per 3 prompts or 10 min, through `os-title` (tuios workspace name, agent window name, statusline). Non-Claude tabs keep the shell's name; there is no other auto-title plugin (the nushell icon wrappers for `nvim`/`lg`/`dash` were removed: nvim drew nothing through them).

**Default: do nothing**, no `os-title` at checkpoints. A title set by hand is sticky (the hook never overwrites a title that differs from its last `.auto` write; `/clear` resets both), so call `os-title "<3–4 words, PL or EN>"` only when the Haiku title is actively wrong, with words that stay true for the rest of the session. Fire-and-forget, safe outside tuios; trimmed to 30 chars for the tab (`CLAUDE_TUIOS_TITLE_MAX`). One manual pass for an open session: `CLAUDE_CODE_SESSION_ID=<sid> TUIOS_ENV=1 TUIOS_PANE_ID=<window-id> tuios-claude-title.sh --retitle <transcript>`.
