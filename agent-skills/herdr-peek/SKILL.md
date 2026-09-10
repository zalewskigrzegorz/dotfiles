---
name: herdr-peek
description: Read the scrollback of a pane in Greg's herdr workspaces on demand, so Claude can see a command + its output — or what an agent in another tab reported — without Greg copy-pasting. Runs `herdr-peek` (wraps `herdr pane read`). No arg grabs the current workspace's shell pane; a bare number (`herdr-peek 8`) targets that workspace's AGENT pane, where the number is the tab index shown in herdr's statusline (▸8). Use when Greg says "co się zawaliło", "co zwróciła ta komenda", "terminal nie przeszło", "zobacz w terminalu", "sprawdź terminal", "co na terminalu", "zobacz w oknie co się stało", "zobacz co agent zgłosił", "co agent na 8 zrobił", "check terminal", "terminal output", "scrollback", "what's on the terminal", "show me the terminal", "see what the agent on tab N reported" — or otherwise refers to a command he just ran, or a numbered tab/agent he wants Claude to look at.
---

# herdr-peek

Read a herdr pane's scrollback so you can see what a command did — or what an agent in another tab reported — without Greg pasting it.

## Background

Greg runs herdr (not tmux). A workspace has the agent pane (where you, Claude, run) plus a plain **shell pane** (nu) where he runs commands. Each workspace also has a **number** (`herdr workspace list` → `"number"`), the same index herdr shows in the tab strip / statusline (`▸8`). `herdr-peek` reads a pane via the herdr socket.

Two ways it resolves a pane:

- **No arg** → the **shell pane** of the *current* workspace (`$HERDR_WORKSPACE_ID`), excluding your own pane. This is for reading a command Greg just ran.
- **A bare number or workspace id** (`herdr-peek 8`, `herdr-peek wM`) → the **agent pane** of *that* workspace. A bare number is the workspace `number` from `herdr workspace list` — the `▸N` in the statusline. This is for "look what the agent on tab N reported". Don't guess the mapping by counting — the script resolves the number itself.

## How to use

1. Run the helper (on PATH, pre-allowed):

   ```
   herdr-peek          # current workspace's shell pane
   herdr-peek 8        # workspace/tab 8's agent pane (statusline ▸8)
   ```

   Default = last **25 lines**. Enough for most cases, low token cost.

2. **Read the output. Decide if it's enough:**
   - **Enough** (command + its error/result visible) → respond: diagnose, propose the fix.
   - **Truncated** (starts mid-error, command not visible, stack trace cut) → ask inline: *"Need more scrollback? I can pull 100 lines."* Don't silently pull more — it costs tokens, his call.

3. On "yes" / "dawaj" / "więcej":

   ```
   herdr-peek -n 100
   ```

   (`-n 50` for a smaller bump.) Read the fuller context and respond.

4. Wrong pane, or need an exact one? Target it verbatim:

   ```
   herdr-peek wM:p3
   ```

   (`herdr pane list` shows pane ids; `herdr workspace list` shows numbers.)

## Errors

- `no pane found for '<N>'` → that workspace number/id isn't live. Run `herdr workspace list` to see the current numbers, don't retry blindly.
- `no shell pane found in this workspace` (no-arg case) → only the agent pane is open, or `$HERDR_WORKSPACE_ID` is unset because you're not in a herdr pane. Tell Greg you can't read it here and ask him to paste or name the pane.

## Scope

- **No-arg reads the shell pane; a number/id reads the agent pane.** Does not read git/nvim TUIs — Greg pastes from those.
- Output is **raw text** (ANSI/prompt lines come through as-is) — read past the 🦄/statusline noise to the actual command + output.
- **Read-only.** Never sends keys or runs commands in Greg's panes.
