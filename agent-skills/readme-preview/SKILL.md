---
name: readme-preview
description: Show Greg a README (or any Markdown file) rendered the way GitHub renders it, HEAD and working tree side by side, in his browser before anything is committed or deployed. Use after editing a README.md, a profile README, docs Markdown, or when he says "pokaż README", "pokaż najpierw", "jak to wygląda na GitHubie", "podgląd README", "preview the readme". Comes before the commit popup, never after it.
---

# README preview

Greg asked "pokaż najpierw" three times in one session (41e2faa7) because a
README change went to a commit popup before he had seen it rendered. A preview
he has not looked at is not "shown": your own `agent-browser` screenshot is
your check, not his.

## Steps

1. Render, into the session scratchpad (never into the repo):

   ```bash
   bash ~/.claude/skills/readme-preview/scripts/render.sh <file.md> <scratchpad>/readme-preview
   ```

   It calls `gh api markdown` (GFM with the repo as context, so `#123` and
   `@user` links resolve) on `git show HEAD:<file>` and on the working tree,
   and writes one `index.html` with both columns. A file not in HEAD shows
   "new file" on the left. Relative images load from the working tree.

2. Serve it on a free port in the background (`run_in_background`), unbuffered
   so the port shows up in the log:

   ```bash
   python3 -I -u -m http.server 0 --bind 127.0.0.1 --directory <scratchpad>/readme-preview
   ```

   Read the port from the task output (`Serving HTTP on 127.0.0.1 port N`),
   then `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:N/` must be
   `200`.

3. Open it where Greg looks: `browsentic` `page_openTab` on
   `http://127.0.0.1:N/`, scrolled to the changed section (`page_scrollTo`).
   Browsentic down → `open-here http://127.0.0.1:N/`.

4. One line: what changed and where on the page, then "napisz kk, dam popup z
   commitem". End the turn. No popup in the same turn.

5. After his answer or the next edit: re-run step 1 (the server serves the new
   file, a browser reload shows it). When done, `TaskStop` the server and
   `page_closeTab` the tab.

## Notes

- Not `grip` or a local Markdown renderer: they differ from GitHub on alerts
  (`> [!NOTE]`), task lists and heading anchors. `gh api markdown` is GitHub's
  own renderer.
- `gh api markdown` is rate-limited like any API call; render once per edit,
  not in a loop.
- A repo without a GitHub remote renders in plain `markdown` mode (no issue
  links); say so in the one line.
