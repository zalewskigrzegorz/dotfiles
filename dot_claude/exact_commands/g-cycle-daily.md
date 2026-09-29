---
description: Draft and post the daily Shape Up cycle summary to the cycle's Slack channel — the overall status of the project (what's deployed, what works, what's decided), what's in flight, blockers and the next milestone, built from the day's delta — as Greg, through g-slack. Explicit-invoke command, stays out of context until /g-cycle-daily.
argument-hint: "[cycle name] [--since YYYY-MM-DDTHH:MM:SSZ]"
---

# /g-cycle-daily — daily cycle summary

One message a day in the cycle channel: where the project stands, what's moving,
what's blocked, how close the next milestone is. The live dashboard shows the tickets;
this message tells the story around them. Greg runs it by hand once a day.

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
- **No preview popup.** Print the draft as plain paragraphs and end the turn with
  "powiedz wyślij". This replaces g-slack's step-5 popup for this command.
- **Top-level message in the channel.** No `thread_ts`, unless Greg points at a thread.
- **`cycle-daily save` runs only after Slack returned `ok:true`.** A declined or failed
  draft leaves the old baseline, so the next run's delta still covers today.
- **English, Slack mrkdwn:** single `*bold*`, `•` bullets, backticks for code, no `#`
  headers, no `**`.
- **Draft with bare `#n`.** Step 6 escapes the text and turns every `#n` into a link
  mechanically; never hand-write `<url|#n>`.
- **Names, not logins.** First names from work-context § Roster. Greg's own work is "I".
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
(`Quiet day: nothing moved, X of Y still done.`) or skip today.

### 3. Draft

**Overall status, not a ticket list.** The reader wants to know where the project
stands; a list of closed tickets is hard to read in isolation (feedback from the
person who asked for these posts, 2026-09-29). Every post is a full, self-contained
status that makes sense to someone who skipped yesterday's. The delta tells you what
to update; it is not the content.

1. **Status, 2–4 short sentences, no bullets, no `#n`.** Open with the cycle position
   (`Week N of <weeks>.`), then the state of the system in product terms: what's
   deployed where, what works end to end, which decisions are settled. Group by
   capability ("SCIM, support and OAuth work"), never one sentence per ticket. When
   something moved since yesterday, say it here in plain words.
2. `*In progress*`: 1–3 bullets, the work being finished now and what it unblocks.
   A `#n` only for a PR or issue someone would act on (review, merge), one per bullet.
3. `*Blockers*`, only when there are any: what's stuck and on what. Numbers, not
   adjectives: unowned open work against `days_left`, PRs waiting on review 2+ days,
   changes requested, blockers from `activity`.
4. **Closing line: the next milestone and how close it is**, with a day when there's
   an estimate. Never "soon".

Leave out a section that has nothing in it. The whole post stays under ~10 lines.

Shape (anonymized; the requester's own example is in work-context):

```text
Week 2 of 4. The test env is up with seed data and the new schema is in. The big decisions are settled: OAuth clients move 1:1, passwords stay as they are so nobody resets, support keeps its current role, and SCIM sets roles from groups the same way SSO does.

*In progress*
• wiring the new provider into the auth server, the last piece before the first milestone
• review fixes on the schema PR #1100: billing permissions, plain-text tokens, DB tests in CI

*Blockers*
• 24 of 31 tasks open with 12 days left and only 3 have an owner. The OAuth provider and the bulk migration haven't started

First milestone (one migrated person signs in with their old password and the app loads): expecting it Thursday.
```

### 4. Voice it

Run the draft through `greg-voice`. Keep numbers, `#n`, backticks and the section
labels intact.

### 5. Show it and wait

Print the voiced draft as plain paragraphs (no fence, no popup), then one line:
target channel from work-context, "powiedz wyślij". Greg may trim or redirect; loop
on 3–5 until he says "wyślij".

### 6. Build the payload

Write the approved text to `<scratchpad>/cycle-daily-<YYYY-MM-DD>.txt`, then escape it
for Slack and link every `#n` (`/pull/` for PRs the snapshot knows, `/issues/`
otherwise):

```bash
TEXT=$(jq -Rrs --slurpfile d "<scratchpad>/cycle-diff.json" --arg repo "$WORK_MAIN_REPO" '
  ($d[0].state.prs | keys) as $prs
  | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;")
  | gsub("#(?<n>[0-9]+)"; .n as $n
      | "<https://github.com/\($repo)/\(if any($prs[]; . == $n) then "pull" else "issues" end)/\($n)|#\($n)>")
' "<scratchpad>/cycle-daily-<YYYY-MM-DD>.txt")
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
