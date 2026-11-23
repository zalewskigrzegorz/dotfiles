---
description: rtk (Rust Token Killer) compresses command output before it reaches the context. It is wired in as a PreToolUse Bash hook, so ordinary commands are rewritten automatically — these are the few things to invoke by hand.
alwaysApply: true
---

# rtk: output compression on the Bash tool

[`rtk`](https://github.com/rtk-ai/rtk) filters, groups and dedupes command output. It runs as a PreToolUse hook on `Bash` (`rtk hook claude` in `.chezmoitemplates/claude-settings.json`) that rewrites e.g. `git status` into `rtk git status`: never prefix `rtk` by hand. By hand only: `rtk gain` (`--history` per command), `rtk discover` (raw commands with an rtk equivalent), `rtk proxy <cmd>` (filtering off).

- **Nothing is lost on failure**: a non-zero exit writes the full raw output to `~/.local/share/rtk/tee/` and prints the path; read that file instead of re-running. Unknown subcommands pass through untouched.
- **Auto-allow caveat**: a rewritten command returns `permissionDecision: "allow"` and skips the prompt (explicit `deny`/`ask` rules still win). That trade is deliberate; anything that must keep prompting needs an explicit `ask`/`deny` rule or `exclude_commands` in rtk's `config.toml`.
- **Telemetry stays off** (`rtk telemetry status` → `enabled: no`); never `rtk telemetry enable`, work identifiers must not leave the machine.
- **Existence checks** ("does X exist / which files match") go through `rtk proxy <cmd>` the first time, or `Glob`/`Read`: a filtered `find`, `ls` or `rg -l` can come back empty or `[+N hidden: rtk recall …]` while the file exists (57 re-runs once). **Only existence checks**: content searches (`rg -n`, `-B/-A`) use plain `rg` or `Grep` capped with `-m N` (guard denies `rtk proxy rg -n`). A suspicious empty or `[+N hidden]` result → re-run that one command via `rtk proxy`, then back to plain `rg`.
