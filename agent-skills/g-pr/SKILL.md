---
name: g-pr
description: Creates or updates a GitHub PR with gh and the repo's pull_request_template.md (changesets in the work monorepo, no-changeset-needed label, Fixes/Closes links), ready for review with auto-merge. Use when the user wants to open a PR or refresh a PR title/body.
---

# g-pr

Create a PR, refresh its title/body, or align it with the template, once
commits exist on the branch.

## Text

- Title and body in **English**. Body through `greg-voice` before create/edit:
  voice only the prose (What/Why/How?, Reference, Testing); template headers
  and every checkbox stay exactly. Voicing never expands: Brevity wins.
- Read `.github/pull_request_template.md` and keep all headers and checkboxes.
- No source changes beyond what the user allows (e.g. a changeset file).
- **Title**: `type(scope): subject`, types from `commitlint.config.js` (work
  monorepo: `feat`, `fix`, `docs`, `chore`, `tests`, `hotfix`). Gitmoji optional.

## Brevity (overrides everything)

- **What/Why/How? ≤3 short lines**: what changed; why only when not obvious;
  how only when surprising. One line is ideal.
- Never enumerate the diff (no per-file bullets, no "Changes:"), no context
  essays, no selling ("This PR introduces/enhances/ensures", "comprehensive",
  "robust", "seamless", benefit lists).
- **Testing** = one line of what you ran or clicked. **Reference** = bare links.
- In doubt, cut: 4 lines good, 20 lines failed.

## Sections

| Section | Content |
|---|---|
| What/Why/How? | per Brevity |
| Reference | links (Slack, docs, issues); a PR that closes an issue gets `Fixes #123` / `Closes #123` on its own line; others `Related #456` |
| Testing | one line |
| Check yourself / Security | boxes matching reality |

`Fixes #n` only when the user said it, the branch name carries the number by
a clear convention, or an existing body references it. Otherwise ask, never guess.

## Changesets (work monorepo)

User-facing Reunite → `pnpm changeset:reunite --empty`; Realm →
`pnpm changeset:realm --empty`; copy per
`docs/intranet/engineering/changelog-process.md`. Not user-facing → no
changeset, label `no-changeset-needed` (if the label exists).

## Create vs update

1. `gh auth login` if needed. Push (`git push -u origin HEAD`) when asked and
   allowed; say so if the environment can't push.
2. Existing PR? `gh pr view --json number,title,url` or `gh pr list --head
   "$(git branch --show-current)" --json number,url`.
3. **None → create ready for review, auto-merge on:**
   ```bash
   gh pr create --title "<type>(<scope>): <subject>" --body-file <tmp>/pr-body.md [--label no-changeset-needed]
   gh pr merge <number> --auto --squash
   ```
   - `--squash` when allowed, else `gh repo view --json viewerDefaultMergeMethod`.
   - `auto merge is not allowed` → one line, PR stays ready, no retry.
   - **Draft, no auto-merge only when Greg (or the brief) says so** ("draft",
     "bez auto-merge", "nie merguj sam"); the body then says why and what
     unblocks it, in Greg's words. Brief and Greg differ → Greg wins.
   - A PR stacked on another open PR gets auto-merge too (GitHub retargets it).
4. **Trim auto-requested reviewers.** CODEOWNERS requests a team for every
   matched path, incidental files included (copy strings, generated files,
   flag registries). Check `gh pr view <n> --json reviewRequests --jq
   '[.reviewRequests[] | .name // .login]'`; extra teams → list them with the
   triggering paths, ask which to drop, then `gh api -X DELETE
   repos/<owner>/<repo>/pulls/<n>/requested_reviewers -f
   'team_reviewers[]=<Team>'`. Removal does not waive a ruleset
   `require_code_owner_review`.
5. **E2e (work monorepo)** runs only on `pull_request: labeled`. "See e2e on
   CI" → `gh pr edit <n> --add-label run_e2e`, then `gh run list --branch
   "$(git branch --show-current)" --workflow e2e.yml --limit 1 --json
   databaseId,url`. Re-run after a push = remove and re-add the label.
   `reunite-e2e-dispatch` is a lab test of dispatched jobs, not PR e2e.
6. **PR exists → refresh**: `gh pr edit <n> --title "…" --body-file
   <tmp>/pr-body.md`. A small body may go through a heredoc if the template
   structure stays.

Comments on a PR follow `../g-pr-common/PRIMITIVES.md` P5.
