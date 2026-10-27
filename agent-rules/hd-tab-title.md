---
description: a Haiku hook titles Claude tabs; call hd-title only when that title would mislead
alwaysApply: true
---

# tuios Tab Title — the Haiku hook owns Claude tabs, `hd-title` is the override

Since 2026-10-21 the Stop hook `dot_claude/hooks/stop/tuios-claude-title.sh`
gives every Claude tab a 3–4 word essence of the task ("Fix: work nie dodaje
taba", "Review: łączenie zespołów SSO"). After the first answer, and then at
most once per 3 prompts or 10 min, Haiku reads the recent conversation and
keeps or replaces the title, through `hd-title`: the tuios workspace name
(`tuios set-workspace-name`, the tab strip), the agent window name
(`tuios set-window --name`, the rail's agent row) and the statusline alike. Greg's words: the first prompt and the workspace › topic format "nic
nie mówi".

Tabs without Claude keep the name the shell gives them, except `lg`, `dash`,
`nvim` and friends: `zz-tuios-tui-wrappers.nu` renames the workspace to an icon
while the TUI runs and restores it after. There is no auto-title plugin any more.

**Default: do nothing.** Do not call `hd-title` at checkpoints.

## The override is sticky

A title you set with `hd-title` differs from what the hook last wrote
(`claude-session-title/<sid>.auto`), and the hook never overwrites it again in
that session. `/clear` drops both and hands the tab back to auto-title until
the next answer. So call it only when the Haiku title is actively wrong, and
pick words that stay true for the rest of the session.

## How, when you do

```bash
hd-title "deslop gate rollout"
```

- 3–4 words, what Greg wants done, PL or EN.
- Fire-and-forget, non-blocking, safe outside tuios (it then only writes the statusline store).
- Trimmed to 30 chars for the tab (`CLAUDE_TUIOS_TITLE_MAX`); the statusline
  store keeps the full text.
- One pass by hand for an open session:
  `CLAUDE_CODE_SESSION_ID=<sid> TUIOS_ENV=1 TUIOS_PANE_ID=<window-id> tuios-claude-title.sh --retitle <transcript>`.
