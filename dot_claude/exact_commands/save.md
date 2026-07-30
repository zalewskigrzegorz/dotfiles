---
description: Save the current Claude Code session into MemPalace. Idempotent — won't dupe.
---

# /save — archive this session into MemPalace

Ingest the full session transcript into MemPalace as raw session-log chunks.
This is the **one sanctioned manual MemPalace write** (see the AI Memory
Location rule in `~/.claude/CLAUDE.md`) — everything else goes to Hindsight.

## Flow

1. Resolve the current session's transcript path. Claude Code stores it under
   `~/.claude/projects/<slugified-cwd>/<session-id>.jsonl`.
2. Run:

   ```bash
   mempalace mine "<TRANSCRIPT_PATH>" --mode convos --wing claude_imports
   ```

3. Report what was ingested (drawer count / wing), nothing more.

## Rules

- **Idempotent.** MemPalace dedupes on re-ingest, so re-running `/save` on the
  same transcript must not create duplicates. If it reports duplicates, say so
  rather than retrying with different flags.
- **Do not route the transcript to Hindsight `retain`.** Raw transcript chunks
  would pollute Hindsight's curated atomic-fact memory the same way the rejected
  bulk MP → Hindsight migration would have.
- Curated facts that came up during the session still go to Hindsight via
  `retain` — `/save` complements that, it does not replace it.
