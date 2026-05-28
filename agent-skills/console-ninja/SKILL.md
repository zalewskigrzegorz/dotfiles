---
name: console-ninja
description: Use when debugging a runtime bug in a running app — a 500 from a dev server, an exception, a blank page, "check the logs", a stack trace, a frontend error in the browser — instead of asking the user to paste terminal output, adding `console.log` to source code, or tailing files. Console Ninja captures the app's logs + runtime errors and exposes them via `mcp__console-ninja__*`. Also use when the MCP suddenly returns nothing after the user switched branches or rebuilt — that means the Console Ninja runtime hook detached and the dev server must be relaunched via the `console-ninja` CLI wrapper.
---

# console-ninja

## Core principle

The user runs Console Ninja in VS Code. It captures every `console.log` / `console.error` plus uncaught exceptions from the running app (Node server, Next.js, Vite, browser) and exposes them via MCP. **Hitting the MCP replaces "paste your terminal output," replaces "let me add a few console.logs," and replaces tailing files.** Don't bypass it.

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

## The relaunch flow (use when MCP is empty AND the user just switched branches / rebuilt / restarted dev server)

Known pain point on Greg's machine: `git checkout` and rebuilds frequently detach Console Ninja's Node-side runtime hook. The VS Code extension does **not** silently re-attach. Symptom: `runtime-logs-and-errors` returns nothing while the dev server is clearly running. Don't ask "is CN running?" — fix it.

**Node / dev-server apps (Next.js, Vite, Express, NestJS, …):**

1. Find the running dev server PID/command:
   ```bash
   pgrep -fl 'next dev|vite|nodemon|tsx watch|node .*server'
   ```
2. Confirm with the user (one short line: "I'll kill PID 1234 (`next dev`) and relaunch through `console-ninja` so the runtime hook attaches — OK?"). Wait for yes.
3. Kill the dev server:
   ```bash
   kill <pid>
   ```
4. Relaunch **through the `console-ninja` CLI wrapper** so `NODE_OPTIONS=--require <hook>` is set:
   ```bash
   console-ninja npm run dev
   # or: console-ninja pnpm dev / yarn dev / tsx watch src/server.ts / …
   ```
   The `console-ninja` binary is globally installed (Greg has it at `~/Library/pnpm/console-ninja` — `console-ninja` is on PATH). It wraps any node command transparently; stdout is unchanged; logs are now visible to MCP.
5. Wait for the "ready"/"listening" line, then retry `mcp__console-ninja__runtime-logs-and-errors`.

**Browser-only apps (no Node server, e.g. plain Vite SPA):**

No CLI wrapper. CN's VS Code extension injects a script tag via the dev-server proxy when the extension is **enabled**. If MCP is empty:

1. Tell the user one line: "CN browser capture is off — toggle the Console Ninja icon in the VS Code status bar to Enable, then hard-reload (Cmd+Shift+R)."
2. Wait for confirmation, retry MCP.

## Red flags — stop and switch to MCP / relaunch flow

| Thought | Reality |
|---|---|
| "Let me read the route handler first to spot the bug" | Read it **after** the MCP gives you the error + stack. Otherwise you're guessing. |
| "I'll have the user paste the dev-server output" | The MCP exposes that without manual paste. |
| "Let me sprinkle a few `console.log`s and rerun" | CN already captures every existing log. Adding more pollutes source. |
| "MCP returned nothing — I'll fall back to tailing logs" | First try relaunch flow. Tail only if the wrapper relaunch also gives nothing. |
| "I'll just restart `npm run dev`" | A bare restart does NOT re-attach the CN hook. Use `console-ninja npm run dev`. |

## Typical flow (500 from a Next.js route)

```
1. mcp__console-ninja__runtime-errors                  # get error + stack + file:line
2. mcp__console-ninja__runtime-error-by-id(<id>)       # full detail (if step 1 truncated)
3. Read(<file from stack>)                             # now with concrete data
4. propose fix
```

If step 1 returns empty AND the user said "just switched branches / rebuilt":

```
1. pgrep -fl 'next dev|vite|…'                         # find dev server
2. confirm with user, kill <pid>
3. console-ninja npm run dev                           # relaunch with hook
4. wait for ready, retry step 1 above
```

## Hard "don't"s

- **Don't** wrap a prod start script with `console-ninja`. Dev only.
- **Don't** propose adding `console-ninja` as an npm dep. It's a globally installed CLI.
- **Don't** assume the wrapper applies to browser-only apps. It only works for Node processes.
- **Don't** silently fall back to `console.log` debugging when MCP is empty. State the empty result, run the relaunch flow.

## Out of scope

- Test runtime values / failing tests → `wallaby` skill.
- Throwaway snippet prototyping → `quokka` skill.
- E2E browser automation logs (Playwright/Cypress) — CN doesn't sit inside those drivers.
