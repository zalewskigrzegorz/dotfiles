---
description: Save the current Claude Code session into MemPalace. Idempotent — won't dupe.
---

# /save — archive this session into MemPalace

The one sanctioned manual MemPalace write (`memory-location.md`).

1. Transcript: `~/.claude/projects/<slugified-cwd>/<session-id>.jsonl`.
2. `mempalace mine "<TRANSCRIPT_PATH>" --mode convos --wing claude_imports`
3. Report what was ingested (drawers / wing), nothing more.

- MemPalace dedupes on re-ingest; if it reports duplicates, say so, don't retry with other flags.
- Never send the transcript to Hindsight `retain` (raw chunks pollute curated facts). Curated facts from the session still go to `retain`; `/save` complements that.
