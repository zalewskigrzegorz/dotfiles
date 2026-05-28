---
name: console-ninja
description: Use when debugging a runtime bug in a running app — a 500 from a dev server, an exception, a blank page, "check the logs", a stack trace, a frontend error in the browser — instead of asking the user to paste terminal output, adding `console.log` to source code, or tailing files. Console Ninja captures the app's logs + runtime errors and exposes them via `mcp__console-ninja__*`. Also use when the MCP suddenly returns nothing after the user switched branches or rebuilt — that means the Console Ninja runtime hook detached and the dev server must be relaunched via the `console-ninja` CLI wrapper.
---

# console-ninja

## Core principle

The user runs Console Ninja in VS Code or Cursor. It captures every `console.log` / `console.error` plus uncaught exceptions from the running app (Node server, Next.js, Vite, browser) and exposes them via MCP. **Hitting the MCP replaces "paste your terminal output," replaces "let me add a few console.logs," and replaces tailing files.** Don't bypass it.

## CN architecture (mental model)

CN has three moving parts and **all three must be aligned** for MCP to return data:

1. **Editor extension** in VS Code or Cursor. Hosts the per-project "host worker" that buffers logs/errors. Each project gets a port (see `~/.console-ninja/hostRegister.json`). **If the editor is closed, the project goes `paused: true` and the host worker dies.** No editor running → no data.
2. **Runtime hook** at `~/.console-ninja/.bin/loader.js`. Loaded into the user's Node process via `NODE_OPTIONS=--require <loader>`. The real shell wrapper is `~/.console-ninja/.bin/console-ninja` (PATH-prepended via `.bashrc`/`.zshrc`). The hook sends every log/error to the editor's host worker over the project's port.
3. **MCP server** at `~/.console-ninja/mcp/index.js` (spawned per Claude/agent session). Reads from the editor's host worker. **It does not read from the runtime hook directly** — the editor sits in between.

**Consequence:** CN is fundamentally not headless. Closing VS Code/Cursor breaks the loop even if the runtime hook still loads cleanly. (Wallaby has a true standalone mode; CN does not — feature draft saved in `bazgroly/dotfiles/notes/2026-05-28-cn-headless-feature-request-draft.md`.)

**Two wrappers exist, only one works:**

- `~/.console-ninja/.bin/console-ninja` — **real one**, has the correct loader path. Picked up via PATH because `.bashrc`/`.zshrc` prepend `~/.console-ninja/.bin`.
- `~/Library/pnpm/global/.../console-ninja@1.0.0/.../shell/console-ninja` — **broken**, still has `<REPLACE>` placeholder. If a shell context (e.g. nushell, or a script that resets PATH) picks this one up, you get `Error: Cannot find module '<REPLACE>'`. If you see that error, use the absolute path: `~/.console-ninja/.bin/console-ninja <cmd>`.

## Hard rules

When the user describes a runtime bug in an app that is already running:

1. **First tool call is `mcp__console-ninja__runtime-logs-and-errors`** (or `runtime-errors` if the user specifically said "error/exception/500"). Not Grep, not Read, not `git status` — those come after you have the concrete error.
2. **Never add `console.log` statements** to source as a debugging tactic. CN captures the existing logs and runtime values without code edits.
3. **Never ask the user to paste their terminal output or browser console.** That's what the MCP is for. If it's empty, follow the relaunch flow below; don't fall back to paste-requests silently.
4. **Never `pkill` / `kill` a process without confirming the PID and command** with the user first. Wrong target = killed tmux / browser / wallaby / something.

## Tool map

- `mcp__console-ninja__runtime-logs-and-errors` — default starting point. Combined view.
- `mcp__console-ninja__runtime-errors` — errors only. Use when user said "error/exception/500".
- `mcp__console-ninja__runtime-logs` — logs only.
- `mcp__console-ninja__runtime-error-by-id` — full detail on one error (use `id` from `runtime-errors`).
- `mcp__console-ninja__runtime-error-by-location` / `runtime-logs-by-location` — scoped to a file:line.

## Diagnosing empty MCP — three possible causes, three different fixes

When `mcp__console-ninja__runtime-logs-and-errors` returns `<No data available>`, do NOT assume it's "branch switch detached the hook" by default. There are three distinct causes; pick the right diagnosis before suggesting a fix.

### Cause A — Editor isn't running (host worker dead)

Symptom: VS Code / Cursor is closed. The project's entry in `~/.console-ninja/hostRegister.json` is `paused: true`.

Check:
```bash
grep -o '"[^"]*<project-basename>[^"]*":{[^}]*}' ~/.console-ninja/hostRegister.json
```

Fix: ask user to open the project in VS Code or Cursor — that boots the host worker. State plainly: "CN host worker is dead because the editor is closed. Open the project in Cursor/VS Code so CN can stream data, then I'll retry the MCP." Don't try to start the host worker from CLI (no public way as of CN v1.0.528).

### Cause B — Editor running but project paused

Symptom: editor is open but project's `paused: true` in `hostRegister.json`. Common after re-opening a project — CN doesn't auto-unpause.

Fix: ask user to click the CN icon in the editor status bar → "Tracker: ON" / "Enable Console Ninja" for this project. One click. Retry MCP after.

### Cause C — Editor + project both active, but the running app process is not hooked

This is the original "branch switch / rebuild" case. Editor is on, project is unpaused, but the dev server process was started outside the CN wrapper (or restarted automatically without it). The runtime hook never loaded into that process.

Symptom: editor open, project unpaused in `hostRegister.json`, but MCP still empty AND there is a running dev server (`pgrep -fl 'next dev|vite|nodemon|tsx watch|node .*server'`).

Fix — relaunch through the wrapper:

1. Find PID:
   ```bash
   pgrep -fl 'next dev|vite|nodemon|tsx watch|node .*server'
   ```
2. Confirm with user (one line: "Kill PID X (`next dev`) and relaunch through `console-ninja` so the runtime hook loads — OK?"). Wait for yes.
3. `kill <pid>`.
4. Relaunch through the wrapper:
   ```bash
   console-ninja npm run dev
   # or: console-ninja pnpm dev / yarn dev / tsx watch src/server.ts / …
   ```
   Use the bare command `console-ninja` (PATH picks the working `~/.console-ninja/.bin/` shim). If that fails with `Cannot find module '<REPLACE>'`, the wrong wrapper was picked — use absolute path: `~/.console-ninja/.bin/console-ninja npm run dev`.
5. Wait for "ready"/"listening", retry MCP.

### Browser-only apps (no Node server, e.g. plain Vite SPA)

There is no CLI wrapper for pure-browser capture. CN's editor extension injects a script tag via the dev-server proxy when the extension is enabled AND the project is unpaused. If MCP is empty:

1. Verify causes A/B aren't in play (editor running + project unpaused).
2. If both OK, tell the user: "CN browser capture may need a refresh — hard-reload the page (Cmd+Shift+R) so the injected script reloads."
3. Retry MCP.

## Red flags — stop and diagnose

| Thought | Reality |
|---|---|
| "Let me read the route handler first to spot the bug" | Read it **after** the MCP gives you the error + stack. Otherwise you're guessing. |
| "I'll have the user paste the dev-server output" | The MCP exposes that without manual paste. |
| "Let me sprinkle a few `console.log`s and rerun" | CN already captures every existing log. Adding more pollutes source. |
| "MCP empty — must be branch-switch detach, run the wrapper" | Three possible causes. Check `hostRegister.json` first; relaunch wrapper only fixes Cause C. |
| "I'll just restart `npm run dev`" | A bare restart does NOT re-attach the CN hook. Use `console-ninja npm run dev` (Cause C only). |
| "I'll start CN headlessly from the CLI" | CN has no headless mode. Editor must be running. Feature request drafted in `bazgroly`. |
| "`Cannot find module '<REPLACE>'` — CN is broken" | Wrong wrapper got picked. Use absolute path `~/.console-ninja/.bin/console-ninja`. |

## Typical flow (500 from a Next.js route)

```
1. mcp__console-ninja__runtime-errors                  # get error + stack + file:line
2. mcp__console-ninja__runtime-error-by-id(<id>)       # full detail (if step 1 truncated)
3. Read(<file from stack>)                             # now with concrete data
4. propose fix
```

If step 1 returns empty, run the diagnosis flow (Cause A / B / C above) before doing anything else.

## Hard "don't"s

- **Don't** wrap a prod start script with `console-ninja`. Dev only.
- **Don't** propose adding `console-ninja` as an npm dep. It's a globally installed CLI.
- **Don't** assume the wrapper applies to browser-only apps. It only works for Node processes.
- **Don't** silently fall back to `console.log` debugging when MCP is empty. State the empty result, run the relaunch flow.

## Out of scope

- Test runtime values / failing tests → `wallaby` skill.
- Throwaway snippet prototyping → `quokka` skill.
- E2E browser automation logs (Playwright/Cypress) — CN doesn't sit inside those drivers.
