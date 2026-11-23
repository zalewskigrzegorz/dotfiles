---
name: tuios-peek
description: Read the scrollback of a window in Greg's tuios sessions so Claude sees a command and its output, or what an agent in another session reported, without copy-paste. Runs `tuios-peek` (wraps `tuios capture-pane`); no arg = current session's shell window, a number (`tuios-peek 8`, statusline ▸8) = that session's agent window. Use on "co się zawaliło", "co zwróciła ta komenda", "terminal nie przeszło", "zobacz w terminalu", "sprawdź terminal", "co na terminalu", "zobacz w oknie co się stało", "zobacz co agent zgłosił", "co agent na 8 zrobił", "tuios peek", "check terminal", "terminal output", "scrollback", "what's on the terminal", "show me the terminal", "see what the agent on session N reported", or any command he just ran.
---

# tuios-peek

A session (one per repo+branch) has the agent window plus a nu **shell window**. Its number is its 1-based position in `tuios ls --json`, shown in the statusline (`▸8`).

```
tuios-peek                 # shell window of $TUIOS_SESSION, excluding your own $TUIOS_PANE_ID
tuios-peek 8               # agent window of session 8 (or a session name); the script resolves it, don't count
tuios-peek repo-feat-x:3   # exact window, passed to capture-pane -w as is
tuios-peek -n 100          # more lines (default 25)
```

- Output enough (command + result visible) → diagnose. Truncated (mid-error, no command) → ask "Need more scrollback? I can pull 100 lines." and pull only on his yes ("dawaj", "więcej"); `-n 50` for a smaller bump.
- Ids: `tuios list-windows -s <session>`; order: `tuios ls`.
- `no pane found for '<N>'` → not live; `tuios ls`, no blind retry. `no shell pane found in this session` → only the agent window, or not in a tuios pane: ask him to paste or name the window.
- Raw text with ANSI/prompt noise. Doesn't read git/nvim TUIs (he pastes those).
- Pane stuck on an approval prompt: `tuios peek-prompt -s <session> -w <window>` prints it; answering is Greg's (or `respond` with his go-ahead).
- **Read-only**: never sends keys or runs commands in his windows.
