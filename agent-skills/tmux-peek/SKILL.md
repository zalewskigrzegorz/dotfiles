---
name: tmux-peek
description: Read the scrollback of Greg's terminal tmux window (window 1) on demand, so Claude can see a command + its output without Greg copy-pasting. Runs `tmux-peek` to grab the last ~25 lines of the terminal window in the current tmux session, then Claude reads them and only asks for more if the context is truncated. Use when Greg says "co się zawaliło", "co zwróciła ta komenda", "terminal nie przeszło", "zobacz w terminalu", "sprawdź terminal", "co na terminalu", "check terminal", "terminal output", "scrollback", "what's on the terminal", "show me the terminal" — or otherwise refers to a command he just ran in his shell window that failed or whose output Claude needs to see. Terminal window only; for git/hunk/nvim windows Greg copy-pastes.
---

# tmux-peek

Read Greg's terminal window scrollback so you can see what a command did without him pasting it.

## Background

Greg's tmux layout per session: **window 1 = terminal (nu)**, 2 = git, 3 = Claude (where you run), 4 = hunk, 5 = nvim. Window *numbers* drift across sessions for everything except the terminal — window 1 is reliably the shell in every session. The `tmux-peek` helper resolves the **current** session via `tmux display-message -p '#S'` (correct even with several sessions attached at once) and captures window 1.

## How to use

1. Run the helper (it's on PATH and pre-allowed):

   ```
   tmux-peek
   ```

   Default = last **25 lines** of the terminal window. That's enough for most "this command failed" cases and keeps token cost minimal.

2. **Read the output. Decide if it's enough:**
   - **Enough** (the command + its error/result are visible) → respond. Diagnose, propose the fix, whatever Greg asked.
   - **Truncated** (output starts mid-error, you can't see the command that caused it, a stack trace is cut off) → ask Greg inline: *"Need more scrollback? I can pull 100 lines."* Do **not** silently pull more — pagination is his call, it costs tokens.

3. On Greg's "yes" / "dawaj" / "więcej", pull more:

   ```
   tmux-peek -n 100
   ```

   (`-n 50` for a smaller bump.) Then read the fuller context and respond.

## Not in tmux?

If `tmux-peek` prints `Error: Not in a tmux session` (e.g. you're on the lab outside tmux), tell Greg you can't read the terminal window here and ask him to paste the output instead. Don't retry.

## Scope

- **Terminal window only** (window 1). This skill does not read git/hunk/nvim — those are TUIs and Greg pastes from them if needed.
- Output is **raw text** — ANSI colors / prompt lines come through as-is. Read past the prompt/statusline noise to the actual command and output.
- This is **read-only**. It never sends keys or runs commands in Greg's terminal.
