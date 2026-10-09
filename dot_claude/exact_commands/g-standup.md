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
> `$WORK_MAIN_REPO`, `$WORK_PROJECT_DIR`, **and `$WORK_SLACK_POSTER_TOKEN`** (the
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
  don't try `conversations.history` by hand with it (`standup-send` does, and
  reports `missing_scope` if the scope is still missing).
- **Blocker answer is `no`, never `-`.** Slack turns a leading `-` into an empty
  bullet (`•  `) on the public post. `no` / `none` render fine.
- **Plain text only — no link markup.** The bot mangles Slack `<url|text>` links
  into garbage. Bare `#24671` is fine; skip `<…>`.
- **Work only.** Exclude personal repos (dotfiles, bazgroly, home-lab, anything
  under `~/Code/personal`). No home/pets/side-project items.
- **The bot sleeps between messages.** After each send it often replies "Please,
  give me a minute… 💤" and takes ~40–60 s to post the next question. `standup-send` waits
  for the real next question; skip the sleep line and the plan-echo.
- **Slack MCP tools are DEFERRED — they are absent from the visible tool list
  until loaded.** Do NOT conclude "no Slack MCP in this session". Load them
  first: `ToolSearch("select:mcp__claude_ai_Slack__slack_read_channel")` (add
  other `mcp__claude_ai_Slack__*` tools to the same call as needed), then call
  them normally. If ToolSearch returns "No matching deferred tools found" even
  though `claude mcp list` shows the connector Connected, the tools never
  registered in THIS session (stale long-lived session) — tell Greg the session
  needs a restart, or hand the Slack reads to another session that has them.
  Don't burn time on Chrome automation of app.slack.com as a first resort.

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
in-progress issues + today's meetings → "will do today". Merged or not comes
from the PR state in the list above, or `gh pr list --search <sha> --state all
--json number,state` for a stray commit — not `git branch --contains`: an empty
`$sha` from `git log --grep` failed four times with `malformed object name`
(2026-10-06).

### 4. Confirm what to include (interactive — required)

Present candidates grouped by question (did / will / blockers). Ask Greg what to
keep, cut, merge, add. He drives this ("połącz X i Y", "wywal Z", "feel = ok").

### 5. Draft the answers

English, terse, `•` bullets, plain text, team style (short imperative fragments,
PR numbers bare). Match the four questions from work-context in order.

### 6. Get explicit go-ahead

Show the full set. Wait for a clear yes. No yes → don't send.

### 7. Send sequentially with the user token

One script does send + wait: `standup-send <bot DM channel> <answer>` (`bin/standup-send`,
reads `$WORK_SLACK_POSTER_TOKEN` itself, never echoes it). It posts the answer as
Greg, then polls `conversations.history` every 5 s and prints the bot's next
message (skipping the "give me a minute" sleep line) as soon as it lands.

For each of Q1-Q4, in order:

1. Take the question currently on screen (from step 1, then from the script's
   output). Match it to the drafted answer **by content** (feel / did / will /
   blockers), not blind position. If it doesn't match the known four, **pause and
   ask Greg**.
2. Run `standup-send "$BOT_DM" "$ANSWER"` (Bash timeout 150000). Output = next
   question text, or "Thank you! Have a nice day" after Q4.
3. Exit codes: `0` next message printed · `124` no reply in 120 s (answer WAS
   sent, never resend, check the DM once) · `1` post failed (error printed) ·
   `3` posted but history unreadable, see below · `2` bad usage / no token.

Blocker answer = `no`. Don't hand-poll with `slack_read_channel` + `sleep`; that
cost 13 reads and 6 sleeps for four answers (2026-10-09).

**Exit 3 / `missing_scope`:** the `slack-poster` token has `chat:write` only, and
history needs `im:history` (verified 2026-10-09). Until Greg adds the scope to the
app, reinstalls it and pastes the new token into 1Password, fall back to reading
the DM through the Slack MCP once per answer after ~60 s. The answer was already
sent, so never resend.

### 8. Verify

Read the public standup channel **once, now** (id from work-context, newest message); confirm
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
