---
description: Draft and post the daily Shape Up cycle summary to the cycle's Slack channel — what changed since the last one (closed tasks, PRs, status moves, owners, decisions from comments), what's in flight, and the risks — as Greg, through g-slack. Explicit-invoke command, stays out of context until /g-cycle-daily.
argument-hint: "[cycle name] [--since YYYY-MM-DDTHH:MM:SSZ]"
---

# /g-cycle-daily — daily cycle summary

One message a day in the cycle channel: what changed since the last summary, what's
moving, what's at risk. The live dashboard shows the tickets; this message tells the
story around them. Greg runs it by hand once a day.

> **All identifiers are private.** Read
> `~/.local/state/dotfiles/secrets/work-context.md` → **§ "Slack — cycle daily"** for
> the active cycle: channel, epic, board, feature branch, start date, length, the
> ready-made `cycle-daily` args line and the verbatim reference post. `source
> ~/.local/state/dotfiles/secrets/work.env` for `$WORK_MAIN_REPO` and
> `$WORK_SLACK_POSTER_TOKEN`. Never hardcode any of them here — this file is public.

## Hard rules

- **Nothing is posted without Greg's explicit "wyślij"** on the final text.
- **Send through `g-slack`** (user token, no footer). Don't reimplement the send;
  follow its steps 6–7 with the payload built in step 6 below.
- **The draft is longer than 15 lines, so there is no preview popup.** Print it as
  plain paragraphs and end the turn with "powiedz wyślij". This replaces g-slack's
  step-5 popup for this command.
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
| `first_run` | `true` = no baseline yet → full status, as in the reference post |
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

1. **Point-first line:** `Quick status, <day N | end of week N> of <weeks>: <the one
   thing that moved most>. X of Y tasks done.` It's "end of week N" when
   `day % 7 == 0`. X and Y come from `totals`; add the delta when it helps ("2 more
   since yesterday").
2. `*Done*`: what closed or merged since `since`. Say the decision or the effect in
   one clause, not the ticket title. On a later run list only the delta; never
   repeat yesterday's Done.
3. `*In progress*`: open work with a PR, an owner or an In progress status. Give the
   PR state (draft, waiting for review, changes requested) and what it unblocks.
   Say what moved since yesterday, not just that it's still open.
4. `*Risks*`: numbers, not adjectives. Unowned open work against `days_left`, big
   items with no PR and no owner, PRs waiting on review for 2+ days, changes
   requested, blockers from `activity`.
5. Closing line: `Next one tomorrow.` (Friday → `Next one Monday.`)

Leave out a section that has nothing in it. Keep each bullet to one or two lines.

Shape (anonymized; the verbatim first post is in work-context):

```text
Quick status, end of week 1 of 4: all the spikes are closed and we started building today. 7 of 31 tasks done.

*Done*
• kickoff decisions written up as ADRs (#1001)
• passwords: we keep the current hash cost, so hashes copy over as-is, no reset for anyone and revert stays trivial (#1012)
• support: the plugin can't do it, so we keep the old role and push impersonation to a next pitch (#1011)

*In progress*
• schema + migrations, PR #1100 (draft). I did a first review today: billing gets update rights it shouldn't, and the DB tests never run in CI
• mounting the new provider in the auth server (#1090). This blocks the first milestone: one migrated person signs in with their old password

*Risks*
• 24 open, only 3 have an owner. The big two, the OAuth provider (#1030) and the bulk migration (#1026), haven't started

Next one tomorrow.
```

### 4. Voice it

Run the draft through `greg-voice`. Keep numbers, `#n`, backticks and the three
section labels intact.

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
