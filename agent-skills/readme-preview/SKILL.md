---
name: readme-preview
description: Show Greg a README (or any Markdown) rendered the way GitHub renders it, HEAD and working tree side by side, in his browser before anything is committed or deployed. Use after editing a README.md, profile README or docs Markdown, or on "pokaż README", "pokaż najpierw", "jak to wygląda na GitHubie", "podgląd README", "preview the readme". Comes before the commit popup, never after.
---

# README preview

Why: rule `adhd-actions-not-walls.md` ("no approve on something he has not read", 41e2faa7). Your own screenshot is your check, not his.

1. Render into the scratchpad, never the repo:
   `bash ~/.claude/skills/readme-preview/scripts/render.sh <file.md> <scratchpad>/readme-preview`
   (`gh api markdown` with repo context on `git show HEAD:<file>` and the working tree → one two-column `index.html`; "new file" on the left when absent from HEAD; relative images from the working tree).
2. Serve in the background (`run_in_background`): `python3 -I -u -m http.server 0 --bind 127.0.0.1 --directory <scratchpad>/readme-preview`; read the port from `Serving HTTP on 127.0.0.1 port N`; `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:N/` must be `200`.
3. `browsentic` `page_openTab` on it, `page_scrollTo` the changed section (down → `open-here http://127.0.0.1:N/`).
4. One line: what changed and where, then "napisz kk, dam popup z commitem". End the turn.
5. Next edit: re-run step 1, he reloads. Done: `TaskStop` the server, `page_closeTab`.

- Not `grip` or another local renderer: they differ on alerts (`> [!NOTE]`), task lists, anchors.
- `gh api markdown` is rate-limited: once per edit, never in a loop.
- No GitHub remote → plain `markdown` mode (no issue links); say so in the one line.
