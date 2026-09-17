---
description: A skill showing twice in the picker is a stale global copy — fix with `bin/sync`, never by deleting the repo's copy
alwaysApply: true
---

# Duplicate `/skill` in the Picker → Run `bin/sync`, Don't Delete by Hand

When the same skill shows up **twice** in Claude Code's `/` picker inside a
repo, the cause is almost always a **stale global copy**, not a rogue project
copy. Fix it with `bin/sync`. Deleting the project's copy by hand is the wrong
end of the problem and gets silently undone on the next apply.

## How skill scoping actually works here

`run_onchange_after_30-agent-skills-sync.sh.tmpl` splits `agent-skills/` into
buckets:

- **Global** → rsync'd (`--delete`) into `~/.claude/skills/` and
  `~/.cursor/skills/`. Loaded in every repo.
- **Project-scoped** → placed into `<repo>/.claude/skills/` **and removed from
  the global dir**, so they only cost context inside their own repo. Buckets:
  `WORK_SKILLS` (from `bin/place-work-skills --list`, shared with `work new`
  so fresh worktrees get them too), `DOTFILES_SKILLS`, `HOMELAB_SKILLS`.
- The script also writes the matching `/.claude/skills/<name>/` lines into the
  target repo's `.git/info/exclude`, so a placed personal skill never shows up
  in the team's `git status`.

So a work-scoped skill living in `<work-repo>/.claude/skills/` is **correct and
intended**. A copy of it also sitting in `~/.claude/skills/` is the bug.

## What went wrong on 2026-09-08

Eight work-scoped skills (`g-pr`, `g-pr-bump`, `g-pr-common`,
`g-pr-fix-checks`, `g-pr-respond`, `g-pr-review`, `g-github-issue`,
`babysit-prs`) were present in **both** places, so `/g-pr-bump` appeared twice
and both descriptions loaded into every session (~830 tokens of pure dupe).
Hand-deleting the project copies "fixed" nothing — the next `bin/sync` put them
straight back, which is exactly what it is supposed to do. The single `bin/sync`
is what pruned the stale global copies and left one of each.

## Rules

1. **Duplicate in the picker → `bin/sync` first.** Confirm with
   `comm -12 <(ls ~/.claude/skills | sort) <(ls <repo>/.claude/skills | sort)` —
   empty output means clean.
2. **Never hand-delete a skill dir from `<repo>/.claude/skills/`.** If a skill
   should stop being placed there, take it out of its bucket in
   `bin/place-work-skills` (or the arrays in stage 30) and add the name to
   `RETIRED=` in that script when its `agent-skills/` source is deleted.
3. **Never hand-edit `.git/info/exclude` for skill entries.** Stage 30 owns
   those lines and rewrites them.
4. **A skill that should only load in one repo belongs in a bucket**, not in
   the global set. That's the whole point of the split.

## Team-tracked name collisions → rename the global one

Project scope does **not** shadow user scope in the picker: a global skill and a
repo-local one sharing a `name:` both load, and `/name` shows up twice with two
descriptions. `bin/sync` cannot fix this — neither copy is stale.

The team's file is theirs and changing it needs a PR, so the fix is always to
**rename the global variant**, never to overwrite or delete the team's:

| Name in repo | Team's version (in git) | Greg's, renamed |
|---|---|---|
| `deslop` | short "remove AI slop" prompt | `g-deslop` — full pre-commit gate referenced by `g-commit` |

After a rename, update every reference to the old name (other SKILL.md files,
`CLAUDE.md`, rules) and run `bin/sync` so the stale global dir is deleted.

**Compare `name:`, not directory names.** `grafana-mcp-wtf/` exists in both
`~/.claude/skills/` (private overlay) and the monorepo, but the team's declares
`name: grafana-mcp-wtf-dashboards` — different slugs, one picker entry each,
nothing to fix.
