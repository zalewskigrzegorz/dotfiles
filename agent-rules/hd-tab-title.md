---
description: herdr-auto-title names tabs by default; call hd-title only when the auto name would mislead
alwaysApply: true
---

# herdr Tab Title — auto-title owns it, `hd-title` is the override

Since 2026-09-17 the **`herdr.auto-title` plugin** names every tab and pane after
the work in them, twice a second: `dashboard › claude › Implement OAuth scopes`,
`nvim › auth.provider.ts`, `ssh › prod-01`. It reads the real session, so it is
almost always more accurate than a title you'd guess.

**Default: do nothing.** Do not call `hd-title` at every checkpoint any more.

## The one-way door

`hd-title` calls `herdr tab rename`, and **auto-title permanently stops touching
a tab someone renamed by hand**. So every `hd-title` call trades a live,
self-updating title for a frozen one that only you will ever refresh. Clearing
the name hands the tab back to auto-title.

## When `hd-title` is still right

Two cases, both rare:

- **The statusline segment.** `hd-title` writes a second surface auto-title
  can't see: `$XDG_STATE_HOME/dotfiles/claude-session-title/<session-id>`, which
  the statusline's `win_seg` reads and colours per session. If Greg is working
  off the statusline rather than the tab strip, that store needs a write.
- **The auto name is actively wrong** — a long session whose tab still reads as
  the repo you started in, or work whose point isn't visible in the paths and
  branch (a spike, a migration spanning repos, an investigation).

Otherwise: leave it. A stale-looking tab for a few seconds is cheaper than a
tab frozen for the rest of the session.

## How, when you do

```bash
hd-title "deslop gate rollout"
```

- 3–5 words, the *current* focus, PL or EN.
- Fire-and-forget, non-blocking, safe outside herdr.
- Trimmed to 24 chars for the tab (`CLAUDE_HERDR_TITLE_MAX`); the statusline
  store keeps the full text.
