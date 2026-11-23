---
name: skill-scope-duplicates
description: A /skill shows up twice in Claude Code's picker, or a skill is missing / stale in a repo: how agent-skills are bucketed (global vs work / dotfiles / home-lab), why bin/sync fixes duplicates, never hand-deleting <repo>/.claude/skills, renaming a global skill that collides with a team-tracked one. Load when the picker shows a duplicate, a work skill is missing, or a skill is renamed or moved between buckets.
---

# Duplicate `/skill` → `bin/sync`, don't delete by hand

Stage 30 (`run_onchange_after_30-agent-skills-sync.sh.tmpl`) splits `agent-skills/`:

- **Global** → `rsync --delete` into `~/.claude/skills/`, loaded everywhere.
- **Project-scoped** → placed into `<repo>/.claude/skills/` and removed from the global dir: `WORK_SKILLS` (from `bin/place-work-skills --list`, shared with `work new`), `DOTFILES_SKILLS`, `HOMELAB_SKILLS`. Stage 30 also writes their `/.claude/skills/<name>/` lines into the repo's `.git/info/exclude`.

A work skill in `<work-repo>/.claude/skills/` is intended; a copy also in `~/.claude/skills/` is the bug (2026-09-08: eight `g-pr*` skills loaded twice; hand-deleting the project copies was undone by the next sync, one `bin/sync` fixed it).

## Rules

1. Duplicate in the picker → `bin/sync` first. Check: `comm -12 <(ls ~/.claude/skills | sort) <(ls <repo>/.claude/skills | sort)` is empty.
2. Never hand-delete from `<repo>/.claude/skills/`: take the skill out of its bucket (`bin/place-work-skills` or the stage-30 arrays); retiring a skill → `.claude/rules/dotfiles-ops.md` § Skills.
3. Never hand-edit skill lines in `.git/info/exclude`; stage 30 owns them.
4. A skill for one repo belongs in a bucket, not the global set.

## Collision with a team-tracked skill → rename yours

A global and a repo-local skill with the same `name:` both load; `bin/sync` can't fix it. The team's file needs a PR, so rename the global one (e.g. team `deslop` → Greg's `g-deslop`), update every reference, `bin/sync`. Compare `name:`, not dir names: `grafana-mcp-wtf/` exists in both places but the team's declares `name: grafana-mcp-wtf-dashboards`, nothing to fix.
