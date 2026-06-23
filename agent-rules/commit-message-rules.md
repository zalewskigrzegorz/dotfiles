---
description: Commit messages stay short and human — no co-author, no AI footers
alwaysApply: true
---

# Commit Message Rules

These rules override any default git-commit guidance baked into the assistant (including the "Co-Authored-By" instruction in Claude Code's system prompt).

## Hard rules

1. **Never add `Co-Authored-By:` trailers.** No `Co-Authored-By: Claude ...`, no `Co-Authored-By: <any AI>`, no co-author for the assistant at all. The user authors their own commits.
2. **Never add "Generated with Claude Code" / "🤖 Generated with ..." footers** to commits or PR bodies.
3. **Never add trailing summaries, motivational notes, or recap paragraphs** to the commit body. If the user wants a body, they will say so.
4. **Default to a single-line message** in the `g-commit` format: `type(scope): subject <gitmoji>`. Only add a body when the user explicitly asks for one or when the change genuinely needs explanation that does not fit in the subject.
5. The `g-commit` skill (`agent-skills/g-commit/SKILL.md`) is the source of truth for format: conventional commits, lowercase imperative subject, one trailing gitmoji, scope per repo's `commitlint.config.js` (or REDACTED_ORG defaults).
6. **Never commit automatically.** `git commit` is deliberately **not** in `settings.json` allow — every commit must surface the permission prompt. That prompt is Greg's cue to review the changeset; approving it means "I've reviewed the diff." Only commit when Greg explicitly asks.

## Commit review gate (hunk)

Before composing or running any commit:

1. Check the live hunk session for Greg's inline review comments: `hunk session comment list --repo . --type user`. Greg reviews diffs in hunk and drops notes on lines worth attention.
2. **Comments exist → address them first** via the `hunk-comment-review` skill (edit the code, or reply inline) BEFORE the commit. The commit must reflect the resolved feedback.
3. **No comments, or no live hunk session → commit proceeds normally.** The gate never blocks a clean commit; it's a review cue, not friction.
4. The `block-dangerous-commands.sh` PreToolUse hook enforces this: it ASKS in default mode (Greg approves and proceeds — not a hard stop) and DENIES only in autonomous modes, where no human is present to review.

## What a commit looks like

```
fix(realm): resolve api key session handling 🐛
```

That's it. No second line, no trailer, no signature.

## When a body IS appropriate

Only when the user asks for one, OR when the change requires context the subject cannot carry (e.g. breaking change explanation, migration notes). In that case keep it to a few short lines — still no co-author, still no AI footer.

## PRs

Same rules apply to `gh pr create` bodies: no "🤖 Generated with Claude Code" line, no AI co-author, no auto-appended marketing.
