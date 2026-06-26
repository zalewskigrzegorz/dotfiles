---
description: Always humanize + voice outward-facing text (PRs, reviews, issues, Slack)
alwaysApply: true
---

# Outward-Facing Text — Always Humanize + Voice

Any text that leaves Greg's machine for other people to read MUST be passed
through the **`humanizer`** skill and then the **`slack-voice`** skill before it
is posted, created, or sent. This is automatic — Greg should never have to ask
for it.

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

1. **`humanizer` always, on the whole text** — strip the AI tells (inflated
   symbolism, rule-of-three, em-dash overuse, "it's not just X, it's Y", filler,
   etc.) from everything that goes out.
2. **`slack-voice` on the free prose** — give it Greg's tone (casual, point-first,
   just the meat) for: PR descriptions, review comments, replies, issue bodies,
   Slack messages.
3. **Leave structured template parts untouched** — do NOT let the voice layer
   rewrite changesets, `Reference` / `Fixes #` / `Closes #` links, checklists,
   templated headings, tables, or code blocks. Voice the prose around them; keep
   the scaffolding intact.

## Order

humanizer → slack-voice → post. If a skill's own flow (e.g. `g-pr-review`) already
drafts the text, run both passes on that draft before it leaves the machine.
