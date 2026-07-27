---
name: herdr-orchestration
description: Use when spawning, briefing, monitoring, auditing, or cleaning up coding agents in herdr workspaces/worktrees from the CLI — "odpal agenta w worktree", "daj mu taska", "sprawdź co robi agent", "czy agent skończył", "zamknij worktree po agencie", delegating a task to a parallel Claude session, or checking on any agent visible in Greg's herdr sidebar. Mac only (herdr does not run on the lab).
---

# Herdr agent orchestration

Drive parallel coding agents in herdr (Greg's terminal workspace manager) from the CLI. Most `herdr` subcommands return JSON — parse it, don't grep blindly. **Exception: `herdr agent read` returns raw terminal scrollback, not JSON** — pipe it to `tail`, never to a JSON parser.

## Create worktrees with `work new`, never raw `herdr worktree create`

`work` is Greg's nushell wrapper (`dot_config/nushell/autoload/work.nu`). It calls `herdr worktree create` and then does three things the raw call skips:

- **applies the pane layout** — renames the bare shell tab, opens a dedicated `claude` tab and runs `claude` in it,
- **seeds untracked state** — APFS-clones (`cp -c`, instant) `node_modules` and every `.env` from the parent checkout,
- runs a deps preflight.

Skip it and you get a bare pane with no agent, no `node_modules` and no env files — then you waste minutes on `pnpm install` and env-copy scripts that `work` would have cloned for free.

`work` is nu-only and not on PATH from the Bash tool, so source it explicitly and run from inside the repo (`$WORK_PROJECT_DIR` is the work monorepo; for any other repo `cd` there instead):

```bash
cd "$WORK_PROJECT_DIR" && nu -c 'source /Users/greg/Code/dotfiles/dot_config/nushell/autoload/work.nu; work new <branch> --from origin/main'
```

Flags: `--from <ref>` (base, NOT `--base`), `--type <t>` (conventional prefix), `--no-prefix`, `--no-focus`, `--no-seed`. Removal: `work rm <branch> [--force] [--keep-branch]`. Everything after creation (start/prompt/read/wait) uses `herdr` subcommands directly.

## Quick reference — these exact commands, nothing else

| Goal | Command |
|---|---|
| List all agents + statuses | `herdr agent list` |
| One agent's state | `herdr agent get <name\|pane_id>` |
| Read agent scrollback (**raw text, not JSON**) | `herdr agent read <target> \| tail -20` |
| Create worktree + workspace | `work new` — see above |
| Start agent in a pane | `herdr agent start <name> --kind claude --pane <pane_id>` |
| Send a task brief | `herdr agent prompt <target> "<text>"` |
| Press keys (e.g. submit) | `herdr agent send-keys <target> Enter` |
| Block until state | `herdr agent wait <target> --until blocked --until done --timeout <ms>` |
| Remove worktree workspace | `work rm <branch>`, or `herdr worktree remove --workspace <id> [--force]` |

Checkout lands in `~/.herdr/worktrees/<repo>/<branch-slug>`. If you do fall back to raw `herdr worktree create`, capture `workspace_id` and `root_pane.pane_id` from its JSON — but expect both to shift once the layout is applied (mine 2).

## The four mines

1. **`agent prompt` pastes but does NOT submit.** A multi-line brief lands in the input box as `[Pasted text #1 +45 lines]` and just sits there. ALWAYS follow up: `herdr agent read <target> | tail -20` — if the text is still in the input box, `herdr agent send-keys <target> Enter`, then read again and confirm the agent is actually working. This fires nearly every time, not occasionally.
2. **Applying the layout renumbers everything and drops agent names.** After `work new`'s layout step (or any tab/pane change), the agent is on a different `pane_id` and a different `tab_id` than `worktree create` reported — e.g. `w10:p1` becomes `w10:p3` on `w10:t2` — and a name you registered with `agent start` no longer resolves. Re-run `herdr agent list` and target by `pane_id` after any layout change.
3. **`idle` is ambiguous** — it means "not typing": could be finished, could be waiting for a permission prompt. `blocked` sorts first in Greg's sidebar and is the real "needs input" signal. For "did it actually do the work", the terminal is NOT the source of truth — check the worktree: `git -C ~/.herdr/worktrees/<repo>/<slug> log --oneline origin/<base>..HEAD` and `gh pr list --head <branch>`.
4. **The parent session's permission mode does NOT propagate.** Yolo mode is session-scoped: a spawned agent runs in Greg's default (usually manual) mode regardless of how permissive your own session is. Expect it to stop on the first permission prompt and surface as `blocked`. Don't brief it as if it could act unattended, and don't read that first stall as a failure.

## Lifecycle pattern

```bash
cd "$WORK_PROJECT_DIR" && nu -c 'source /Users/greg/Code/dotfiles/dot_config/nushell/autoload/work.nu; work new feat/demo --from origin/main'
herdr agent list                           # find the claude pane in the new workspace (mine 2)
herdr agent prompt w12:p3 "<brief>"        # if work already ran claude, skip `agent start`
herdr agent read w12:p3 | tail -20         # verify submitted; else send-keys Enter (mine 1)
herdr agent send-keys w12:p3 Enter
herdr agent wait w12:p3 --until blocked --until done --timeout 1800000
herdr agent read w12:p3 | tail -30         # what does it need / what did it produce
# audit: git log + gh pr in the worktree (see mine 3)
nu -c 'source /Users/greg/Code/dotfiles/dot_config/nushell/autoload/work.nu; work rm feat/demo'   # only after merge
```

## Writing the brief

The brief is the child's ONLY context. Include: the task + its issue/PR number; the **base branch** (stacked-PR repos: naming the wrong base creates a PR against main — the worktree-dev skill's #1 landmine, tell the agent to use it for bootstrap); pattern files to imitate; where the PR should point (`base <branch>`, `Fixes #<n>`); which branches/worktrees other agents own and must be left alone; and "present a plan before coding" if Greg should gate it.

## Stacked PRs: one worktree per stack, not per branch

A branch can be checked out in only one worktree, and `gh stack checkout` / `gh stack rebase` walk the whole stack sequentially in a single directory. Spread the layers across per-branch worktrees and every stack command dies with `'<branch>' is already used by worktree at ...`. Give the whole stack one worktree and let the agent move with `gh stack up/down/switch`.

This costs nothing in parallelism: layers of a stack are not independent anyway — a commit on layer N invalidates every layer above it. Parallelise across *stacks* and standalone PRs, not across layers of one stack.

Two things to put in a stack agent's brief:

- **Trunk is checked out in the main checkout**, so the stack worktree cannot check out `main` and a fetch into it is refused. Have the agent run `git -C <main-checkout> pull --ff-only` first, and fall back to `gh stack rebase --no-trunk` if the trunk step still fails.
- **Merged bottom layers produce phantom conflicts.** Squash-merged layers have different SHAs than their local commits, so `git cherry` reports them as absent and the rebase re-conflicts on changes already upstream. Tell the agent to take main's version there rather than resurrecting code main already dropped.

## Safety

- Never `send-keys` into a pane you haven't just `read` — you may be typing into Greg's live session (all his agents share the list; check `focused` and `cwd` before touching one you didn't start).
- Never `worktree remove` a workspace you didn't create without Greg's confirmation; `--force` discards uncommitted work.
- Agents run with Greg's default permission mode (often manual) — a briefed agent that stays `idle` is usually waiting for a permission prompt; read the pane before assuming failure. See mine 4.
- Before removing any worktree, audit it: `git status --porcelain`, `git rev-list --left-right --count @{u}...HEAD` for unpushed commits, and `herdr agent list` for agents whose `cwd` is inside it. Ignored files (`node_modules`) don't show in `status` but do make `worktree remove` need `--force` — and removal takes minutes per worktree because it deletes them.
- `git stash` is shared across all worktrees of a repo (it lives in the common `.git`), so stashes survive `worktree remove`. A "1 stash" reading in every worktree is the same single stash, not one each.
