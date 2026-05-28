---
name: wallaby
description: Use when a test is failing, flaky, slow to debug, or when asking "why does this assertion fail / what's the actual value / what does this line return at runtime". Also use before reaching for `npm test` / `jest` / `vitest` / `pytest` to reproduce — Wallaby is already running in the editor and exposes live failing-test details, runtime values, coverage, and snapshot controls via MCP. Applies to JavaScript/TypeScript and Python projects.
---

# wallaby

## Core principle

The user has Wallaby.js running in their editor (VS Code/JetBrains) **all the time**. It continuously executes tests as code changes and captures failure details + runtime values. The `mcp__wallaby__*` tools expose that live state. **Hitting the MCP is 10x faster than spawning a Jest/Vitest/Pytest process from the shell**, and it gives you data the shell run does not (runtime values at any file:line, per-test coverage).

## Hard rule (this is the rule the skill exists to enforce)

When the user mentions a failing/slow test, **your first tool call is a `mcp__wallaby__*` lookup, not `Bash("npm test")` / `Bash("jest …")` / `Bash("vitest …")` / `Bash("pytest …")`**.

Do not:
- Run `npm test`, `pnpm test`, `yarn test`, `jest`, `vitest`, `pytest` etc. as the first investigation step.
- Read the test file and the SUT first "to understand the assertion" before checking what Wallaby already knows.
- Treat Wallaby as a conditional fallback ("if Wallaby is running, then…"). Assume it is.

## Red flags — stop and switch to MCP

If you catch yourself thinking any of these, you're rationalizing:

| Thought | Reality |
|---|---|
| "Let me just rerun jest to see the actual error" | Wallaby already has it. `wallaby_failingTestsForFile` returns the error + stack. |
| "I need to read the test first to know what to query" | The MCP takes a path; you don't need to pre-read it. |
| "Maybe Wallaby isn't running on this file" | Try first. If empty → fall back. Don't pre-emptively skip. |
| "Jest is more authoritative" | Wallaby runs the same Jest/Vitest/Pytest under the hood. Same source of truth, faster surface. |

## Tool map (most common → narrowest)

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

## When the MCP returns empty

This means Wallaby isn't running this file (not in its automatic config, or extension stopped). Then:

1. State plainly in one line: "Wallaby returned no data for this file — extension may not be running or this file isn't in Wallaby's auto config."
2. Ask the user to start Wallaby (`Cmd+Shift+P → Wallaby.js: Start`) — don't silently fall back to `npm test` without naming it.
3. If the user prefers the CLI fallback, run the narrowest possible test command (`jest <file>` not the whole suite).

## Typical flow (failing-test debug)

```
1. mcp__wallaby__wallaby_failingTestsForFile(path)
   → see error message, line, test id
2. mcp__wallaby__wallaby_runtimeValuesByTest(test_id, file, line)
   → see actual values, compare to expected
3. Read(sut_path)  // only now, with concrete failure data in hand
4. propose fix
```

That is 3–4 calls. The shell-first baseline is 5+ calls and slower per call. Don't trade away the win.

## Out of scope

- Live app logs, browser console, server-side runtime errors → `console-ninja` skill.
- Throwaway prototyping (regex check, one-liner exploration) → `quokka` skill.
- Running E2E (Playwright/Cypress) — Wallaby doesn't cover those; use the project's e2e command.
