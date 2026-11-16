---
paths:
  - "bin/screens-sweep"
  - "run_onchange_after_50-screens-sweep-launchd.sh.tmpl"
---

# screens-sweep: a job that deletes

- **A new or changed deleting job starts with a dry run** that prints the file count per class (image, video, gif, other) and 5 examples of each. Deleting is switched on only after that output. Every class without a model verdict has an explicit "keep" or "trash". The first full run trashed 3 `.mp4` and 1 `.gif` from 2024 because only images got a verdict (the Drive bin keeps them 30 days).
- **"You don't have permission" on delete after a series (141 files)** → first the Google Drive menu bar icon and its delete confirmation message, only then the code. Cause not verified.
- **Open on 2026-11-16:** Greg has not checked Drive yet, and the daily 13:00 launchd run will hit the same wall. `tiktok-to-album` v2 is unconfirmed. Remove this point once he confirms.
