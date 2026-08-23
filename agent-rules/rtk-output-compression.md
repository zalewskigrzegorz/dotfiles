---
description: rtk (Rust Token Killer) compresses command output before it reaches the context. It is wired in as a PreToolUse Bash hook, so ordinary commands are rewritten automatically — these are the few things to invoke by hand.
alwaysApply: true
---

# rtk — output compression on the Bash tool

[`rtk`](https://github.com/rtk-ai/rtk) is a local Rust binary that filters, groups
and deduplicates command output so less of it lands in the context. It runs as a
**PreToolUse hook on `Bash`** (`rtk hook claude`, registered in
`.chezmoitemplates/claude-settings.json`), which rewrites `git status` into
`rtk git status` and so on. That part is automatic — do not prefix commands with
`rtk` by hand.

## What to call directly

```bash
rtk gain              # how much output the filters actually removed
rtk gain --history    # per-command breakdown
rtk discover          # commands that ran raw and had an rtk equivalent
rtk proxy <cmd>       # run a command with filtering OFF (debugging)
```

## What to know when reading filtered output

- **Nothing is silently lost on failure.** When a command exits non-zero, rtk
  writes the full raw output to `~/.local/share/rtk/tee/` and prints the path in
  the filtered output. Read that file instead of re-running the command.
- **Unknown subcommands pass through untouched.** A missing filter degrades to
  the raw command, never to a blocked one.
- **`rtk proxy <cmd>`** is the escape hatch when you suspect the filter itself is
  hiding the thing you need.

## The auto-allow caveat

The hook returns `permissionDecision: "allow"` for any command it rewrites, so a
rewritten command **skips the permission prompt**. Explicit `deny` and `ask`
rules still win — rtk detects them and steps aside. This does mean Greg's prompt
is no longer the review gate for the commands rtk covers, which is a deliberate
trade, not an oversight. Anything that must keep prompting belongs in an explicit
`ask`/`deny` rule, or in `exclude_commands` in rtk's `config.toml`.

## Telemetry

Off, and it stays off — `rtk telemetry status` should report `enabled: no`. Never
run `rtk telemetry enable`: work identifiers and repo names must not leave the
machine.
