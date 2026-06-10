---
name: g-pr-bump
description: Posts a friendly bump in the `#pull-requests-review` Slack thread for a Redocly PR, tagging only teams/users that have not approved yet. Use when Greg says "bumpnij PR", "pingnij teamy", "pingnij na slacku", "remind reviewers", "wyślij bump", "still need approvals", or otherwise asks to nudge reviewers on his open PR.
---

# g-pr-bump

## When to use

Greg wants to remind reviewers on one of his open Redocly PRs by replying in the PR's thread in `#pull-requests-review` (channel ID `C060SJ1TSSG`). PR Review Bot posts one parent message per PR; the bump goes as a reply in that thread.

## Out of scope

- Cross-repo bumps. This skill assumes `Redocly/redocly` PRs. For other repos, ask Greg whether to use the same approach.
- Sending a *new* top-level message. Always reply in the bot's thread.
- Tagging individuals other than the explicitly pending reviewer. Don't @ Roman, Adam, etc. on a whim.

## Workflow

### 1. Identify the PR

- If user gave a PR number → use it.
- Else `gh pr view --json number,headRefName` from current branch.
- Save PR number as `$PR`.

### 2. Get pending reviewers from GitHub (source of truth)

```bash
gh api repos/Redocly/redocly/pulls/$PR --jq '{requested_reviewers: [.requested_reviewers[].login], requested_teams: [.requested_teams[].slug]}'
gh api repos/Redocly/redocly/pulls/$PR/reviews --paginate --jq '[.[] | select(.state == "APPROVED") | .user.login]'
```

`requested_reviewers` + `requested_teams` = still pending. Anyone already in the approved list **must not** be bumped — even if Greg lists them. Always re-check before pinging.

### 3. Locate the Slack thread

```
slack_search_public query='in:#pull-requests-review "pull/<PR>"'
```

Take the most recent match from `PR Review Bot` (ID `U07HGCNQT5G`) — that's the parent message. Capture its `message_ts`. Channel is always `C060SJ1TSSG`.

If no match, double-check the PR is in `Redocly/redocly` (this channel doesn't host `redocly-cli` PR bots the same way).

### 4. Compose the bump

**Mention syntax via Slack API (`slack_send_message`):**

| Target | Format | Example |
|---|---|---|
| User group (subteam, ID prefix `S`) | `<!subteam^SID>` | `<!subteam^S06MUG7997T>` |
| Individual user (ID prefix `U`) | `<@UID>` | `<@U02BC4URYJJ>` |

**Do NOT use** `<@SID|name>` for subteams — Slack renders it as literal text when posted via API. The `<!subteam^SID>` form is the only one that pings.

**Optional handle override:** `<!subteam^SID|@handle>` (with leading `@` in the handle text) renders the same pill, useful when you want explicit visible handle text.

Template:

```
Friendly bump 🙏 — still need approvals from <!subteam^TEAM1>, <!subteam^TEAM2>, <@USER>
```

Keep it short. One sentence. No "Sorry" or "Sent retry" prefixes. No commentary about what's blocking. Just the ask.

### 5. Send

```
slack_send_message
  channel_id: C060SJ1TSSG
  thread_ts: <bot message_ts from step 3>
  message: <composed bump>
```

The integration adds a "Sent using Claude" footer automatically. You cannot suppress it via MCP — it's app-level. Tell Greg if he asks.

### 6. Verify (optional)

`slack_read_thread` to confirm the reply landed. If the message contains `<!subteam^` raw text instead of pills, it failed — the workspace bot may lack `usergroups:read` or the ID is wrong. Don't repost — ask Greg.

## Team ID reference

Maintain inline; expand as new teams are discovered. Always verify by searching recent `#pull-requests-review` messages for `<!subteam^...|name>` patterns.

| Team handle | Subteam ID |
|---|---|
| config-governance | `S06MUG7997T` |
| dark-side | `S041WEV2WD7` |
| hot-dogs | `S07RFH0EP98` |
| cyberpunks | `S048XMRP1RD` |
| lightsabers | `S064N40CAG0` |
| keyboard-warriors | `S041L9PL57W` |
| quality-assurance | `S07JVEUGQ2J` |
| borsch-team | `S041HRREL90` |
| to-the-moon-team | `S052V187R1R` |
| blips-and-chitz | `S041HNL89U3` |
| plug-and-play | `S064E6ECDK2` |
| protoss | `S0A4A8DRZD2` |
| technical-writers | `S05KQHWSCLW` |
| staff-engineers | `S070LA1NS9Z` |
| replay-team | `S078L2V2YNL` |

GitHub team slug ↔ Slack subteam mapping is usually 1:1 (e.g. `config-governance` GitHub team = `<!subteam^S06MUG7997T>`). Don't invent IDs.

## Confirm before posting

Slack writes affect shared state. Always show Greg the composed message and the resolved pending reviewers list, then wait for explicit confirmation ("tak", "wyślij", "ok") before calling `slack_send_message`. Don't proactively re-bump on a thread that already has a fresh bump in it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Pinging a team that already approved | Always run the `/reviews` query in step 2 first. |
| `<@S048XMRP1RD\|cyberpunks>` rendering as text | Use `<!subteam^S048XMRP1RD>` instead. API does not parse `<@SID...>` for groups. |
| Posting outside the thread | `thread_ts` MUST be set to the bot's parent message ts. |
| Repeating bumps within an hour | Don't. Wait at least a few hours, or use a different angle (DM the specific person). |
| Adding individuals not requested as reviewers | Stick to `requested_reviewers` + `requested_teams` from GitHub. Don't @ random people. |

## Notes

- Channel `#pull-requests-review` purpose explicitly invites bumps: "Just post a link to PR and tag the relevant team."
- The `Sent using Claude` footer is integration-controlled. To remove it, change the app config at workspace-admin level; otherwise Greg should bump manually.
- Related skills: `g-pr-fix-checks` (rebase + retrigger CI), `g-pr-review` (respond to reviewer comments).
