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

## A request to another team: one thread, one message per ask

A Slack hand-off to support or another team was corrected three times in one
session (fba8a1cf, 2026-10-12: "za dużo informacji! 1 wątek na support i
osobne wiadomości").

- **Top-level = one sentence** saying what this is about. Each ask is its own
  message in the thread, and each opens with what we are asking for.
- **Greg owns only the tasks he named himself.** Everything else is written as
  a request to the reader. If ownership is unclear, ask him before drafting:
  "nie, ja mogę tylko baner, status page nie jestem w stanie".
- **Things he will attach himself** (a screenshot, a link) are not mentioned in
  the text.

## Telling a customer to trace an email — search criteria, not our ID

When the outward-facing text asks someone (a customer, their IT, a partner's
admin) to check whether an email arrived, give them **sender address + subject +
timestamp window** — the fields an Exchange or Google message trace actually
searches on. **Never hand over our internal SES `Message-ID`**: it is opaque
outside our system and useless until they already hold the message. Caught on a
draft to a customer's admin, 2026-09-22 ("id mu przecież nic nie da").

## Customer-facing text promises only what the source says

Status page, customer mail, banner (805e0816, 2026-10-13, "to jest zle nie
owinelismy tego tak piosac"):

- **Take only what the source marks as public or what Greg said himself.** An
  internal technical note is not a promise. "nobody needs to reset anything"
  was our inference; cut such a sentence or label it `propozycja` before it goes.
- **"Uprość, bez technicznych detali" swaps jargon for plain words; it does
  not delete facts.** Every sentence that tells the reader they must act ("orgs
  using SCIM must update their config") stays. How it works underneath can go.

## Before drafting an issue on someone else's repo

`gh issue list -R <owner/repo> --search "<keywords>" --state all` first. A hit
→ a comment (+1 with our case) instead of a new issue, and its number goes in
the first line of the reply. A full draft was thrown away for an open duplicate
on 2026-10-13 (72209d68).

## UI strings you write

Messages, alerts, empty states, tooltips: short sentences, no `;`, no `—`. Two
sentences instead of one joined by a semicolon. One look for `[;—]` in the diff
after writing them. "te copy jest ai generated, ma `;`" (2fcb7035). This is
product text in code, not replies to Greg.

## A reader's example is the spec

When the person who reads the output gives an example of the format they want
("e.g. …"), copy it line for line: same blocks, same line length, same labels,
same markup or lack of it. Don't carry over sections, bullets, bold, ticket
numbers, counters or estimates from the old format, and don't "improve" it. What
the example doesn't show stays out unless Greg asks for it.

After changing a skill or command that produces that output, run it once
draft-only on real data and put the draft next to the example before committing.

Caught 2026-09-29 on `g-cycle-daily`: the rewrite kept bold, bullets, `#n`, a
week counter and blockers; stripping them took 3 drafts.

## When `humanizer` is still the right skill

`humanizer` remains a standalone tool for text that is **not** in Greg's voice —
docs, a README, someone else's draft he is cleaning up, anything where the goal
is "sounds less like AI" rather than "sounds like Greg". Outward-facing text in
his own name goes through `greg-voice` instead.
