---
name: herdr-peek
description: Read the scrollback of Greg's terminal/shell pane in his herdr workspace on demand, so Claude can see a command + its output without Greg copy-pasting. Runs `herdr-peek` (wraps `herdr pane read`) to grab the last ~25 lines of the non-agent shell pane in the current herdr workspace, then Claude reads them and only asks for more if truncated. Use when Greg says "co się zawaliło", "co zwróciła ta komenda", "terminal nie przeszło", "zobacz w terminalu", "sprawdź terminal", "co na terminalu", "zobacz w oknie co się stało", "check terminal", "terminal output", "scrollback", "what's on the terminal", "show me the terminal" — or otherwise refers to a command he just ran in a shell pane whose output Claude needs to see. Shell pane only; for git/hunk/nvim Greg copy-pastes.
---

# herdr-peek

Read Greg's shell-pane scrollback so you can see what a command did without him pasting it. herdr replacement for the old tmux-peek.

## Background

Greg runs herdr (not tmux). A workspace has the agent pane (where you, Claude, run) plus a plain **shell pane** (nu) where he runs commands. `herdr-peek` reads that shell pane via the herdr socket — it auto-picks the non-agent pane (`agent_status == "unknown"`) in the **current** workspace (`$HERDR_WORKSPACE_ID`), excluding your own pane.

## How to use

1. Run the helper (on PATH, pre-allowed):

   ```
   herdr-peek
   ```

   Default = last **25 lines** of the workspace's shell pane. Enough for most "this command failed" cases, low token cost.

2. **Read the output. Decide if it's enough:**
   - **Enough** (command + its error/result visible) → respond: diagnose, propose the fix.
   - **Truncated** (starts mid-error, command not visible, stack trace cut) → ask inline: *"Need more scrollback? I can pull 100 lines."* Don't silently pull more — it costs tokens, his call.

3. On "yes" / "dawaj" / "więcej":

   ```
   herdr-peek -n 100
   ```

   (`-n 50` for a smaller bump.) Read the fuller context and respond.

4. Wrong pane / multiple shells in the workspace? Target one explicitly:

   ```
   herdr-peek w2:p1
   ```

   (`herdr pane list` shows pane ids + workspaces.)

## Not in herdr / no shell pane

If `herdr-peek` prints `no shell pane found in this workspace` (e.g. only the agent pane is open, or `$HERDR_WORKSPACE_ID` is unset because you're not in a herdr pane), tell Greg you can't read it here and ask him to paste, or to name the pane. Don't retry blindly.

## Scope

- **Shell panes only.** Does not read git/hunk/nvim TUIs — Greg pastes from those.
- Output is **raw text** (ANSI/prompt lines come through as-is) — read past the 🦄/statusline noise to the actual command + output.
- **Read-only.** Never sends keys or runs commands in Greg's panes.
