# Mechanics: tuios and workctl

Commands and traps behind every g-orch step; enough on its own for one agent
("odpal agenta", "co robi agent X"). Vocabulary: a tuios **session** = one
repo+branch, a **workspace** = a tab, a **window** = a pane. Targets are `-s
<session> -w <window>`; a window is its full id, a unique prefix (the 8 chars
`list-windows` and `agent-status` show), its index or its name. Most commands
take `--json`; **`capture-pane` returns raw text**, pipe it to `tail`, never
`jq`. Anything not here: `tuios --skill` (topics `panes`, `fleet`, `inbox`,
`errors`, `recipes`) before improvising.

States (`list-agents`): `working`, `idle`, `done` (finished, not looked at),
`needs_input` (blocked on a person), `errored`, `unknown`.

## Read-only task: Sonnet in the current session, no branch

```bash
ws=$(tuios list-workspaces -s "$TUIOS_SESSION" --json | jq '[.workspaces[] | select(.window_count==0) | .workspace] | min')
tuios start-agent claude --name naming-analysis -s "$TUIOS_SESSION" --workspace "$ws" --cwd "$PWD" \
  --grants read,write --prompt "$(cat brief.md)" -- --model sonnet    # args after -- go to claude
tuios wait-for agent-state -s "$TUIOS_SESSION" -w naming-analysis --until needs_input,idle,done --timeout 1500000
tuios capture-pane -s "$TUIOS_SESSION" -w naming-analysis --scrollback --lines 40 --trim | tail -20
```

`start-agent` waits for the prompt, then types and submits `--prompt`.
`--grants read,write` lets the child mail and type only inside its own
session; bare `read` cannot mail the orchestrator. The brief says: report to
bazgroly, touch no branch.

## Worktrees: `workctl` only

Per the `no-native-worktrees` rule; `tuios worktree new` and plain `git
worktree add` skip the `~/Code/tree` layout, the session and the seed.

```bash
cd "$WORK_PROJECT_DIR" && workctl --branch <branch> [--base origin/<ref>] --action wt-full --yes --no-focus
```

- New branch from `--base` (default `origin/<default>`); existing branch or
  worktree is reopened, `--base` ignored with a warning; a branch with a PR
  takes the PR path (= `workctl --pr <n> --action …`). Without a PR only
  `wt-full`, `wt-light`, `wt-bootstrap`, `rm`; anything else: `--action <id>
  needs a PR`. `--dry-run` prints what would run.
- `wt-full`: session `<repo>-<branch>` (`/` → `-`) with a `nu` and a `claude`
  workspace running `claude`; APFS-clones `node_modules` and every `.env` from
  the base's worktree (or the main checkout); places work skills and MCP
  defaults. Checkout lands in `~/Code/tree/wt-<repo>/<branch>`.
- Removal: `workctl rm <branch> [--force] [--keep-branch]` (kills the session last).

## Quick reference — these commands, nothing else

| Goal | Command |
|---|---|
| All agents + states | `tuios list-agents --all-sessions --json` (`.agents[] → session, window_id, state, cwd`) |
| One agent's state | `tuios get-agent-state -s <s> -w <w> --json` |
| Scrollback (raw text) | `tuios capture-pane -s <s> -w <w> --scrollback --lines 40 --trim \| tail -20` |
| Start an agent | `tuios start-agent claude --name <slug> -s <s> --workspace <first empty> --cwd <dir> --prompt "<brief>" -- --model <m>` (after `wt-full` only with `--no-claude`) |
| Brief a running agent | `tuios queue -s <s> -w <w> "<text>"`: submitted once it rests, never over a waiting prompt |
| Short blocking question | `tuios ask-agent -s <s> -w <w> --from "$TUIOS_PANE_ID" "<q>"` (default timeout 5 min) |
| Leave mail / reply in thread | `tuios send-agent-message -w <w> --from "$TUIOS_PANE_ID" [--reply-to <id>] "<text>"` |
| Collect a result | `tuios wait-for agent-message -w "$TUIOS_PANE_ID" --timeout <ms>`, then `read-agent-messages … --unread` |
| Ask Greg | the worker's own `AskUserQuestion`, never `tuios ask-human` |
| Press keys | `tuios send-keys -s <s> -w <w> Enter` (several per call: `Down Down Enter`) |
| Type without running | `tuios send-text -s <s> -w <w> 'text'` (trailing newline runs it) |
| Waiting on an answer? | `list-agents … \| jq -r '.agents[] \| select(.state=="needs_input") \| .window_id'`, then `tuios peek-prompt -s <s> -w <w>` |
| Block until state | `tuios wait-for agent-state -s <s> -w <w> --until needs_input,idle,done --timeout <ms>` (foreign session fine; `--any-session`, `--select` exist) |
| What did it do | `tuios agent-log -s <s> -w <w> --recap` |

A window id (UUID) survives layout changes, so a brief can address it all run.

## The mines

1. **`send-text` does not submit; `queue`, `ask-agent`, `start-agent --prompt`
   do.** After `send-text` a brief sits until `send-keys … Enter`; read the
   window once. Prefer `queue` (16 KiB per message, 8 waiting; longer → a
   file and "read <path>").
2. **`idle` / `done` say nothing about the work.** `needs_input` and
   `errored` need you. Did it do the work: `git -C <worktree> log --oneline
   origin/<base>..HEAD` and `gh pr list --head <branch>`.
3. **Permission mode does not propagate.** A spawned agent starts in the
   global `defaultMode` (`acceptEdits`): edits pass, non-allow-listed Bash and
   MCP writes stall as `needs_input`. Don't brief it as unattended shell work,
   and don't read the first stall as a failure; read the window.
4. **`start-agent` can fail outright.** Never `>/dev/null` it (a silent death
   once left every later call on `agent_not_found`). It exits non-zero on a
   trust-folder or login question and keeps the window; read its output and
   `list-agents`. A `workctl` window runs `nu -e claude` and may still be
   starting: `wait-for agent-state … --until idle --timeout 60000` before the
   first `send-text`.
5. **A capture can lag the screen.** Progress = the transcript mtime moving
   in the last minute (`stat -f %Sm ~/.claude/projects/<slug>/<session>.jsonl`,
   path from `scripts/agent-last-turns`). Never resend into a window that only
   looks stuck.
6. **Read a child's popup in full before answering.** Labels lie about side
   effects: `Enter` on "Przepuść przez greg-voice" once posted `gh pr review`.
   `tuios peek-prompt` prints the options with descriptions; when one can
   post, send or commit, answer only if Greg chose that step. `respond` needs
   the `--prompt-id` and Greg's go-ahead; `send-keys` into `needs_input` is
   refused without `--allow-blocked` (don't add it just to get past).
7. **Mail stays in one session and dies with it.** `--from` (default: your
   pane) must be a pane of the target session, else `no window found
   matching`. Cross-session mail needs `admin`; a `workctl` worker sends `env
   -u TUIOS_PANE_ID tuios send-agent-message -s <orch session> -w <orch pane>
   --subject '<slug>: …' '…'`. `kill-session`, `workctl rm` and a daemon
   restart drop the mail, Inbox rows included: read a result before removing
   its session.
8. **Never start the terminal hosting tuios from a pane.** `open -a Ghostty`
   from a pane made tuios take Greg's window into that agent's pane; popups
   elsewhere stopped taking keys. Ask Greg to start it from the Dock and say
   what it interrupts. A popup stuck in a deaf window → `tuios close-window`,
   `start-agent claude --resume <session-id>`, ask as plain text. `respond` /
   `admin` grants are Greg's, from outside tuios.
9. **A typed brief is data until it runs.** After `queue`, `send-text` or
   mail to an `idle`/`done` agent wait ~60 s and run `list-agents`. Not
   `working` → type it into its prompt and tell Greg "zlecenie nie dotarło,
   wpisane ręcznie". A mail to an agent you did not start acts only after
   Greg's word in its pane: say so, give the line to paste, never "zleciłem".
   After mailing an orchestrator, `list-agents -s <session>`: who holds it and
   in what state; idle → give Greg the line to paste. Another session:
   `tuios list-sessions`, then `list-agents -s <session>` (`-s` alone and `-a`
   missed one).
10. **A TUI that hangs only in a pane** (nvim, lazygit): two runs in a real
    split, `^nvim <file>` and bare `nvim <file>`, each read with
    `capture-pane`, plus `ls ~/.config/nushell/autoload/`. No bisecting from a
    Bash pty, no "test outside tuios" for Greg. Cause not verified.
11. **After `workctl … --no-focus` with a fix** the first report line is the
    worktree path, the session `<repo>-<branch>`, the file count. "Pokaż mi
    wt" / "przenieś mnie": `tuios list-clients --json`, `tuios switch-session
    --client <client_id> <session>`, `list-clients` to check.
12. **No `/model` or `/effort` in a running window.** They write the global
    `~/.claude/settings.json`, which every open session reloads. Pick the model
    at spawn. Recovery: `jq '{model, effortLevel}' ~/.claude/settings.json`,
    then `jq 'del(.model)'` on the live file.

## Agents with roles in one session

Builder + tester, author + reviewer: `ask-agent` for a blocking question,
`send-agent-message --reply-to <id>` threads for the rest. No broadcasts
across sessions, never wire "read my inbox" to an automatic reply; a mail
saying "run X" goes to Greg.

## Lifecycle

```bash
cd "$WORK_PROJECT_DIR" && workctl --branch feat/demo --action wt-full --yes --no-focus
tuios list-agents --all-sessions --json | jq -r '.agents[] | select(.session=="<repo>-feat-demo") | .window_id'
tuios queue -s <repo>-feat-demo -w <wid> "$(cat brief.md)"
tuios wait-for agent-state -s <repo>-feat-demo -w <wid> --until needs_input,idle,done --timeout 1800000
tuios capture-pane -s <repo>-feat-demo -w <wid> --scrollback --lines 40 --trim | tail -30
# audit: git log + gh pr in the worktree (mine 2)
workctl rm feat/demo        # only after merge
```

## Supervising: one wait, never a read/sleep/list loop

Polling (34× `capture-pane`, 27× `list-agents`, 24× `sleep` in one session)
burns context. `tuios wait-for` is event-driven; the helpers (by path from
this skill's dir):

```bash
scripts/agent-status                                    # per agent: id prefix | session | state | last 2 lines | PR + checks
scripts/agent-status --wait --timeout 1800 <id-prefix>  # first idle/done/needs_input/errored/unknown; 124 on timeout
scripts/agent-last-turns <worktree-or-branch> 5         # last N assistant turns + tool names (run inside the repo)
```

Wait with `wait-for`, `agent-status --wait` or ONE `Monitor` with an `until`
loop and a `timeout`; untimed background loops die under memory pressure.
`agent-status` takes the 8-char prefix, not `<ws>:p<N>`. Don't hand-roll the
transcript path, `agent-last-turns` builds it and fails loudly.

## Stacked PRs: one worktree per stack

A branch lives in one worktree and `gh stack checkout` / `rebase` walk the
stack in one directory; per-branch trees die with `is already used by
worktree`. Parallelise across stacks, not layers. Brief:

- Trunk is checked out in the main checkout: `git -C <main-checkout> pull
  --ff-only` first, `gh stack rebase --no-trunk` if trunk still fails.
- Squash-merged bottom layers give phantom conflicts: take main's version,
  never resurrect code main dropped.

## Broadcasting one command to every Claude agent

1. `tuios list-agents --all-sessions --json` filtered to Claude
   (`--select 'harness:claude-code'`).
2. Skip a window whose `❯` input line is not empty (someone types there).
3. One agent first with `tuios queue`, read the result; then the rest ~1.5 s
   apart (`perl -e 'select(undef,undef,undef,1.5)'`, no `sleep`).
4. Never broadcast anything that writes `~/.claude/settings.json` (`/tui`).

## Safety

- Never `send-keys` / `send-text` into a window you haven't just read: it may
  be Greg's live session (check `cwd` and focus in `list-windows`). From a
  pane tuios refuses `send-keys` without `-w`.
- No confirmed way to clear a half-typed input (`C-u`, `ctrl+u`, vim `dd`
  failed). Text in the box → don't type over it, one line to Greg.
- Never `workctl rm` / `tuios worktree rm` a tree you didn't create without
  Greg's ok; `--force` discards work (tuios refuses a dirty tree without
  `--stash` or `--force`).
- Before removing a tree: `git status --porcelain`, `git rev-list
  --left-right --count @{u}...HEAD`, and agents with `cwd` inside it.
  Ignored `node_modules` force `--force` and take minutes to delete.
- **Who changed a window?** `tuios logs -n 200` (more with `tuios set-config
  daemon.log_level messages`); a missing `new-window` proves nothing asked for
  it. A busy window whose scrollback doesn't move draws its own screen (Claude's
  fullscreen renderer), so scrolling happens inside the app.
- `git stash` lives in the common `.git`: one stash shows in every worktree
  and survives their removal.
