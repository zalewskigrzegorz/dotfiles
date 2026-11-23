---
paths:
  - "dot_claude/hooks/**"
  - "agent-mods/guard/**"
---

# Testing a `pre-tool-use/*` hook

Feed it fixture JSON on stdin with guards on (no YOLO marker, `permission_mode: default`) and read `hookSpecificOutput.permissionDecision`. Run a table of `command → expect allow|ask|deny` cases against the working copy **and** against `git show HEAD:<hook>` in a scratch dir: that separates a regression from old behaviour in one pass and catches inconsistencies (commit asked while push passed, 2026-09-25). Read only the cases whose result changed.
