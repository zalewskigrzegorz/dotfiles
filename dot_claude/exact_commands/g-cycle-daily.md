---
description: Draft and post the daily Shape Up cycle summary to the cycle's Slack channel (what landed, what's in flight, next milestone) in the requester's format, as Greg through g-slack. Explicit-invoke command.
argument-hint: "[cycle name] [--since YYYY-MM-DDTHH:MM:SSZ]"
---

# /g-cycle-daily

One short daily message in the cycle channel: where the project stands, what moves, the next milestone. The dashboard shows tickets; this never repeats them.

> **Identifiers are private:** `~/.local/state/dotfiles/secrets/work-context.md` § "Slack — cycle daily" (channel, epic, board, branch, start, length, the `cycle-daily` args line, format examples); `source ~/.local/state/dotfiles/secrets/work.env` for `$WORK_MAIN_REPO`, `$WORK_SLACK_POSTER_TOKEN`. Never hardcode them here.

## Hard rules

- Posted only after Greg's "wyślij" on the final text, through `g-slack` steps 6–7 (user token, no footer). No preview popup: plain lines + "powiedz wyślij" replace g-slack's step 5.
- Top-level in the channel, no `thread_ts` unless he points at a thread.
- `cycle-daily save` only after Slack returned `ok:true` (a failed draft keeps the old baseline).
- Format: the requester's example line for line (`external-output-voice.md` "A reader's example is the spec"): English, one fact per line, no bullets, bold, headers, ticket/PR numbers, week counter, blockers block or names.
- Testing or changing this command: draft only, never post.

## 1. Load and diff

Active cycle from § "Slack — cycle daily" (`$ARGUMENTS` may name another; two active → ask):

```bash
source ~/.local/state/dotfiles/secrets/work.env
A=(<args line from work-context>)   # --repo --epic --project --branch --start --weeks
cycle-daily diff "${A[@]}" > "<scratchpad>/cycle-diff.json"   # also writes <epic>.pending.json
```

`--since <ISO>` overrides the comment window. Keys: `first_run`, `since`, `state.cycle` (`day`, `week`, `weeks`, `days_left`), `state.totals`/`totals_before`, `closed`, `reopened`, `added`, `removed`, `status_moves`, `assignee_changes`, `prs_new|merged|closed_unmerged|ready|review`, `activity` (human comments/reviews since `since`, 400-char `excerpt`, `url`), `state` (every sub-issue and PR).

**Read `activity` properly:** decisions, scope cuts and blockers live in comments. A cut-off excerpt that looks like one → `gh issue view <n> --repo "$WORK_MAIN_REPO" --comments` (or `gh pr view`).

Nothing changed → one line, and a popup: post `Quiet day, nothing moved.` or skip.

## 2. Draft

Read the previous top-level post first: today's must not repeat its unchanged lines.

```text
Done:
<2–4 lines, ≤ ~10 words each: deployed, merged, working, decided; grouped by capability>

In progress:
<1–3 lines, the work in a few words; carries over only while still open>

<next milestone, one sentence>
```

The milestone must change once what it waited on landed: check it against every `Done:` line and the open sub-issues. Under ~10 lines.

## 3. Voice, show, re-check

`greg-voice` may swap words, never merge lines or add detail. Print as plain lines + target channel + "powiedz wyślij"; loop until "wyślij". Before every revised draft and right before sending, re-check every PR/issue the draft relies on (`gh pr view <n> --json state,mergedAt`, `gh issue view <n> --json state`); diff older than 15 min → rerun `cycle-daily diff`.

## 4. Send and save

```bash
TEXT=$(jq -Rrs 'gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;")' "<scratchpad>/cycle-daily-<YYYY-MM-DD>.txt")
```

Send via `g-slack` step 6. On `ok:true`: `cycle-daily save "${A[@]}" --slack-ts <ts>`, verify per step 7, give the permalink. `ok:false` → report, don't save.

## New cycle

Greg updates § "Slack — cycle daily" and pushes it to 1Password (`bin/sync` restores from the vault, `docs/secrets.md`). First run has no snapshot and gives a full status. Snapshots: `~/.local/state/dotfiles/cycle-daily/<epic>.json`.
