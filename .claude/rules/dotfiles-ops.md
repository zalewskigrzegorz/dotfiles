---
paths: "bin/**, scriptc/**, dot_claude/**, dot_config/**, agent-*/**, .chezmoitemplates/**, run_*, private_*/**, docs/**"
---

# dotfiles ops traps

## Slack poster token rotation: env var beats the file

After rotating `WORK_SLACK_POSTER_TOKEN` the first send failed on
`token_revoked`: older shells and sessions held the old value and the scripts
read the env var before `work.env` (2026-10-13). Rotation = update the
`slack-poster-user-token` item **and** the line in the `WORK_ENV` document
(`bin/sync` restores `work.env` from it). Test with `env -u
WORK_SLACK_POSTER_TOKEN <script>`, restart older shells and sessions. The value
goes clipboard → consumer → `pbcopy < /dev/null`, never to stdout.

## A `uvx` MCP server locks the uv cache

Every running `uvx <server>` holds `~/.cache/uv`, so `uv cache prune` in
`disk-sweep` timed out (2026-10-13). An MCP server is installed with `uv tool
install` in stage 26 and started by its binary name, never `uvx`. Diagnose:
`ps -axo pid,etime,command | rg '[u]vx '`. Older sessions keep the lock until
restarted.

## `/tui` switches every running Claude session at once

`/tui default` writes `tui` into `~/.claude/settings.json`, every open session
reloads it live and drops from the fullscreen renderer to an empty screen
(28ca873d). "Already using the default renderer" in the others is the shared
setting, not proof they were untouched. Never run `/tui` or edit `tui` while
sessions are open. Test a renderer in one new session only: `with-env
{CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN: '1'} { claude }`. Recovery: set `tui`
back, sessions redraw on the next key.

The `env` block reloads live the same way: that flag put into settings.json
blanked every open session (928081b1, reverted in 47a4241). A renderer flag
goes into the process env (`with-env`, nushell `env.nu`), never settings.json.
Removing a key from the template doesn't remove it from the live file
(`modify_settings.json.tmpl` merges in): `jq 'del(.env.X)'` the live file too.
Scroll jumps don't reproduce on tuios (2.1.311), so don't blame upstream
#34845. The blanking is anthropics/claude-code#104064, and blank sessions need
`/exit` + `claude --continue`.

## A cheap Haiku call from a script or hook

`claude -p --model claude-haiku-5-5 --no-session-persistence --strict-mcp-config
--tools "" --setting-sources "" --system-prompt "…" "<input>" </dev/null`, with
an env guard (`OS_TITLE_CHILD=1`) that your own hook checks first. No hooks,
plugins, MCP or CLAUDE.md load: ~600 tokens, ~2 s, $0.0002. `--bare` is not an
option here, it reads only `ANTHROPIC_API_KEY`, never the OAuth login. Haiku
sometimes reasons before the answer, so take the last line. Without
`</dev/null` it eats the stdin of a `while read` loop around it, and the loop
ran one item out of twelve (28ca873d).

## `bin/sync` on a held chezmoi lock

Another agent's `chezmoi apply` holds it. One `ps -axo pid,etime,command | rg
'[c]hezmoi'`; under ~2 min old → `timeout 180 sh -c 'while pgrep -x chezmoi
>/dev/null; do sleep 5; done'`, then `bin/sync` once. Older, or the wait timed
out → report pid and age. Never kill another agent's apply (f6d9d77e).

## Pushed dotfiles `master` from a worktree → fast-forward the main checkout

`bin/sync` and `~/bin` read `~/Code/dotfiles`. After `git push origin
HEAD:master` from a worktree: `git -C ~/Code/dotfiles fetch -q origin master
&& git -C ~/Code/dotfiles merge --ff-only origin/master`, only when that
checkout is clean and on `master`; otherwise one line (dc819c48).

## Renaming or retiring a skill

`rg` the old name across the repo and fix every hit outside `legacy/`. Add the name to `RETIRED=(…)` in stage 30 in the same commit that deletes its `agent-skills/` dir: `--delete` cleans `~/.claude/skills`, but a copy already placed in a repo's `.claude/skills/` stays without it (be66f15e).

## Work skills reach the monorepo through `bin/place-work-skills`

A work skill is not copied by hand into the monorepo checkout: run `bin/place-work-skills` (edb80735).

## Before writing "X puts Y first on PATH"

Run `env PATH=<prefix>:/usr/bin:/bin command -v <tool>` and `<tool>
--version` once. An `ls` of the directory is not proof (f6d9d77e).
