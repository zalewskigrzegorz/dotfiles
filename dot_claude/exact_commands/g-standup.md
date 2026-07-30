---
description: Fill in Greg's daily standup on Slack — gather work-only activity since the last standup (PRs, monorepo commits, meetings, memory), confirm interactively, draft the answers in the team's terse bullet style, and auto-send to the standup bot DM via Greg's own Slack user token (no "Sent using Claude" footer). Not a skill, so it stays out of context until invoked with /g-standup.
---

# /g-standup — daily standup autofill

Fill Greg's daily standup. The standup bot DMs four questions; his answers post
publicly to the team standup channel. Gather what he did (work only), let him
confirm/trim, then send the answers **as Greg** (no Claude footer) via his
personal Slack user token.

> **All identifiers are private.** Read
> `~/.local/state/dotfiles/secrets/work-context.md` → **§ "Slack — standup"** for
> the bot user ID, bot DM channel, public standup channel, and the fixed question
> list. `source ~/.local/state/dotfiles/secrets/work.env` for `$WORK_GITHUB_ORG`,
> `$WORK_MAIN_REPO`, `$WORK_PROJECT_DIR`, **and `$WORK_SLACK_STANDUP_TOKEN`** (the
> footer-free user token — already in the env file, so **never `op read` at
> runtime**; no vault prompt). Never hardcode any of these here.

## Hard rules (learned the hard way — do not relitigate)

- **Never send without Greg's explicit confirmation** of the full drafted set.
  He must also pick what's included (interactive, step 4).
- **Send via the user token + `chat.postMessage`, NOT the Slack MCP.** The
  claude.ai Slack MCP appends `*Sent using* @Claude` to every message — it shows
  publicly on the standup channel, on every line. The user token posts cleanly
  as Greg. **Reads go through the Slack MCP** (`slack_read_channel`, no footer on
  reads) — the standup token is `chat:write` only and **cannot** read history, so
  don't waste a call trying `conversations.history` with it.
- **Blocker answer is `no`, never `-`.** Slack turns a leading `-` into an empty
  bullet (`•  `) on the public post. `no` / `none` render fine.
- **Plain text only — no link markup.** The bot mangles Slack `<url|text>` links
  into garbage. Bare `#24671` is fine; skip `<…>`.
- **Work only.** Exclude personal repos (dotfiles, bazgroly, home-lab, anything
  under `~/Code/personal`). No home/pets/side-project items.
- **The bot sleeps between messages.** After each send it often replies "Please,
  give me a minute… 💤" and takes ~40–60 s to post the next question. Poll the DM
  until the real next question appears; skip the sleep line and the plan-echo.

## Workflow

### 1. Check there's an active standup

Read the bot DM via the Slack MCP (`slack_read_channel`, channel from
work-context, newest ~6 messages). Confirm the bot
is currently prompting (a recent "It's time for today's stand up!" / an
unanswered question). It only accepts answers while asking; if the last standup
is finished ("Thank you! Have a nice day"), tell Greg there's nothing open and
stop. Note which question is on screen — that's where sending resumes.

### 2. Window = since the last standup

Default: **since the last working day.** Mon → include Fri + weekend; otherwise
= yesterday. Compute the cutoff date, use it for every source. Greg can override
("tylko dziś", "od czwartku").

### 3. Gather work-only activity (parallel)

```bash
source ~/.local/state/dotfiles/secrets/work.env
CUT=<cutoff YYYY-MM-DD>

# PRs (shipped + in-flight) across the work org
gh search prs --author @me --owner "$WORK_GITHUB_ORG" --updated ">=$CUT" \
  --json number,title,state,url,repository,updatedAt --limit 30 \
  | jq -r '.[] | "[\(.state)] #\(.number) \(.title)"'

# Commits in the monorepo (all branches, Greg's authors)
git -C "$WORK_PROJECT_DIR" log --author='zalewski\|Grzegorz\|maksim009' \
  --since="$CUT" --all --no-merges --pretty=format:'%cI %s'

# Meetings attended in the window (transcript optional for a 1-line takeaway)
spark meetings --filter "newer_than:<N>d"
```

Ambient context (don't over-weight): `mcp__hindsight__recall query="work shipped
decisions focus <topics>"` filtered to the window; optionally skim recent AI
sessions under `~/.claude/projects/*/` if PRs/commits are thin.

**Distill, don't dump.** Collapse many commits on one topic into one bullet.
Merge a PR and its commits into one line. Merged/open PRs → "did"; open/WIP PRs +
in-progress issues + today's meetings → "will do today".

### 4. Confirm what to include (interactive — required)

Present candidates grouped by question (did / will / blockers). Ask Greg what to
keep, cut, merge, add. He drives this ("połącz X i Y", "wywal Z", "feel = ok").

### 5. Draft the answers

English, terse, `•` bullets, plain text, team style (short imperative fragments,
PR numbers bare). Match the four questions from work-context in order.

### 6. Get explicit go-ahead

Show the full set. Wait for a clear yes. No yes → don't send.

### 7. Send sequentially with the user token

Fetch once (never echo it):

```bash
TOKEN=$(op read "<token path from work-context>")
# sanity: [[ "$TOKEN" == xoxp-* ]] || fall back to draft-only (step 9)
```

Loop, one question at a time:

1. Read the bot DM; find the **current** question.
2. Match it to the drafted answer **by content** (feel / did / will / blockers),
   not blind position. If a question doesn't match the known four, **pause and
   ask Greg**.
3. Send the matching answer:

```bash
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-type: application/json" \
  -X POST https://slack.com/api/chat.postMessage \
  -d "$(jq -n --arg c "$BOT_DM" --arg t "$ANSWER" '{channel:$c,text:$t}')" \
  | jq '{ok, error}'
```

4. **Poll for the next question**: re-read the DM every ~15–20 s (wait via a
   `run_in_background` sleep, not foreground). Ignore the "give me a minute" line
   and the plan-echo. Stop when a new, different question appears — or when the
   bot says "Thank you! Have a nice day" (done). Up to ~90 s per step before
   flagging a stall.

Repeat through all four. Blocker answer = `no`.

### 8. Verify

Read the public standup channel (id from work-context, newest message); confirm
Greg's update posted with all four sections and **no footer**. Report the
permalink.

### 9. Fallback — draft-only

If the token is missing/invalid, the bot isn't prompting, or Greg prefers to send
himself: **don't auto-send.** Output the four answers as clean copy-paste blocks
for him to paste. Gather → confirm stays the same.

## Notes

- The bot stores "yesterday's plan" and echoes it under Q2 — a nudge, not
  something to answer.
- Run before the bot has kicked off the day's standup → nothing to answer yet;
  say so and stop.
- Token setup lives in work-context; if it stops working, reinstall the Slack app
  and repaste the token into the 1Password item.
