---
name: rebilly-sync
description: >-
  Weekly workflow to update the "Redocly - Rebilly integration" Slack List from
  the latest Redocly <-> Rebilly sync meeting transcript. Pulls the transcript
  via the spark CLI, loads the current list state (CSV export from Downloads or
  the browser), then goes point by point with Greg: he decides, the agent edits
  the list through Claude-in-Chrome. Updates go to item COMMENTS (that's where
  the team logs status); descriptions are only rewritten when merging duplicates
  or simplifying walls of text. Use when Greg says "rebilly sync", "rebilly
  notes", "update the rebilly list", "przejdźmy po rebilly", invokes
  /rebilly-sync, or after a Redocly <-> Rebilly sync meeting.
---

# rebilly-sync

Weekly: turn the latest Rebilly sync transcript into clean updates on the shared Slack List.

**This list is shared with external Rebilly people.** Deleting items and posting comments are outward-facing — confirm with Greg before doing either. Greg drives point by point; he decides what changes, the agent makes the edit.

## Fixed references

- Slack List "Redocly - Rebilly integration": `https://app.slack.com/client/T70EJTC57/unified-files/list/F08R11Z5X9S`
- Meeting title in spark: **"Redocly <-> Rebilly sync"** (recurring; usually ~15-30 min)
- Current list export (most reliable full snapshot): newest `Redocly_-_Rebilly_integration*.csv` in `~/Downloads/`

## Flow

1. **Pull the transcript.** Use the `use-spark` skill.
   - `spark meetings --filter "newer_than:14d"` → find the newest "Redocly <-> Rebilly sync" meeting ID.
   - `spark meeting --transcript --notes <id>` → read summary + transcript. The summary's Key Points / Action Items are the fastest map; the transcript is the source of truth.

2. **Load current list state.** Prefer the CSV: `cat ~/Downloads/Redocly_-_Rebilly_integration*.csv` (pick the newest). It gives every item's Name, Status, full Description, Owner, GA Blocker — without burning browser round-trips. If there's no fresh export, ask Greg to re-export (list "..." menu → Download CSV), or read the list in the browser. The CSV does NOT include comments — read those in the browser when needed.

3. **Map transcript → items, then go point by point.** Present, per touched item, what the transcript adds. Greg decides each one. Do NOT batch-apply; he's in the loop. Typical decisions:
   - **Status update** → add a COMMENT (see below). Default action — this is where the team logs progress.
   - **Merge duplicates** → one survivor rewritten, the rest deleted (confirm deletes).
   - **Simplify a wall of text** → rewrite the description to essence.
   - **Nothing new / already in comments** → leave it. Always read existing comments first ("unless it's already there").

4. **Comments are where updates live.** When adding a status update, post it as a comment, not in the description. Prefix with `From <DD Mon> sync:` and keep it to the essence (root cause, owner, next step, blocker). English.

5. **Rewrites: always run them through the `humanizer` skill.** Rules Greg insists on:
   - **English only.**
   - **Essence only** — nobody reads walls of text in the meeting; walls add confusion. Cut the "NOT this task / different bug / not a duplicate" cross-reference scaffolding.
   - **Never change the meaning.** Preserve every concrete decision, number, code path, owner, and open question.
   - No em dashes (humanizer §14).

## Browser conventions (Claude-in-Chrome + Slack Lists)

Load the chrome tools in one ToolSearch call (see the claude-in-chrome guidance). Then:

- **Open a record:** hover the row → click the expand icon that appears after the name. (A plain click on the name enters inline title-edit — press Escape to back out.)
- **Open a comment thread:** hover the row → click the comment-bubble icon (shows the count), or use "Add Comment" / the comment count at the top of the open record panel.
- **Edit the title:** click the title (top of record panel or inline), `cmd+a`, type.
- **Edit the description:** open the record, click the Description field, `cmd+a` to select all.
  - **Enter COMMITS and closes the field** — it does NOT make a new line. Build multi-line text with **`shift+Enter`** between lines (`browser_batch` with `key shift+Enter`, `repeat: 2` for a blank line). Then click empty panel space to save.
  - `1)` / `2)` may auto-format the first line into a list item; cosmetic, leave it.
- **Post a comment:** open the thread, click the "Reply…" box, type (single paragraph, no newlines), press `Return` to send. **Verify the sent text** (zoom the posted message) — stray characters have appeared on send; if so, hover the message → "..." → Edit message → `cmd+a` → retype → Save.
- **Delete an item:** right-click the row → "Delete item" (red). A "Item deleted. Undo" toast confirms. Sometimes the first right-click only selects; right-click again.
- **Record-panel up/down nav arrows move one item per click** — don't batch many clicks expecting multi-step jumps; click once, verify, repeat. Scrolling the list + hover/expand is often more reliable.
- Use `browser_batch` to sequence predictable steps (click field → cmd+a → type → key shift+Enter → screenshot) in one round trip.

## After the session

When Greg confirms the notes are done, give a tight summary: merges, deletes, simplifications, and every comment posted (with which item). This is a recurring weekly task — keep the report skimmable.
