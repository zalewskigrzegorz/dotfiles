---
description: Always run outward-facing text (PRs, reviews, issues, Slack) through greg-voice
alwaysApply: true
---

# Outward-Facing Text — Always Voice It

Any text that leaves Greg's machine for other people to read MUST be passed
through the **`greg-voice`** skill before it is posted, created, or sent. This is
automatic — Greg should never have to ask for it.

## When this applies

Apply it to every external deliverable, including (not limited to):

- **PRs** — title and body (`g-pr`, `g-pr-fix-checks` descriptions)
- **PR reviews** — review summaries, inline comments, replies to reviewers
  (`g-pr-review`, `g-pr-bump`)
- **GitHub issues** — bodies and comments (`g-github-issue`)
- **Slack** — messages, replies, status updates, recaps
- Any commit-adjacent prose meant for humans, release notes, or other
  outward-facing writing

It does **not** apply to: code, commit messages (own rules), config, or internal
scratch/AI artifacts.

## How to apply

1. **One pass, `greg-voice`.** It strips the AI tells and puts Greg's tone in as
   a single edit. **Do not run `humanizer` before or after it** — that was the
   old two-step flow and it forced a second trip: humanizer flattens the live
   verbs, em dashes and uneven rhythm that the voice then has to rebuild.
   **One register everywhere, code review included.** A PR review comment or a
   reply to a reviewer gets the same casual, point-first voice as a Slack
   message — that is the point, not an exception. Casual does not mean vague or
   longer: exact paths, line numbers and versions stay, the stiff wrapper around
   them goes, and a terse nit stays terse.
2. **Leave structured template parts untouched** — do NOT let the voice layer
   rewrite changesets, `Reference` / `Fixes #` / `Closes #` links, checklists,
   templated headings, tables, or code blocks. Voice the prose around them; keep
   the scaffolding intact.
3. If a skill's own flow (e.g. `g-pr-review`) already drafts the text, run
   `greg-voice` over that draft before it leaves the machine.

## Slack — send through `g-slack`, as Greg

Slack has a second requirement on top of the voice: **identity.** Any message
that speaks as Greg goes out through the **`g-slack`** skill, which posts with
his personal user token (footer-free) after voicing the text. Never send a
Greg-reply through the claude.ai Slack MCP (`slack_send_message`) — it stamps
`*Sent using* @Claude` on every message, publicly.

- **Represents Greg** (a reply, an opinion, a decision, a DM) → `g-slack`: voiced
  + sent as Greg, no footer. This is the default for anything you'd type in a
  channel on his behalf.
- **Automation** that transparently didn't need his judgement — PR bumps
  (`g-pr-bump`), scheduled notifications, daily-brief drops — keeps the Claude
  footer and stays on its own flow. That footer is correct there, not a bug.

## When `humanizer` is still the right skill

`humanizer` remains a standalone tool for text that is **not** in Greg's voice —
docs, a README, someone else's draft he is cleaning up, anything where the goal
is "sounds less like AI" rather than "sounds like Greg". Outward-facing text in
his own name goes through `greg-voice` instead.
