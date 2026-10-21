---
name: herdr-orchestration
description: Use when spawning, briefing, monitoring, auditing, or cleaning up coding agents in herdr workspaces/worktrees from the CLI — "odpal agenta w worktree", "daj mu taska", "sprawdź co robi agent", "czy agent skończył", "zamknij worktree po agencie", delegating a task to a parallel Claude session, or checking on any agent visible in Greg's herdr sidebar. Mac only (herdr does not run on the lab).
---

# Herdr agent orchestration

Drive parallel coding agents in herdr (Greg's terminal workspace manager) from the CLI. Most `herdr` subcommands return JSON — parse it, don't grep blindly. **Exception: `herdr agent read` returns raw terminal scrollback, not JSON** — pipe it to `tail`, never to a JSON parser.

## Read-only or analysis task: a Sonnet agent in the current worktree, no new branch

Not every brief needs a worktree. An analysis that only reads (a code review, a naming study, a
comparison) runs in a second tab of the workspace you are already in, on a cheaper model, and
leaves no branch behind. Verified 2026-09-21: the whole loop took 5 minutes of agent time.

```bash
herdr agent list | jq -r '.result.agents[] | "\(.pane_id)\t\(.workspace_id)\t\(.cwd)"'   # find your workspace id
herdr tab create --workspace <ws> --cwd "$PWD" --label "naming analysis" | jq -c '.result.root_pane.pane_id'
herdr agent start naming-analysis --kind claude --pane <ws>:p<N> -- --model sonnet   # args after -- go to claude
herdr agent prompt <ws>:p<N> "$(cat brief.md)"     # pastes only (mine 1)
herdr agent send-keys <ws>:p<N> Enter
herdr agent read <ws>:p<N> | tail -12               # confirm it is working, not sitting on the paste
herdr agent wait <ws>:p<N> --until blocked --until done --timeout 1500000
```

`herdr agent list` returns `{"result":{"agents":[…]}}`, not a bare array. `--model sonnet` after `--`
is how the Fable-session rule ("subagents run on Sonnet") is honoured here, since `wt-full` starts
`claude` with the default model. Tell the brief to write its report to bazgroly, not into the repo,
and to touch no branch.

## Create worktrees with `workctl`, never raw `herdr worktree create` or plain git

`work new` is a thin wrapper over `workctl` (`def --wrapped "work new" [...rest] { ^workctl ...$rest }`),
and `workctl` is a binary on `PATH`, so the Bash tool calls it directly from inside the repo
(`$WORK_PROJECT_DIR` is the work monorepo; for any other repo `cd` there instead):

```bash
cd "$WORK_PROJECT_DIR" && workctl --branch <branch> [--base origin/<ref>] --action wt-full --yes --no-focus
```

- **A new branch** is created from `--base` (default `origin/<default>`). A stacked branch passes its base.
- **An existing branch or worktree** is checked out or reopened; `--base` is ignored with a warning.
- **A branch with a PR** goes through the PR path, the same as `workctl --pr <n> --action …`.
- A branch without a PR takes only the worktree actions (`wt-full`, `wt-light`, `wt-bootstrap`, `rm`);
  anything else dies with `--action <id> needs a PR`.

`wt-full` does what the raw calls skip:

- **applies the pane layout** — renames the bare shell tab, opens a dedicated `claude` tab and runs `claude` in it,
- **seeds untracked state** — APFS-clones (`cp -c`, instant) `node_modules` and every `.env`, from the base's worktree
  when the base is a branch that has one (its lockfile decides `node_modules`), otherwise from the main checkout,
- places the work skills and the MCP defaults.

Skip it and you get a bare pane with no agent, no `node_modules` and no env files — then you waste minutes on
`pnpm install` and env-copy scripts. On 2026-09-29 a worktree made with plain `git worktree add` had to be rebuilt by
hand (`herdr worktree open`, the layout, the seed) after Greg asked for this path. `--dry-run` prints what would run.
Removal: `workctl rm <branch> [--force] [--keep-branch]`. Everything after creation (start/prompt/read/wait) uses
`herdr` subcommands directly.

## Quick reference — these exact commands, nothing else

| Goal | Command |
|---|---|
| List all agents + statuses | `herdr agent list` |
| One agent's state | `herdr agent get <name\|pane_id>` |
| Read agent scrollback (**raw text, not JSON**) | `herdr agent read <target> \| tail -20` |
| Create worktree + workspace | `workctl --branch <b> [--base <ref>] --action wt-full --yes --no-focus` — see above |
| Start agent in a pane | `herdr agent start <name> --kind claude --pane <pane_id>` |
| Send a task brief | `herdr agent prompt <target> "<text>"` |
| Press keys (e.g. submit) | `herdr agent send-keys <target> Enter` |
| Pick in the agent's popup | `herdr agent send-keys <target> down down Enter` — several keys per call, `esc` is the canonical Escape |
| Is it waiting on an answer? | `herdr agent list \| jq -r '.result.agents[] \| select(.pane_id=="<p>") \| .agent_status'`, then `herdr agent read <p> \| grep -v '^\s*$' \| tail -5` |
| Block until state | `herdr agent wait <target> --until blocked --until done --timeout <ms>` |
| Remove worktree workspace | `workctl rm <branch>`, or `herdr worktree remove --workspace <id> [--force]` |

Checkout lands in `~/Code/tree/wt-<repo>/<branch>`. If you do fall back to raw `herdr worktree create`, capture `workspace_id` and `root_pane.pane_id` from its JSON — but expect both to shift once the layout is applied (mine 2).

## The seven mines

1. **`agent prompt` pastes but does NOT submit.** A multi-line brief lands in the input box as `[Pasted text #1 +45 lines]` and just sits there. ALWAYS follow up: `herdr agent read <target> | tail -20` — if the text is still in the input box, `herdr agent send-keys <target> Enter`, then read again and confirm the agent is actually working. This fires nearly every time, not occasionally.
2. **Applying the layout renumbers everything and drops agent names.** After `wt-full`'s layout step (or any tab/pane change), the agent is on a different `pane_id` and a different `tab_id` than `worktree create` reported — e.g. `w10:p1` becomes `w10:p3` on `w10:t2` — and a name you registered with `agent start` no longer resolves. Re-run `herdr agent list` and target by `pane_id` after any layout change.
3. **`idle` is ambiguous** — it means "not typing": could be finished, could be waiting for a permission prompt. `blocked` sorts first in Greg's sidebar and is the real "needs input" signal. For "did it actually do the work", the terminal is NOT the source of truth — check the worktree: `git -C ~/Code/tree/wt-<repo>/<branch> log --oneline origin/<base>..HEAD` and `gh pr list --head <branch>`.
4. **The parent session's permission mode does NOT propagate.** Yolo mode is session-scoped: a spawned agent does NOT inherit it regardless of how permissive your own session is. A spawned agent starts in the global `defaultMode` from `~/.claude/settings.json` — currently `acceptEdits`, so it auto-accepts file edits but still prompts (and surfaces as `blocked`) on Bash commands and MCP writes that aren't allow-listed. So it can edit unattended but will stall on the first non-allow-listed shell command; don't brief it as if it could run shell steps unattended, and don't read that first Bash stall as a failure.
5. **`agent start` returns before `claude` is ready, and it can fail outright.** Never `>/dev/null` it: on 2026-10-21 a start that died silently left `wait`, `prompt` and `send-keys` answering `agent_not_found` for a pane nobody was in. Always `herdr agent start … | jq -c '.result.agent.agent_status // .error'`. A `prompt` sent right after it answers `agent_not_ready` ("blocked during startup"), and the brief is lost; two of five agents needed a second prompt on 2026-10-21. After `agent start`: `herdr agent wait <pane> --until idle --timeout 60000`, then prompt. Check the paste landed with one `agent read` (mine 1).
6. **`agent read` can serve a frozen screen.** On 2026-10-21 one pane showed the same statusline timer (`2m31s`) for 10 minutes and the input box kept its text after three `Enter`s, while the agent had taken the input and was working. The terminal is not the source of truth for progress either: `stat -f %Sm ~/.claude/projects/<slug>/<session>.jsonl` (the path `scripts/agent-last-turns` prints) moving in the last minute means working; `agent list` → `agent_status` and the worktree (mine 3) answer "done". Don't resend the brief into a pane that looks stuck; check the transcript first.
7. **A child's popup is read in full before any `send-keys`.** The option labels alone lie about side effects: on 2026-10-21 `Enter` on "Przepuść przez greg-voice" in a review agent ended with `gh pr review` posted on GitHub, although the brief said "nie postuj". Read the option descriptions (`agent read | tail -30`), and when any option can post, send or commit, pick it only if Greg chose that step. A read-only brief names the forbidden commands: "no `gh pr review`, no `gh api -X POST`, no `gh pr comment`", not only "nie postuj".

## Lifecycle pattern

```bash
cd "$WORK_PROJECT_DIR" && workctl --branch feat/demo --action wt-full --yes --no-focus
herdr agent list                           # find the claude pane in the new workspace (mine 2)
herdr agent prompt w12:p3 "<brief>"        # wt-full already ran claude, skip `agent start`
herdr agent read w12:p3 | tail -20         # verify submitted; else send-keys Enter (mine 1)
herdr agent send-keys w12:p3 Enter
herdr agent wait w12:p3 --until blocked --until done --timeout 1800000
herdr agent read w12:p3 | tail -30         # what does it need / what did it produce
# audit: git log + gh pr in the worktree (see mine 3)
workctl rm feat/demo                       # only after merge
```

**The model follows the task's weight** (`agent-rules/subagent-model-by-weight.md`): code that lands in a PR, a debugging hunt or anything over ~15 min → `--model opus`; mail drafts, Slack digests, read-only lookups → `--model sonnet`; Fable only when Greg names it for that spawn. `wt-full` starts `claude` on the default model, so switch before the brief and say the model in the spawn line.

```bash
herdr agent prompt w12:p3 "/model <model id>"
herdr agent send-keys w12:p3 Enter          # prompt never submits on its own (mine 1)
herdr agent read w12:p3 | tail -5            # one read: the model line changed
herdr agent prompt w12:p3 "<brief>" && herdr agent send-keys w12:p3 Enter
```

## Supervising: one wait, not a read/sleep/list loop

A supervisor that polls (`agent read` 34x, `list` 27x, `sleep` 24x in one session) burns its own context.
Use the helpers in `scripts/` (run by path from this skill's dir):

```bash
scripts/agent-status                              # one line per agent: target | state | last 2 lines | PR + checks
scripts/agent-status --wait --timeout 1800 w3N:p2 # blocks (polls 15 s), returns on idle/blocked/unknown, exit 124 on timeout
scripts/agent-last-turns <worktree-or-branch> 5   # what did the agent actually do / ask (last N assistant turns + tool names)
```

- Waiting = `agent-status --wait`, or ONE `Monitor` with an `until` loop and a `timeout`. Never a series of
  background loops: loops without a timeout get killed under memory pressure and leave nothing behind.
- `agent-last-turns` builds the `~/.claude/projects/<slug>/*.jsonl` path itself and fails loudly on a missing dir;
  don't hand-roll `f=…; jq …`. A branch name resolves via `git worktree list`, so run it inside the repo.

## Writing the brief

The brief is the child's ONLY context. Include: the task + its issue/PR number; the **base branch** (stacked-PR repos: naming the wrong base creates a PR against main — the worktree-dev skill's #1 landmine, tell the agent to use it for bootstrap); pattern files to imitate; where the PR should point (`base <branch>`, `Fixes #<n>`); which branches/worktrees other agents own and must be left alone; and "present a plan before coding" if Greg should gate it.

**A fix brief starts with "is the bug still there".** Before the first edit the agent runs `git log origin/main --since='14 days ago' --oneline -- <paths>` and `gh pr list --state merged --search '<symptom keywords>' --limit 5`, and checks the symptom against `origin/main` as it is now. A recent merge that removed the root cause → stop, report the PR, no code. On 2026-10-21 PR #31254 fixed a People-page filter that #31080 (merged the day before) had already made moot; Greg remembered, the agent and the brief did not. The parent checks the same thing before `workctl`, in one `gh pr list --search`.

**An agent that runs migrations or DB specs** gets the target database name in the brief, must quote any `*.env` URL that contains `&` (unquoted, the shell cuts it and the migration hits the wrong database: 13 migrations once landed on shared `main`), and must print the resolved database name before `prisma migrate deploy`. When it finishes, the parent checks `select max(finished_at) from prisma._prisma_migrations` on the shared `main` DB before calling it clean.

**A base that is an open PR will merge under the agent.** When the branch is stacked on someone else's open PR, say what to do when that PR merges: rebase onto the PR's own base (`git rebase --onto origin/<pr-base> origin/<old-base>`) and retarget its PR there. On 2026-09-29 the schema PR under ▸13 merged about 2 hours after the brief, and the brief still named it as the base.

## Stacked PRs: one worktree per stack, not per branch

A branch can be checked out in only one worktree, and `gh stack checkout` / `gh stack rebase` walk the whole stack sequentially in a single directory. Spread the layers across per-branch worktrees and every stack command dies with `'<branch>' is already used by worktree at ...`. Give the whole stack one worktree and let the agent move with `gh stack up/down/switch`.

This costs nothing in parallelism: layers of a stack are not independent anyway — a commit on layer N invalidates every layer above it. Parallelise across *stacks* and standalone PRs, not across layers of one stack.

Two things to put in a stack agent's brief:

- **Trunk is checked out in the main checkout**, so the stack worktree cannot check out `main` and a fetch into it is refused. Have the agent run `git -C <main-checkout> pull --ff-only` first, and fall back to `gh stack rebase --no-trunk` if the trunk step still fails.
- **Merged bottom layers produce phantom conflicts.** Squash-merged layers have different SHAs than their local commits, so `git cherry` reports them as absent and the rebase re-conflicts on changes already upstream. Tell the agent to take main's version there rather than resurrecting code main already dropped.

## Broadcasting one command to every running Claude agent

"Zaktualizuj wszystkie uruchomione agenty" (28ca873d):

1. `herdr agent list | jq` filtered to claude panes.
2. Skip a pane whose `❯` line is not empty: someone is typing there.
3. One agent first: `herdr agent prompt <pane> "<cmd>"`, `send-keys Enter`,
   read its result. Then the rest, ~1.5 s apart with
   `perl -e 'select(undef,undef,undef,1.5)'` (no `sleep`).
4. Never broadcast anything that writes `~/.claude/settings.json` (`/tui`):
   every session reloads it live anyway.

## Safety

- Never `send-keys` into a pane you haven't just `read` — you may be typing into Greg's live session (all his agents share the list; check `focused` and `cwd` before touching one you didn't start).
- No confirmed way to clear a half-typed input: `C-u`, `ctrl+u` and vim `esc d d i` all left the text in place (2026-10-05). If the input box already holds text, don't type a reply over it; tell Greg in one line.
- Never `worktree remove` a workspace you didn't create without Greg's confirmation; `--force` discards uncommitted work.
- Agents start in the global `defaultMode` (`acceptEdits`), not your session's mode — a briefed agent that stays `idle`/`blocked` is usually waiting on a Bash/MCP permission prompt (edits auto-accept, shell doesn't); read the pane before assuming failure. See mine 4.
- Before removing any worktree, audit it: `git status --porcelain`, `git rev-list --left-right --count @{u}...HEAD` for unpushed commits, and `herdr agent list` for agents whose `cwd` is inside it. Ignored files (`node_modules`) don't show in `status` but do make `worktree remove` need `--force` — and removal takes minutes per worktree because it deletes them.
- **Who changed a tab or pane?** `~/.config/herdr/herdr-server.log` logs every mutating call with its `request_id` (`cli:tab:create`, `cli:agent:prompt`, `auto-title-*`), but not reads like `tab list`. A missing `tab.create` there proves a script never asked for the tab (2026-10-21, `work` layout). `herdr pane list` → `.scroll.max_offset_from_bottom` = 0 on a busy pane means the app draws its own screen (Claude Code's fullscreen renderer), so its scrolling happens inside the app, not in herdr.
- `git stash` is shared across all worktrees of a repo (it lives in the common `.git`), so stashes survive `worktree remove`. A "1 stash" reading in every worktree is the same single stash, not one each.
