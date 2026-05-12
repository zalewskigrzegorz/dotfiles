---
name: g-github-issue
description: Creates GitHub issues for REDACTED_ORG/REDACTED_ORG via gh CLI. Chooses template (bug vs maintenance explicitly when unclear), default label Team: REDACTED_TEAM, English issue bodies, confirmation before gh issue create. Use when the user wants a bug report, maintenance issue, feature request, idea, docs, epic, or onboarding issue.
---

# g-github-issue

## When to use

User wants to create an issue on **REDACTED_ORG/REDACTED_ORG** (e.g. "create issue", "file a bug", "maintenance ticket").

## Constants

- **Repo:** `REDACTED_ORG/REDACTED_ORG`
- **Default label:** `Team: REDACTED_TEAM` (exact spelling; pass as `-l "Team: REDACTED_TEAM"` unless the user specifies others)
- **Creation:** use **GitHub CLI only** — `gh issue create -R REDACTED_ORG/REDACTED_ORG`. Do not use MCP for creating issues unless the user insists.

## Language

All **generated** issue titles and body text must be **English**, even if the conversation is in another language.

## Bug vs maintenance

If the intent is ambiguous (error vs technical debt / initiative), **ask** explicitly: e.g. "Should this be a **Bug report** or a **Maintenance** issue?" Do **not** pick one by default.

## Issue types and title prefixes

| Type            | When to use              | Title prefix (if any)        |
|-----------------|--------------------------|-------------------------------|
| Bug report      | Defect, repro, expected vs actual | —                    |
| Feature request | New product capability   | —                             |
| Idea            | Idea to validate         | `[Idea] `                     |
| Maintenance     | Tech debt, initiative    | —                             |
| Epic            | Large multi-feature goal | `[Epic] `                   |
| Docs change     | Change existing docs     | `docs: `                      |
| New docs        | New documentation        | `docs: `                      |
| Onboarding      | Onboarding checklist     | `Onboarding checklist [full name]` |

Body structure per type: see [reference.md](reference.md). In the REDACTED_ORG workspace you may also read `.github/ISSUE_TEMPLATE/*.md`.

## Rules

1. **Ask when information is missing** — title, issue type, required sections. Do not guess critical details (repro steps, issue number for PR links, environment).
2. **Labels:** default `Team: REDACTED_TEAM` in addition to any the user requests.
3. **Before `gh issue create`:** show a short summary (repo, title, labels, body preview or full body) and ask for confirmation (e.g. "Proceed and create this issue?"). **Do not run** `gh issue create` until the user clearly confirms (yes / proceed / send).

## Flow

1. Determine **type**. If bug vs maintenance is unclear, ask (see above).
2. **Title:** ask if missing; apply prefixes per table.
3. **Body:** fill sections from [reference.md](reference.md) in **English**. Ask for missing sections.
4. **Labels:** include `"Team: REDACTED_TEAM"` by default.
5. **Confirm** with the user.
6. **Create** after confirmation:
   - Short body: `gh issue create -R REDACTED_ORG/REDACTED_ORG -t "Title" -b '...' -l "Team: REDACTED_TEAM"`
   - Long / multiline body: write to e.g. `/tmp/issue-body.md` then:

```bash
gh issue create -R REDACTED_ORG/REDACTED_ORG -t "Title" --body-file /tmp/issue-body.md -l "Team: REDACTED_TEAM"
```

Prefer `--body-file` for multiline content to avoid shell escaping issues.

## When gh is unavailable

If `gh` is missing or not authenticated (`gh auth status`), tell the user to install or log in. Do not switch to MCP unless the user asks.
