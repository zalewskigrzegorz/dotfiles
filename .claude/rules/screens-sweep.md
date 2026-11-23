---
paths:
  - "bin/screens-sweep"
  - "run_onchange_after_50-screens-sweep-launchd.sh.tmpl"
---

# screens-sweep: a job that deletes

Stage 50's `com.greg.screens-sweep` runs `bin/screens-sweep` daily at 13:00: deletes Drive `Screenshots` older than 30 days that Apple's on-device `fm` judges junk (the Drive bin keeps them 30 days). State and log: `~/.local/state/screens-sweep/`.

- **A new or changed deleting job starts with a dry run** printing the file count per class (image, video, gif, other) and 5 examples each; deletion is switched on only after that output. Every class without a model verdict gets an explicit "keep" or "trash" (the first run trashed 3 `.mp4` and 1 `.gif` because only images got a verdict).
- **"You don't have permission" on delete after a series (141 files)** → first the Google Drive menu bar icon and its delete confirmation, only then the code. Cause not verified.
- **Open on 2026-11-16:** Greg hasn't checked Drive yet and the 13:00 run will hit the same wall; `tiktok-to-album` v2 unconfirmed. Remove this point once he confirms.
