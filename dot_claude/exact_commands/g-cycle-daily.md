---
description: Draft and post the daily Shape Up cycle summary to the cycle's Slack channel — a few short lines on where the project stands (what's deployed, what works, what's decided), what's in flight and the next milestone, in the format the requester set — as Greg, through g-slack. Explicit-invoke command, stays out of context until /g-cycle-daily.
argument-hint: "[cycle name] [--since YYYY-MM-DDTHH:MM:SSZ]"
---

# /g-cycle-daily — daily cycle summary

One short message a day in the cycle channel: where the project stands, what's
moving, the next milestone. The live dashboard shows the tickets; this message never
repeats them. Greg runs it by hand once a day.

> **All identifiers are private.** Read
> `~/.local/state/dotfiles/secrets/work-context.md` → **§ "Slack — cycle daily"** for
> the active cycle: channel, epic, board, feature branch, start date, length, the
> ready-made `cycle-daily` args line and the format examples. `source
> ~/.local/state/dotfiles/secrets/work.env` for `$WORK_MAIN_REPO` and
> `$WORK_SLACK_POSTER_TOKEN`. Never hardcode any of them here — this file is public.

## Hard rules

- **Nothing is posted without Greg's explicit "wyślij"** on the final text.
- **Send through `g-slack`** (user token, no footer). Don't reimplement the send;
  follow its steps 6–7 with the payload built in step 6 below.
- **No preview popup.** Print the draft as plain lines and end the turn with
  "powiedz wyślij". This replaces g-slack's step-5 popup for this command.
- **Top-level message in the channel.** No `thread_ts`, unless Greg points at a thread.
- **`cycle-daily save` runs only after Slack returned `ok:true`.** A declined or failed
  draft leaves the old baseline, so the next run's delta still covers today.
- **English, plain lines:** one fact per line, no bullets, no `*bold*`, no `#`
  headers, backticks only for code.
- **No ticket or PR numbers, no week counter, no blockers block, no names.** The
  requester doesn't want them (Greg, 2026-09-29: blockers built from ticket counts
  were noise).
- Testing or changing this command: produce the draft only, never post.

## Workflow

### 1. Load the cycle and fetch the delta

Take the active cycle from § "Slack — cycle daily" (a cycle name in `$ARGUMENTS`
picks another one; if two look active, ask). Then:

```bash
source ~/.local/state/dotfiles/secrets/work.env
A=(<args line from work-context>)   # --repo --epic --project --branch --start --weeks
cycle-daily diff "${A[@]}" > "<scratchpad>/cycle-diff.json"
```

`--since <ISO>` overrides the window for comments (e.g. Greg skipped a day and wants
only the last 24 h). `cycle-daily diff` also writes `<epic>.pending.json` next to the
snapshot; step 7 promotes it.

### 2. Read the delta

| Key | What it holds |
|---|---|
| `first_run` | `true` = no baseline yet, the delta lists are absent and `since` is the cycle start |
| `since` | baseline time (previous summary), or cycle start on the first run |
| `state.cycle` | `day`, `week`, `weeks`, `days_left` |
| `state.totals`, `totals_before` | `closed`/`total`, `open_unassigned`, `by_status` now and at the baseline |
| `closed`, `reopened` | sub-issues that changed state, with assignees and linked PRs |
| `added`, `removed` | scope changes in the epic |
| `status_moves` | board Status changes (`from` → `to`) |
| `assignee_changes` | owners `added` / `removed` |
| `prs_new`, `prs_merged`, `prs_closed_unmerged`, `prs_ready`, `prs_review` | PR movement: new, merged, dropped, draft → ready, review decision changed |
| `activity` | human comments and reviews on the epic, sub-issues and cycle PRs since `since`, 400-char `excerpt`, `url` |
| `state` | the full current state: every sub-issue (`status`, `assignees`, `prs`) and PR |

**Read `activity` properly.** Decisions, scope cuts and blockers live in comments,
not in ticket state. When an excerpt looks like a decision or a blocker and it's cut
off, read the whole comment: `gh issue view <n> --repo "$WORK_MAIN_REPO" --comments`
(or `gh pr view <n> --comments`).

**Nothing changed** (every delta list empty and no `activity`): tell Greg in one line
that nothing moved since `since`, and ask in a popup whether to post a one-liner
(`Quiet day, nothing moved.`) or skip today.

### 3. Draft

**Copy the requester's example line for line** (work-context § "Format … asked
for"). Three blocks, a handful of short lines, readable in five seconds. Three drafts
on 2026-09-29 missed it: paragraphs, review details, names, ticket numbers, a week
counter, a blockers block built from ticket counts. The delta tells you what changed;
the post only says where the project is.

1. **Status, 2–4 lines**, one short sentence each (≤ ~10 words): what's deployed
   where, what works, what's settled. Cumulative, so someone who skipped every
   earlier post gets the whole picture. Group by capability ("SCIM, support and
   OAuth work").
2. `In progress:`, then 1–3 lines, each the work itself in a few words ("Merge the
   schema PR", "Mount the new auth in the auth server").
3. **Last line: the next milestone**, one short sentence.

A blank line between blocks, nothing else. Under ~8 lines.

Shape (anonymized; the requester's own example is in work-context):

```text
The test env is up with seed accounts.
The member split is on main.
Passwords and OAuth clients move over as they are.

In progress:
Merge the schema PR
Mount the new auth in the auth server
Bulk migration of users and passwords

First milestone after the schema merge and the mount.
```

### 4. Voice it

Run the draft through `greg-voice`. Keep the line structure intact: the voice may
swap words, never merge lines into sentences or add detail.

### 5. Show it and wait

Print the voiced draft as plain lines (no fence, no popup), then one line:
target channel from work-context, "powiedz wyślij". Greg may trim or redirect; loop
on 3–5 until he says "wyślij".

**Re-check state before the final draft and before the send.** The delta is a
snapshot, and the iterations take a while: on 2026-09-29 the diff ran at 12:57, the
schema PR merged at 13:11, and the draft still said "Merge the schema PR" until
Greg caught it. Before showing a revised draft and again right before step 6, check
every PR and issue the draft relies on (`gh pr view <n> --json state,mergedAt`,
`gh issue view <n> --json state`). When the diff is older than 15 minutes, rerun
`cycle-daily diff` instead.

### 6. Build the payload

Write the approved text to `<scratchpad>/cycle-daily-<YYYY-MM-DD>.txt`, then escape it
for Slack:

```bash
TEXT=$(jq -Rrs 'gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;")' \
  "<scratchpad>/cycle-daily-<YYYY-MM-DD>.txt")
```

### 7. Send, then save the baseline

Send `$TEXT` to the cycle channel through `g-slack` step 6 (no `thread_ts`). On
`ok:true`, take the returned `ts` and promote the baseline:

```bash
cycle-daily save "${A[@]}" --slack-ts <ts>
```

Then verify per g-slack step 7 (posted as Greg, no footer) and give Greg the
permalink. On `ok:false`, report the error and don't save.

## New cycle

When a cycle ends, Greg updates § "Slack — cycle daily" in work-context (epic, board,
branch, start, length, channel) and pushes it to 1Password — `bin/sync` overwrites the
local file from the vault (see `docs/secrets.md`). The first run of the new cycle has
no snapshot and produces a full status. Snapshots live in
`~/.local/state/dotfiles/cycle-daily/<epic>.json`, one per epic.
