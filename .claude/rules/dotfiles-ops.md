---
paths: "bin/**, scriptc/**, dot_claude/**, dot_config/**, agent-*/**, .chezmoitemplates/**, run_*, private_*/**, docs/**"
---

# dotfiles ops traps

## Slack poster token rotation: env var beats the file

Scripts read `WORK_SLACK_POSTER_TOKEN` from env before `work.env`, so older shells kept the revoked value (`token_revoked`). Rotation = the `slack-poster-user-token` item **and** the line in the `WORK_ENV` document (`bin/sync` restores `work.env` from it). Test with `env -u WORK_SLACK_POSTER_TOKEN <script>`, restart older shells and sessions. Token handling as in `agent-rules/browser-stacks.md` (never to stdout).

## A `uvx` MCP server locks the uv cache

Every running `uvx <server>` holds `~/.cache/uv` (`uv cache prune` in `disk-sweep` timed out). Install MCP servers with `uv tool install` in stage 26 and start them by binary name, never `uvx`. Diagnose: `ps -axo pid,etime,command | rg '[u]vx '`; older sessions hold the lock until restarted.

## `/tui` and the settings `env` block switch every running session at once

- `/tui default` writes `tui` into `~/.claude/settings.json`; every open session reloads it live and drops to an empty screen (28ca873d). "Already using the default renderer" elsewhere is the shared setting, not proof. Never run `/tui` or edit `tui` with sessions open; test a renderer in one new session: `with-env {CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN: '1'} { claude }`. Recovery: set `tui` back, sessions redraw on the next key.
- The `env` block reloads live too (that flag in settings.json blanked every session, anthropics/claude-code#104064; blank sessions need `/exit` + `claude --continue`). Renderer flags go into the process env (`with-env`, `env.nu.tmpl`), never settings.json.
- Removing a key from the template doesn't remove it live (`modify_settings.json.tmpl` merges): `jq 'del(.env.X)'` the live file too.
- Scroll jumps don't reproduce on tuios (2.1.311): don't blame upstream #34845.

## A cheap Haiku call from a script or hook

`claude -p --model claude-haiku-5-5 --no-session-persistence --strict-mcp-config --tools "" --setting-sources "" --system-prompt "…" "<input>" </dev/null`, with an env guard (`OS_TITLE_CHILD=1`) your own hook checks first. No hooks, plugins, MCP or CLAUDE.md load: ~600 tokens, ~2 s. Not `--bare`: it reads only `ANTHROPIC_API_KEY`, never the OAuth login. Take the last line (Haiku sometimes reasons first). Without `</dev/null` it eats a surrounding `while read` loop's stdin (1 item of 12 ran).

## `bin/sync` on a held chezmoi lock

Another agent's `chezmoi apply` holds it. One `ps -axo pid,etime,command | rg '[c]hezmoi'`; under ~2 min old → `timeout 180 sh -c 'while pgrep -x chezmoi >/dev/null; do sleep 5; done'`, then `bin/sync` once. Older, or timed out → report pid and age. Never kill another agent's apply (f6d9d77e).

## Pushed `master` from a worktree → fast-forward the main checkout

`bin/sync`, `~/bin` and the `greg-mods` marketplace read `~/Code/dotfiles`. After `git push origin HEAD:master` from a worktree: `git -C ~/Code/dotfiles fetch -q origin master && git -C ~/Code/dotfiles merge --ff-only origin/master`, only when that checkout is clean and on `master`; otherwise one line.

## Skills

- **Renaming or retiring:** `rg` the old name across the repo and fix every hit outside `legacy/`. Add it to `RETIRED=(…)` in stage 30 in the commit that deletes its `agent-skills/` dir: `--delete` cleans `~/.claude/skills`, but a copy in a repo's `.claude/skills/` stays without it.
- **Work skills reach the monorepo only through `bin/place-work-skills`**, never a hand copy.

## Before writing "X puts Y first on PATH"

Run `env PATH=<prefix>:/usr/bin:/bin command -v <tool>` and `<tool> --version` once; an `ls` is not proof.
