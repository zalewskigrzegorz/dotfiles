---
description: Always run outward-facing text (PRs, reviews, issues, Slack) through greg-voice
alwaysApply: true
---

# Outward-Facing Text: Always Voice It

Every text that leaves Greg's machine for other people (PR titles and bodies, PR reviews, inline comments, replies to reviewers, GitHub issues and comments, Slack messages, release notes, other human-facing commit-adjacent prose) goes through the **`greg-voice`** skill before it is posted, created or sent, unasked. Not for code, commit messages (own rules), config, or internal AI artifacts.

## How

1. **One pass, `greg-voice`.** It strips AI tells and puts his tone in at once. **No `humanizer` before or after**: it flattens the live verbs, dashes and uneven rhythm the voice then rebuilds. **One register everywhere, code review included**: casual, point-first; exact paths, line numbers and versions stay, the stiff wrapper goes, a terse nit stays terse.
2. **Leave template scaffolding untouched**: changesets, `Reference` / `Fixes #` / `Closes #` links, checklists, templated headings, tables, code blocks. Voice the prose around them.
3. A skill that drafts the text itself (`g-pr-review`) still gets `greg-voice` over the draft before it leaves.
4. **The first draft Greg sees is already voiced**, in prose and in a popup `preview` (68513abd). **Every new draft and every edit after his remark gets its own full pass** over the whole text: a skill loaded for an earlier comment doesn't voice the next, and "puszczałeś przez greg voice?" came twice after hand edits. A comment with measurements: the conclusion first, one line per fix with one number, no mechanism.
5. **His own pasted draft is not rewritten.** "Popraw / uzupełnij" keeps his wording: fix typos, mark added points as `propozycja` and an unchecked one "nie weryfikowałem"; `greg-voice` only on request (e4228afc).

`humanizer` stays for text that is not in his voice: docs, a README, someone else's draft.

## Slack: send through `g-slack`, as Greg

Anything that speaks as Greg (reply, opinion, decision, DM) goes through **`g-slack`**: voiced and sent with his user token, no footer. Never the claude.ai Slack MCP `slack_send_message` for that: it stamps `*Sent using* @Claude` publicly. Automation that needs no judgement (PR bumps via `g-pr-bump`, scheduled notifications, daily-brief drops) keeps the Claude footer on its own flow.

**A request to another team: one thread, one message per ask** ("za dużo informacji! 1 wątek na support i osobne wiadomości", fba8a1cf). The top-level is one sentence on what this is about; each ask is its own thread message opening with what we ask for. Greg owns only the tasks he named; everything else is a request to the reader, and unclear ownership is asked before drafting. Things he attaches himself (screenshot, link) are not mentioned.

## What the text may say

- **Customer-facing text (status page, customer mail, banner) promises only what the source marks public or Greg said himself.** An internal note is not a promise: cut our inferences ("nobody needs to reset anything") or label them `propozycja` (805e0816). **"Uprość, bez technicznych detali"** swaps jargon for plain words, it does not delete facts: every sentence telling the reader to act stays.
- **A mail or message in Greg's name carries only his facts and asks**, including a `spark draft` he reads first and a `g-slack` draft. Run `greg-voice` on a mail to a notary, court, office or firm too. No acceptance, offer or promise he did not state (a price, an action he'd take): make it a question to him or leave it out. Unknown facts stay unknown ("nie wiem, czy…"). "Zapytaj X czy …" is a question, no recommendation he did not give; facts you checked go on their own line above the draft.
- **A team announcement states no company plan he did not give** ("before lde becomes our default"): a question to him or cut (bb7f0a72).
- **Text committed to a shared repo is English** (skills, docs, comments); check the whole touched file, frontmatter and trigger lists too, not only the added lines.
- **Work done with an agent is "I" outward**, "we" only when he speaks for the team.
- **A review comment about a finding** gives the effect for a user and one ask; function names and mechanism stay in the verdict to Greg.
- **Telling someone to trace an email**: sender address + subject + timestamp window, never our internal SES `Message-ID` ("id mu przecież nic nie da").

## Before drafting an issue on someone else's repo

`gh issue list -R <owner/repo> --search "<keywords>" --state all` first. A hit → a comment (+1 with our case) instead of a new issue, its number in the first line of the reply (72209d68).

## UI strings you write

Messages, alerts, empty states, tooltips: short sentences, no `;`, no `—` (two sentences instead). One look for `[;—]` in the diff after writing them ("te copy jest ai generated, ma `;`").

## A reader's example is the spec

When the reader of an output gives an example of the format ("e.g. …"), copy it line for line: same blocks, line length, labels, markup or its absence. Carry nothing over from the old format (sections, bullets, bold, ticket numbers, counters, estimates) and don't "improve" it; what the example doesn't show stays out unless Greg asks (`g-cycle-daily` took 3 drafts). After changing a skill or command that produces it, run it once draft-only on real data and compare with the example before committing.
