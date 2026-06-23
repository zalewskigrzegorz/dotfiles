---
name: hunk-comment-review
description: Addresses the user's inline review comments left in a live hunk diff session. The user reviews a changeset in hunk (modem-dev/hunk TUI) and drops comments on lines that caught their attention; this skill reads those human-authored comments and resolves each one — either by editing the code or by replying inline in hunk. Use when the user says "ogarnij uwagi z hunka", "odpowiedz na komentarze w hunku", "address my hunk comments", or as the pre-commit gate invoked by g-commit. No comments / no live session = nothing to do, return cleanly.
---

# hunk-comment-review

## What this is

A feedback loop on top of **hunk** (review-first TUI diff viewer, already wired in
this dotfiles setup: `git review` / the `work` tmux layout open `hunk diff --watch`).

The direction is **user → agent**:

1. The user reviews the working-tree / staged diff in hunk and leaves **their own**
   inline comments on spots worth attention.
2. This skill reads those comments and resolves each: **edit the code** to address
   the concern, **or reply inline** in hunk when no change is warranted.
3. The user sees responses right next to their notes (`--watch` reloads live), then
   commits.

Not mandatory. **No user comments — or no live hunk session — means commit flows
normally; this skill returns without doing anything.**

## Hard rules

- The TUI is the **user's**. NEVER run `hunk diff`, `hunk show`, or other interactive
  commands — they hijack the user's screen. Drive everything through `hunk session *`.
- For the full, authoritative `hunk session` command reference, run `hunk skill path`
  and read that bundled `SKILL.md` (it ships with the installed hunk version, so it
  can't drift). This skill is the *workflow*; that file is the *command spec*.

## Flow

1. **Find the session** for the current repo:
   ```bash
   hunk session list --json
   ```
   - No session → say so in one line ("brak żywej sesji hunka — nie ma czego adresować")
     and stop. This is a normal, silent-ish exit, not an error.
   - `"No active Hunk sessions"` while hunk is visibly running → localhost may be
     blocked by the agent sandbox; retry with network/sandbox escalation before
     concluding there's no session.

2. **Pull the user's comments** (human-authored notes only):
   ```bash
   hunk session comment list --repo . --type user --json
   ```
   - Empty → "brak uwag w hunku" and stop. (g-commit: proceed to commit.)

3. **Resolve each comment.** Read each note's `filePath`, line, and text, look at the
   actual code, and for every comment decide one of:
   - **Edit the code** — make the change the comment asks for (or that its concern
     implies). The live `--watch` view reloads so the user sees the new diff.
   - **Reply inline** — when you're pushing back, explaining a tradeoff, or the note
     is a question. Attach the reply at the **same line** as the user's comment so it
     sits adjacent:
     ```bash
     hunk session comment add --repo . --file <path> --new-line <n> \
       --summary "<short answer>" --rationale "<why, if needed>" --author agent
     ```
     For several replies at once, prefer one batch (validates before mutating):
     ```bash
     printf '%s' '{"comments":[{"filePath":"…","newLine":88,"summary":"…","rationale":"…"}]}' \
       | hunk session comment apply --repo . --stdin
     ```
   - One comment may warrant **both**: change the code *and* leave a one-line note
     saying what you did.

4. **Do NOT delete the user's comments.** Leave their notes in place; only add agent
   replies and code edits. The user clears their own comments when satisfied
   (`hunk session comment clear --repo . --yes` is theirs to run, not yours).

5. **Summarize in chat** — 2–3 lines, one per comment, e.g.:
   ```
   3 uwagi:
     pool.go:88   → poprawione (atomic → mutex, 2 pola naraz)
     README:103   → poprawione (wording)
     app.tsx:42   → zostawione + odpowiedź inline (useMemo niepotrzebny tu)
   ```

## Decide: fix vs reply

- The comment names a concrete defect, asks for a rename/refactor, or points at a bug
  → **fix the code**.
- The comment is a question, a "why did you…", or you disagree with the suggested
  change → **reply inline** with the reasoning. Don't silently change code you believe
  is correct just to clear a note; push back with a comment instead.
- When unsure whether the user wants the change applied, **reply asking**, don't guess.

## Notes

- `--new-line` vs `--old-line`: match whichever side the user's comment is anchored to
  (the `--json` listing tells you). Replies usually go on `--new-line` (the post-change
  side), since that's the code you're explaining.
- Keep replies short — intent, tradeoff, or follow-up. Mirror the user's language
  (Polish/English) in the reply text.
