---
description: Fill in Greg's daily standup on Slack — gather work-only activity since the last standup (PRs, monorepo commits, meetings, memory), confirm interactively, draft terse bullets, and send to the standup bot DM with his own user token (no "Sent using Claude" footer). Explicit-invoke command.
---

# /g-standup

The standup bot DMs four questions; answers post publicly to the team standup channel. Gather (work only), let Greg trim, send **as Greg**.

> **Identifiers are private:** `~/.local/state/dotfiles/secrets/work-context.md` § "Slack — standup" (bot user ID, bot DM, public channel, the four questions); `source ~/.local/state/dotfiles/secrets/work.env` for `$WORK_GITHUB_ORG`, `$WORK_MAIN_REPO`, `$WORK_PROJECT_DIR`, `$WORK_SLACK_POSTER_TOKEN` (never `op read` at runtime).

## Hard rules

- Never send without his explicit yes on the full set; he picks what's included (step 4).
- **Send** with the user token (`standup-send`), never the Slack MCP (its footer shows publicly on every line). **Read** through the Slack MCP (`slack_read_channel`): the token is `chat:write` only.
- Slack MCP tools are deferred: `ToolSearch("select:mcp__claude_ai_Slack__slack_read_channel")` first, never conclude they're absent. Still "No matching deferred tools" while `claude mcp list` shows Connected → the session needs a restart (or another session does the reads). No Chrome automation of app.slack.com as a first resort.
- Blocker answer `no`, never `-` (a leading `-` becomes an empty bullet). Plain text, no `<url|text>` links (the bot mangles them); bare `#24671` is fine.
- Work only: no dotfiles, bazgroly, home-lab, `~/Code/personal`, home, pets, side projects.

## 1. Active standup?

`slack_read_channel` on the bot DM (newest ~6). Bot asking ("It's time for today's stand up!", unanswered question) → note which question is on screen. Finished ("Thank you! Have a nice day") or not started → say so and stop.

## 2. Window

Since `~/.local/state/dotfiles/standup-last`; no file → last working day (Monday includes Fri + weekend). Greg may override ("tylko dziś", "od czwartku").

## 3. Gather (parallel)

```bash
source ~/.local/state/dotfiles/secrets/work.env; CUT=<YYYY-MM-DD>
gh search prs --author @me --owner "$WORK_GITHUB_ORG" --updated ">=$CUT" --json number,title,state,url,repository,updatedAt --limit 30 \
  | jq -r '.[] | "[\(.state)] #\(.number) \(.title)"'
git -C "$WORK_PROJECT_DIR" log --author='zalewski\|Grzegorz\|maksim009' --since="$CUT" --all --no-merges --pretty=format:'%cI %s'
spark meetings --filter "newer_than:<N>d"
jq -r --arg cut "$CUT" 'select(.ts >= $cut) | "\(.ts[0:10]) \(.cwd | sub(".*/"; "")) [\(.branch)] \(.title)  \(.sid)"' \
  ~/.local/state/dotfiles/claude-task-log.jsonl | sort -u     # session titles: catches review/analysis with no PR
```

- Drop personal folders. Open one session transcript (`~/.claude/projects/*/<sid>.jsonl`) only when its title is too thin.
- **PRs reviewed:** one `gh api graphql` `search(type: ISSUE, first: 50)` → `reviews(last: 30)`, `comments(first: 30)`, counted in `jq` by `createdAt >= today`, to a scratch file (`reviews(last:100)` with nested comments exceeds the 500,000 node limit).
- **Work without a PR:** `git -C <main checkout> worktree list --porcelain | rg '^(worktree|branch) '` (a glob over `~/Code/tree/wt-<repo>/*` hits type dirs), then per tree `git status -sb` and `git log --oneline origin/main..HEAD`; drafted as "bez PR-a" for him to confirm.
- Ambient only: `mcp__hindsight__recall(query="work shipped decisions focus <topics>", max_tokens=512)` filtered to the window.
- **Distill:** many commits on one topic → one bullet; a PR and its commits → one line. Merged/open PRs → "did"; WIP PRs, in-progress issues, today's meetings → "will do". Merged-or-not from PR state (`gh pr list --search <sha> --state all --json number,state` for a stray commit), not `git branch --contains`.

## 4. Confirm (required)

Every non-private meeting in the window is a "did" candidate (a5239d4c). Show candidates grouped did / will / blockers; Greg keeps, cuts, merges, adds.

## 5. Draft

English, terse `•` bullets, plain text, team style, bare PR numbers, the four questions in order. "How do you feel": one neutral line ("ok, could be better"), never a health detail, never "feel good" by default: it's public (7665ab21).

## 6. Go-ahead

Full set as plain text + "powiedz wyślij", no popup (a5239d4c). No clear yes → no send.

## 7. Send

Per question, in order: match the question on screen to the answer **by content** (feel / did / will / blockers; unknown question → pause and ask), then `standup-send "$BOT_DM" "$ANSWER"` (Bash timeout 150000). It posts as Greg, polls every 5 s, prints the next bot message (skips the "give me a minute… 💤" line and the plan echo, which needs no answer). Exit: `0` next message · `124` no reply in 120 s (sent; never resend, check the DM once) · `1` post failed · `3` posted but history unreadable · `2` usage/no token. Never hand-poll with `slack_read_channel` + `sleep`.

Exit 3 / `missing_scope`: history needs `im:history`; until Greg adds it, reinstalls the app and updates 1Password, read the DM via the Slack MCP once per answer after ~60 s. Never resend.

## 8. Verify

Read the public channel once (newest): all four sections, no footer. Report the permalink, then `date +%FT%T%z > ~/.local/state/dotfiles/standup-last` (stops the `standup-pending` nudge, sets the next window).

## 9. Draft-only fallback

Token missing/invalid, bot not prompting, or Greg sends himself: four copy-paste blocks, same gather/confirm; write `standup-last` once he says it's sent. Token broken → reinstall the Slack app and repaste into the 1Password item (setup in work-context).
