---
name: tuios-peek
description: Read the scrollback of a window in Greg's tuios sessions on demand, so Claude can see a command + its output — or what an agent in another session reported — without Greg copy-pasting. Runs `tuios-peek` (wraps `tuios capture-pane`). No arg grabs the current session's shell window; a bare number (`tuios-peek 8`) targets that session's AGENT window, where the number is the session's position in `tuios ls` shown in the statusline (▸8). Use when Greg says "co się zawaliło", "co zwróciła ta komenda", "terminal nie przeszło", "zobacz w terminalu", "sprawdź terminal", "co na terminalu", "zobacz w oknie co się stało", "zobacz co agent zgłosił", "co agent na 8 zrobił", "tuios peek", "check terminal", "terminal output", "scrollback", "what's on the terminal", "show me the terminal", "see what the agent on session N reported" — or otherwise refers to a command he just ran, or a numbered session/agent he wants Claude to look at.
---

# tuios-peek

Read a tuios window's scrollback so you can see what a command did — or what an agent in another session reported — without Greg pasting it.

## Background

Greg runs tuios (not tmux). A session (one per repo+branch worktree, e.g. `repo-feat-x`) has the agent window (where you, Claude, run) plus a plain **shell window** (nu) where he runs commands. Each session has a **number**: its 1-based position in `tuios ls --json`, the same index the statusline shows (`▸8`). `tuios-peek` reads a window with `tuios capture-pane`.

How it resolves a window:

- **No arg** → the **shell window** of the *current* session (`$TUIOS_SESSION`), excluding your own window (`$TUIOS_PANE_ID`). For reading a command Greg just ran.
- **A bare number or a session name** (`tuios-peek 8`, `tuios-peek repo-feat-x`) → the **agent window** of *that* session. Don't guess the number by counting — the script resolves it itself.
- **A target with a `:`** (`tuios-peek repo-feat-x:3`) → an exact window, passed to `tuios capture-pane -w` as is, no lookup.

## How to use

1. Run the helper (on PATH, pre-allowed):

   ```
   tuios-peek          # current session's shell window
   tuios-peek 8        # session 8's agent window (statusline ▸8)
   ```

   Default = last **25 lines**. Enough for most cases, low token cost.

2. **Read the output. Decide if it's enough:**
   - **Enough** (command + its error/result visible) → respond: diagnose, propose the fix.
   - **Truncated** (starts mid-error, command not visible, stack trace cut) → ask inline: *"Need more scrollback? I can pull 100 lines."* Don't silently pull more — it costs tokens, his call.

3. On "yes" / "dawaj" / "więcej":

   ```
   tuios-peek -n 100
   ```

   (`-n 50` for a smaller bump.) Read the fuller context and respond.

4. Wrong window, or need an exact one? Target it verbatim:

   ```
   tuios-peek repo-feat-x:3
   ```

   (`tuios list-windows -s <session>` shows window ids and indexes; `tuios ls` shows the sessions in order.)

## Errors

- `no pane found for '<N>'` → that session number/name isn't live. Run `tuios ls` to see the current ones, don't retry blindly.
- `no shell pane found in this session` (no-arg case) → only the agent window is open, or `$TUIOS_SESSION` is unset because you're not in a tuios pane. Tell Greg you can't read it here and ask him to paste or name the window.

## Scope

- **No-arg reads the shell window; a number/name reads the agent window.** Does not read git/nvim TUIs — Greg pastes from those.
- Output is **raw text** (ANSI/prompt lines come through as-is) — read past the statusline noise to the actual command + output.
- A pane stuck on an approval prompt: `tuios peek-prompt -s <session> -w <window>` prints the prompt itself (read-only). Answering it is Greg's, or `respond` with his go-ahead.
- **Read-only.** Never sends keys or runs commands in Greg's windows.
