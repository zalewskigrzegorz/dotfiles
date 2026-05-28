---
name: wallaby
description: Use when a test is failing, flaky, slow to debug, or when asking "why does this assertion fail / what's the actual value / what does this line return at runtime". Also use before reaching for `npm test` / `jest` / `vitest` / `pytest` to reproduce — Wallaby is already running (in VS Code/JetBrains OR in browser-based Standalone mode for Neovim/Zed/Vim/any editor) and exposes live failing-test details, runtime values, coverage, and snapshot controls via MCP. Applies to JavaScript/TypeScript and Python projects.
---

# wallaby

## Core principle

The user has Wallaby.js available in two flavours and there are **two distinct agent integrations**, one per flavour. **Always check which is running before reaching for a tool — they don't share state.**

| Flavour | How it runs | Agent path | Live or one-shot? |
|---|---|---|---|
| **Editor extension** (VS Code / JetBrains / Sublime / VS) | Continuously, as the user edits | **`mcp__wallaby__*` MCP tools** | Live — query whenever |
| **Standalone** (npm `@wallabyjs/cli`, browser UI) | Started by user with `wallaby start`; or by agent with `wallaby run` | **`wallaby run --skill` + `wallaby inspect` Bash commands** | One-shot markdown reports |

The MCP server (`~/.wallaby/mcp/`) only talks to the editor-extension flavour. **Standalone does NOT populate the MCP** — verified empirically 2026-05-28. If you call `mcp__wallaby__wallaby_failingTests` while only standalone is running, you get `<No data available>` — that doesn't mean Wallaby is off, it means you're using the wrong path.

Either way, **the win over `npm test` / `jest` / `vitest` / `pytest` is the same**: you get failure details + per-test runtime values + coverage without spawning a fresh test process, and you can query specific file:line locations.

Greg uses Neovim heavily — assume **standalone CLI path** is a live option, do not write off Wallaby as "VS Code only."

## Hard rule (this is the rule the skill exists to enforce)

When the user mentions a failing/slow test, **your first move is a Wallaby query, not `Bash("npm test")` / `jest` / `vitest` / `pytest`**. Pick the right path based on which flavour is running:

- **MCP path first (default).** Try `mcp__wallaby__wallaby_failingTestsForFile` (or `wallaby_failingTests`) — if it returns data, the extension is alive, continue down MCP.
- **CLI fallback.** If MCP returns `<No data available>`, the user is on standalone (or no Wallaby at all). Run `wallaby run --skill` in the project root — it prints a markdown report with status/failures/coverage. (`--skill` flag keeps Wallaby alive after the run for follow-up `wallaby inspect` calls.)

Do not:
- Run `npm test`, `pnpm test`, `yarn test`, `jest`, `vitest`, `pytest` etc. as the first investigation step.
- Read the test file and the SUT first "to understand the assertion" before checking what Wallaby already knows.
- Treat Wallaby as a conditional fallback ("if Wallaby is running, then…"). Assume it is.
- Assume the MCP being empty means "Wallaby is off" — it may just mean Greg is on standalone. Fall back to `wallaby run --skill` before giving up.

## Red flags — stop and switch to MCP

If you catch yourself thinking any of these, you're rationalizing:

| Thought | Reality |
|---|---|
| "Let me just rerun jest to see the actual error" | Wallaby already has it. `wallaby_failingTestsForFile` returns the error + stack. |
| "I need to read the test first to know what to query" | The MCP takes a path; you don't need to pre-read it. |
| "Maybe Wallaby isn't running on this file" | Try first. If empty → fall back. Don't pre-emptively skip. |
| "Jest is more authoritative" | Wallaby runs the same Jest/Vitest/Pytest under the hood. Same source of truth, faster surface. |

## Tool map — MCP path (editor extension flavour)

Start here when the user points at a failure:

1. `mcp__wallaby__wallaby_failingTestsForFile` (path known) or `mcp__wallaby__wallaby_failingTests` (no file) — get the failure + error message.
2. `mcp__wallaby__wallaby_failingTestsForFileAndLine` — when the user names a line.
3. `mcp__wallaby__wallaby_runtimeValuesByTest` — pull actual values at the failing line. Replaces every `console.log` you'd add.
4. `mcp__wallaby__wallaby_testById` — full detail on one test (use `id` from step 1–2).

Other situations:

- "Is this line covered?" → `mcp__wallaby__wallaby_coveredLinesForFile` / `wallaby_coveredLinesForTest`.
- "Inspect a value at file:line during a test run" → `mcp__wallaby__wallaby_runtimeValues`.
- "Full test list, not just failures" → `wallaby_allTests*` family.
- "Update snapshots" → `wallaby_updateTestSnapshots` (one test) or `wallaby_updateFileSnapshots` (whole file). Confirm with user before `wallaby_updateProjectSnapshots` — it's nuclear.

## Tool map — CLI path (standalone flavour)

When the MCP is empty and the user is on standalone (Neovim/Zed/Vim/any editor):

1. **Run + failure report:**
   ```bash
   wallaby run --skill
   ```
   Prints a markdown report to stdout: status, total/passed/failed/coverage, every failing test with location + error + stack, covered files, links to detailed all-tests + coverage reports inside `node_modules/.wallaby/<hash>/reports/<ts>/`. The `--skill` flag keeps Wallaby alive after the run so follow-up inspects work.
2. **Runtime values at a specific file:line:**
   ```bash
   wallaby inspect '{ path: "src/foo.ts", location: { line: 5 }, expression: "myVar" }'
   ```
   JSON5 schema (note: `location` is nested object, not flat `line` key). Returns markdown per test with the captured runtime value of the expression. Equivalent of `mcp__wallaby__wallaby_runtimeValues` on the MCP side. Multiple inspections can be passed as separate positional args.
3. **Rerun / single test / snapshot updates:** `wallaby run --rerun`, `wallaby run --test "<full name>"`, `wallaby run --snapshots`.
4. **Stop:** `wallaby stop`.

Exit code: `wallaby run --skill` returns non-zero when any test fails. Don't treat exit code 1 as "wallaby broke" — read the markdown report.

## When the MCP returns empty

This means Wallaby isn't running this file (not in its automatic config, or runtime stopped). Then:

1. State plainly in one line: "Wallaby returned no data for this file — Wallaby may not be running or this file isn't in Wallaby's auto config."
2. Ask the user to start Wallaby — flow depends on which mode they use:
   - **Editor extension (VS Code/JetBrains/Sublime/VS):** `Cmd+Shift+P → Wallaby.js: Start`.
   - **Standalone (Neovim/Zed/Vim/Emacs/any editor):** install once with `npm install -g @wallabyjs/cli`, then run `wallaby` in the project root — it opens a browser UI. See "Standalone mode" section below.
3. Don't silently fall back to `npm test` without naming it. If the user prefers the CLI fallback, run the narrowest possible test command (`jest <file>`, not the whole suite).

## Standalone mode (browser UI, any editor)

When the user is **not** in VS Code/JetBrains (typically Neovim or Zed for Greg), Wallaby has a first-party standalone mode. Two ways to use it:

**For humans (interactive, browser UI):**
```bash
wallaby start              # opens browser tab at http://localhost:55000
wallaby start --update     # first-run: also downloads Wallaby Core engine
```
Live test runner, click around, watch values in browser.

**For agents (one-shot markdown to stdout):**
```bash
wallaby run --skill        # runs the suite, prints markdown report, stays alive for inspect
wallaby inspect '{...}'    # query runtime values (see CLI tool map above)
wallaby stop               # tear it down
```

Setup (one-time):
```bash
npm install -g @wallabyjs/cli
```
First time you run any `wallaby` command on a fresh machine, add `--update` to download Wallaby Core. Package name on npm: `@wallabyjs/cli` (the docs page renders it without spacing — don't type `@wallabyjs/cliwallaby`).

The user already has a Wallaby license; standalone uses the same license.

**Hard "don't":** do NOT propose "open VS Code in the background just to host Wallaby" as a workaround — standalone is a first-class agent-supported mode.

**Hard "don't":** do NOT claim MCP works with standalone. The MCP server `~/.wallaby/mcp/` only talks to the editor-extension flavour. If you need agent-readable data from standalone, use `wallaby run --skill` and `wallaby inspect`, both of which print markdown to stdout that you can parse directly.

## Typical flow (failing-test debug)

**MCP path:**
```
1. mcp__wallaby__wallaby_failingTestsForFile(path)
   → see error message, line, test id
2. mcp__wallaby__wallaby_runtimeValuesByTest(test_id, file, line)
   → see actual values, compare to expected
3. Read(sut_path)  // only now, with concrete failure data in hand
4. propose fix
```

**CLI path (standalone):**
```
1. wallaby run --skill
   → markdown report: status, failing tests with stack + location, coverage
2. wallaby inspect '{ path: "<sut>", location: { line: <n> }, expression: "<var>" }'
   → per-test runtime values for the variable at that line
3. Read(<sut>)  // only now, with concrete failure data in hand
4. propose fix
```

Either way: 3–4 calls. The shell-first baseline (`npm test`, then Read, then more Read, then `git log`) is 5+ calls and slower per call. Don't trade away the win.

## Out of scope

- Live app logs, browser console, server-side runtime errors → `console-ninja` skill.
- Throwaway prototyping (regex check, one-liner exploration) → `quokka` skill.
- Running E2E (Playwright/Cypress) — Wallaby doesn't cover those; use the project's e2e command.
