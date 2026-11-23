---
name: g-pr-bump
description: Posts a short bump in the PR-review Slack thread of Greg's work PR, tagging only teams/users that have not approved yet. Use for "bumpnij PR", "pingnij teamy", "pingnij na slacku", "remind reviewers", "wyślij bump", "still need approvals", or any nudge to reviewers on his open PR.
---

# g-pr-bump

A reply in the PR Review Bot's thread for the PR, in the review channel.
Channel ID, bot user ID and the GitHub team → Slack subteam table live in
**work-context** (`~/.local/state/dotfiles/secrets/work-context.md`, §Slack —
PR review flow): read it first, never invent IDs (verify a missing one from
recent `<!subteam^…|name>` patterns in the channel; slugs usually equal handles).

Main-monorepo PRs only; another repo → ask Greg. Never a new top-level message.
Tag only pending reviewers. This is automation, so the MCP's "Sent using Claude"
footer stays (app-level, can't be removed from here; to avoid it Greg bumps by hand).

## Flow

1. **PR**: the number given, or `gh pr view --json number,headRefName`.
2. **Pending = source of truth on GitHub**, re-checked every time:
   ```bash
   gh api "repos/$WORK_MAIN_REPO/pulls/$PR" --jq '{requested_reviewers: [.requested_reviewers[].login], requested_teams: [.requested_teams[].slug]}'
   gh api "repos/$WORK_MAIN_REPO/pulls/$PR/reviews" --paginate --jq '[.[] | select(.state == "APPROVED") | .user.login]'
   ```
   Requested minus approved. An approver is never bumped, even if Greg lists them.
3. **Thread**: `slack_search_public query='in:#<review-channel> "pull/<PR>"'`,
   the newest hit from PR Review Bot = parent, take its `message_ts`. No hit →
   check the PR is in the main monorepo.
4. **Compose**, one sentence, no "Sorry"/retry prefixes, no commentary:
   `Friendly bump 🙏 — still need approvals from <!subteam^TEAM1>, <@USER>`.
   Subteams `<!subteam^SID>` (or `<!subteam^SID|@handle>`); users `<@UID>`.
   `<@SID|name>` for a subteam renders as plain text.
5. **Confirm**: show Greg the text and the pending list, wait for "tak" /
   "wyślij" / "ok". No re-bump on a thread with a fresh bump (wait hours, or DM
   the one person).
6. **Send**: `slack_send_message` with the review `channel_id`, `thread_ts` =
   the bot's ts, the message.
7. **Verify** (optional): `slack_read_thread`. Raw `<!subteam^` text instead
   of pills = wrong ID or missing `usergroups:read`: ask Greg, don't repost.

Related: `g-pr-fix-checks` (rebase + CI), `g-pr-respond` (answer reviewers).
