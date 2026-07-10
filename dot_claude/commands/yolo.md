---
description: YOLO mode — bypass EVERY permission guard for the rest of this session (incl. absolute denies). Session-scoped, so other agents keep their guards. Restore with `claude-yolo off`.
allowed-tools: Bash(claude-yolo:*)
---

!`claude-yolo on`

🔥 **YOLO is ON for this session.** Every tool call now auto-approves — no popups, no asks, and even the absolute denies (force-push, `rm -rf`, `DROP TABLE`, `curl|sh`) are bypassed. Scoped to this session only; parallel herdr agents keep their guards.

Restore guards any time with `claude-yolo off` (or just end the session — the marker auto-expires).
