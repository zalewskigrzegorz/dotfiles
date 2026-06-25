---
name: g-pr
description: Creates or updates a GitHub PR using gh CLI and the repo pull_request_template.md, changesets for Redocly, no-changeset-needed label when appropriate, and Fixes/Closes issue links in Reference. Use when the user wants to open or refresh a PR body/title.
---

# g-pr

## When to use

User wants to create a PR, update PR description, or align with the project PR template (after commits exist on a branch).

## Language

All **generated** PR title and body content must be **English**, even if the conversation is in another language.

Always run the **generated PR body through the `humanizer` skill** before creating/updating the PR — strip AI tells (em dashes, significance-inflation, rule-of-three, promotional filler). Keep the template headers and every checkbox exactly; humanize only the prose in `What/Why/How?`, `Reference`, and `Testing`.

## Constraints

- Do **not** change source code except what the user explicitly allows (e.g. creating a changeset file via the commands below).
- Read `.github/pull_request_template.md` from the repo and **preserve** all section headers and checkboxes; only fill in content.

## Title

Same convention as commits: `type(scope): subject` with types from repo `commitlint.config.js` when present (Redocly: `feat`, `fix`, `docs`, `chore`, `tests`, `hotfix`). Gitmoji on the PR title is optional; match the latest or main commit if helpful.

## Body sections

| Section | Content |
|---------|---------|
| What/Why/How? | Short summary: what changed, why, how. |
| Reference | Links to Slack, docs, issues. **If this PR should close a GitHub issue when merged**, add a closing keyword on its own line: `Fixes #123` or `Closes #123` (GitHub recognizes these in the PR description). Use the exact issue number—if unknown, **ask**; do not guess. Also include any non-closing references as normal links or `Related #456`. |
| Testing | How the change was tested. |
| Check yourself | Check/uncheck boxes to match reality. |
| Security | Check boxes when applicable. |

### Detecting linked issues

Infer `Fixes #n` / `Closes #n` only when the user stated it, the branch name contains the issue number in a clear convention, or an existing PR body already references that issue. Otherwise ask for the issue number.

## Changesets (Redocly monorepo)

When working in **redocly** with user-facing changes:

- **Reunite** user-facing: run `pnpm changeset:reunite --empty`
- **Realm** user-facing: run `pnpm changeset:realm --empty`
- **Not user-facing:** skip changeset and add label `no-changeset-needed` on the PR (if the label exists in the repo).

Changeset copy: follow `docs/intranet/engineering/changelog-process.md`.

## GitHub CLI prerequisites

- `gh auth login` if needed.
- `git push -u origin HEAD` before create (or ensure branch is pushed). **Do not assume sandbox allows push**—warn if push cannot run in the environment.

## Create vs update PR

1. Push the branch if the user asked to open/update the PR and push is allowed.
2. Check whether a PR already exists for the current branch, e.g.:

```bash
gh pr view --json number,title,url 2>/dev/null
```

or `gh pr list --head "$(git branch --show-current)" --json number,url`.

3. **If no PR:** create one (default **draft** unless the user wants a ready PR):

```bash
gh pr create --draft --title "<type>(<scope>): <subject>" --body-file /tmp/pr-body.md
```

Add `--label "no-changeset-needed"` when applicable (skip if label missing in repo).

4. **If PR exists:** refresh title/body from the template and current understanding of the diff:

```bash
gh pr edit <number> --title "<type>(<scope>): <subject>" --body-file /tmp/pr-body.md
```

Write the filled template to `/tmp/pr-body.md` (or another temp path), then pass `--body-file`.

## Optional one-liner body (small PRs)

You may use heredoc with `gh pr create` as long as the template structure (headers + checkboxes) is preserved.


## Comment writing rules

Write like a senior engineer leaving a quick review note, not like an AI assistant.

- **Lead with the point.** State the issue or ask directly. No "Great work!", "Good catch", "I noticed that…", "It seems like…", "Consider…" preambles.
- **Concrete, not abstract.** Name the exact symbol/line/behavior. "`user` can be null here → 401" beats "There might be a potential issue with null handling."
- **Show, don't describe.** If a fix fits in a line or two, give a `suggestion` block or inline code instead of prose explaining it.
- **One issue per comment.** Don't bundle unrelated points or pad with extra advice the reviewer didn't ask about.
- **Say why only when it's not obvious.** Skip rationale for trivial stuff. For real bugs, one short clause is enough ("…otherwise it throws on empty input").
- **No hedging, no filler.** Cut "I think", "maybe", "just", "simply", "in order to", "it's worth noting". No closing pleasantries ("Hope this helps!", "Let me know!").
- **Match length to weight.** Nit = one line. Real bug = 1–3 lines max. Never a paragraph for a small thing.
- Plain technical English. No emoji unless mirroring the reviewer's own.
