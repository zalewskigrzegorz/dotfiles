---
name: g-github-issue
description: Creates GitHub issues in the work monorepo with gh (template per type, team label, English body, confirmation before create), plus epics with sub-issues and board fields. Use for a bug report, maintenance, feature request, idea, docs, epic or onboarding issue ("create issue", "file a bug", "maintenance ticket").
---

# g-github-issue

`source ~/.local/state/dotfiles/secrets/work.env` → repo `$WORK_MAIN_REPO`,
default label `$WORK_TEAM_LABEL` (always added, plus any the user names).
Create with `gh issue create -R "$WORK_MAIN_REPO"` only, no MCP unless the user
insists. `gh` missing or logged out (`gh auth status`) → tell the user, no MCP
fallback. Titles and bodies in **English**.

## Types

| Type | When | Title prefix |
|---|---|---|
| Bug report | defect, repro, expected vs actual | — |
| Feature request | new capability | — |
| Idea | to validate | `[Idea] ` |
| Maintenance | tech debt, initiative | — |
| Epic | large multi-feature goal | `[Epic] ` |
| Docs change / New docs | docs | `docs: ` |
| Onboarding | checklist | `Onboarding checklist [full name]` |

Bug vs maintenance unclear → ask, never pick a default. Body sections:
[reference.md](reference.md) (or `.github/ISSUE_TEMPLATE/*.md`).

## Flow

1. Type, title (ask if missing), body per reference.md. Ask for missing
   sections; never guess repro steps, environment or issue numbers.
2. **Confirm**: show repo, title, labels, body; create only after a clear yes.
3. Create: `gh issue create -R "$WORK_MAIN_REPO" -t "<title>" --body-file
   <tmp>/issue-body.md -l "$WORK_TEAM_LABEL"` (`-b '…'` for a one-liner).
4. **Sub-issue** (the epic asks for it, or a parent is named): no parent flag,
   attach afterwards:
   ```bash
   parent=$(gh issue view <epic> -R "$WORK_MAIN_REPO" --json id --jq .id)
   child=$(gh issue view <new> -R "$WORK_MAIN_REPO" --json id --jq .id)
   gh api graphql -f query='mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){issue{number} subIssue{number}}}' -f p="$parent" -f c="$child"
   ```
   Older `gh` needs `-H "GraphQL-Features: sub_issues"`. The team label puts
   it on the board (`Pending`) by itself: check `gh issue view <n> --json
   projectItems`, don't add it twice.
5. **Board fields** (a status like "This Week", a type like "Maintenance"):
   board number from `work-context.md` (Board line), ids looked up by name:
   ```bash
   org=${WORK_MAIN_REPO%%/*}; proj=<board number>
   pid=$(gh project view "$proj" --owner "$org" --format json --jq .id)
   item=$(gh project item-add "$proj" --owner "$org" --url <issue url> --format json --jq .id)   # idempotent
   [ -n "$item" ] || { echo "no item"; exit 1; }
   gh project field-list "$proj" --owner "$org" --format json --jq '.fields[] | select(.name=="Status") | {id, options}'
   gh project item-edit --project-id "$pid" --id "$item" --field-id <field id> --single-select-option-id <option id>
   ```

## Epic / cycle tracker

1. **Body = the previous epic's body, headings verbatim** (`gh issue view
   <last-epic> --json body`): a GitHub Action parses them 1:1; only content
   changes.
2. Sub-issues via the flow, labels `$WORK_TEAM_LABEL` + a `size:*`, then step 4.
3. **No `--assignee` unless Greg names a person**; a "Kto" column is a plan.
4. End with the epic number and the sub-issue numbers on one line.
5. Before proposing a new sub-issue, `gh issue view <n> --comments` on every
   neighbouring sub-issue and look for "scope note" / "moves to". An owner
   exists → propose that issue instead.
