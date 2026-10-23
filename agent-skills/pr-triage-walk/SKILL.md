---
name: pr-triage-walk
description: Walk Greg's open PRs one by one and get a decision for each — rebase by an agent, refresh/update, close, or leave. Use when he says "przeleć moje PR-y", "przejdźmy po moich prkach", "interaktywnie po otwartych PR-ach", "co z moimi starymi draftami", "triage my PRs". NOT for keeping PRs green autonomously (that's babysit-prs) and NOT for work on one PR (g-pr-*).
---

# pr-triage-walk

Born from ecc92e2d (2026-10-23): Greg said "jest tego 9", there were 11, old
drafts went into one "co zamykamy, niezaznaczone zostają" multi-select, and a
PR he wanted refreshed was reported as "zostawione bez zmian".

## Steps

1. **One list.** `gh search prs --author @me --state open --owner
   "$WORK_GITHUB_ORG" --json number,title,isDraft,updatedAt,url,repository
   --limit 50` (source `work.env` first). The first line of the reply is the
   count and the list, oldest first. If Greg named a different count, say so
   right there ("mówiłeś 9, jest 11: …").
2. **One popup per PR**, same four options every time, the PR's title, age and
   check state in the question's context line:
   - **Rebase przez agenta** — spawn per `herdr-orchestration` and the model
     score in `subagent-model-by-weight`.
   - **Odśwież / zaktualizuj** — rebase on `main` and re-check, here or by an
     agent; for an old draft, also re-read whether it still makes sense.
   - **Zamknij** — `gh pr close <n> --comment "<why>"` with a voiced one-line
     reason; delete the branch only if he says so.
   - **Zostaw** — nothing.
   Never batch several PRs into one multi-select: an unticked box is not a
   decision.
3. **Reconcile at the end.** Compare the list from step 1 with the decisions.
   Every PR without an explicit answer gets its own question before the
   summary. The summary is one line per PR: number as `<url|#n>` when it goes
   to Slack, decision, what was started.

Reviewers and authors in any popup are full names via `work-people`.
