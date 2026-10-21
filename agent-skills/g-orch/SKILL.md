---
name: g-orch
description: Greg's standing agent orchestrator. Takes a list of things to do (private and work, mixed), splits it into agent briefs, picks model and effort per task weight, spawns herdr agents or worktrees, supervises with one watcher, and comes back with results and the decisions only Greg can make. Trigger on "będziesz moim orchestratorem", "orkiestruj", "rozdziel to agentom", "odpal to agentami", "lista rzeczy do zrobienia na dziś", "/g-orch", or any message that is a list of 3+ unrelated tasks. Builds on herdr-orchestration (the mechanics) and subagent-model-by-weight (the model table).
---

# g-orch — the day's orchestrator

Greg hands over a list; the orchestrator runs it. Greg sees results and
decisions, not tool calls. Verified on 2026-10-21: 6 tasks, 9 agents, ~1 h,
3 Slack replies, 2 reviews, 1 PR, 4 drafts.

## 1. Read the list, state the reading

One line per item: what it is, which kind, where it runs, which model. Then
spawn; don't ask about the split unless an item is ambiguous.

| Kind | Example | Where | Score → model (`subagent-model-by-weight`) |
|---|---|---|---|
| Mail / document draft | kancelaria, dealer, urząd | tab in the personal workspace, `use-spark`, `pdf-form-pl` | 0 → Sonnet medium |
| Lookup / digest | Slack since Thursday, standup transcript, "what did X say" | tab in the work workspace, read-only | 0–1 → Sonnet medium |
| PR review draft | "Roman's PR, explain why it's wrong" | tab in the work workspace on `main`, read-only | +2 argue +2 schema +1 history → Opus high |
| Code change | a fix, a filter, a migration | `workctl --branch … --action wt-full`, then the agent | +3 PR (+2 multi-package) → Sonnet high / Opus high |
| Needs data from Greg | a contract, a form with his PESEL | spawn anyway with what the scans and mail hold; placeholders for the rest | 0 → Sonnet medium |

The score is computed from the brief, said in the spawn line, and never
changed on a running agent.

Items that only Greg can do (a 2FA, a signature, a payment) stay on his list
with one line each, no agent.

## 2. Brief template

Every brief is the child's whole world. Always:

- the task in one sentence, the sources (Spark, Slack links, PR number), the
  skills to use by name;
- **READ-ONLY** or **CODE**; read-only briefs list the forbidden commands
  (`no gh pr review, no gh api -X POST, no gh pr comment, no Slack send, no
  branch`), not just "don't post";
- the output path in bazgroly (`~/Code/personal/bazgroly/<repo>/analysis/
  YYYY-MM-DD-<slug>.md` for work, `…/bazgroly/scratch/notes/` for private);
- a closing line: "3–5 lines: done, missing, what you need from Greg";
- for code: the base, the worktrees other agents own, "present a plan and
  wait for ok", `g-commit` + `g-pr` draft, and the "is the bug still there"
  check from herdr-orchestration before the first edit.

Greg's stance goes into the brief verbatim when the task is an argument (a
review, a reply): the agent argues it with evidence from the repo, it doesn't
invent a position.

## 3. Spawn

herdr-orchestration owns the mechanics; the order that works:

```bash
herdr tab create --workspace <ws> --cwd <dir> --label <slug>      # one tab per read-only agent
herdr agent start <slug> --kind claude --pane <pane> -- --model <opus|sonnet>
herdr agent wait <pane> --until idle --timeout 60000               # mine 5: start returns early
herdr agent prompt <pane> "$(cat brief.md)" && herdr agent send-keys <pane> Enter
herdr agent read <pane> | grep -v '^\s*$' | tail -3                  # the title shows the brief → landed
```

Code tasks: `workctl … --action wt-full --yes --no-focus`, find the pane by
`cwd` in `herdr agent list`, `/model opus` first, then the brief. Say the
spawn line once: "5 agentów: 2× Opus (PR, review), 3× Sonnet (maile, Slack),
ETA ~15 min".

## 4. Supervise

One background watcher for all panes:

```bash
scripts/agent-status --wait --timeout 1500 <pane> <pane> …   # from herdr-orchestration
```

On return: `agent_status` per pane; `blocked` → read the popup in full (mine
7) and answer only what Greg already decided; `done` → read the report file,
not the pane. A pane that looks stuck → transcript mtime (mine 6).

Greg hears from the orchestrator when: a result needs his decision, an agent
is blocked on something only he knows, or everything is done. Not per pane.

## 5. Hand back

Per finished item, 1–3 lines: the result, the file path, what's missing. A
Slack reply or a GitHub comment never leaves from a child: the child drafts,
the orchestrator runs `g-slack` / posts via `gh api` after Greg's popup. A
result that duplicates recent work (a PR already fixed by another) is closed,
not "left for review".

Close the day with a status block: done / waiting on Greg / dropped, and the
one or two things the orchestrator skipped.

## Never

- Spawn on Fable without Greg naming it for that spawn.
- Let a child post, send or commit on its own; the brief forbids it by
  command name.
- Poll panes in a loop; one watcher, then act.
- Ask Greg about the split or the model when the table answers it.
