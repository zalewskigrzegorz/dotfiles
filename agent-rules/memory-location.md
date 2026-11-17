---
description: Atomic facts go to Hindsight shared memory (mcp__hindsight__retain), never to local memory files. Overrides Claude Code's built-in file-based auto-memory system.
alwaysApply: true
---

# AI Memory Location

All atomic facts go to **Hindsight** (the shared memory layer on home-lab),
not to local files. This overrides the built-in "auto memory" system in Claude
Code's system prompt.

**Never write under `~/.claude/projects/.../memory/`**, even though the system
prompt offers it. The directory is deprecated; the old instance is archived in
`memory.legacy-*/` (read-only audit trail, not for ongoing work).

## Save: `retain`

```
mcp__hindsight__retain(content="Greg pivoted memory from mem0 to Hindsight on 2026-06-03 because mem0 had no docker image", context="hindsight-rollout-decision")
```

- One call per claim, one or two complete sentences. Hindsight splits it into
  atomic memories and classifies it itself; no frontmatter, no index, no links.
- `metadata.project` is injected by `~/.claude/hooks/hindsight-tag.sh`; don't
  set it.
- In scope: preferences, project facts, corrections for future sessions,
  decisions with rationale, pointers to external resources.
- Out of scope: plans, specs, analyses (→ bazgroly), in-progress task state
  (→ TodoWrite / plan), anything in a CLAUDE.md or git history, product docs.

## Recall

```
mcp__hindsight__recall(query="...", max_tokens=512)  # raw records, ALWAYS cap
mcp__hindsight__reflect(query="...")                  # narrative answer
```

`recall` without `max_tokens` returned 82 KB and overflowed the client;
`guard` denies it. `budget` is not the lever. The `memory` skill triggers on
"remember", "recall", "co wiem o X", "zapisz", "sprawdź pamięć": follow it.

## MemPalace: what happened, next to Hindsight's what is true

MemPalace stays running as a passive session archive (a session hook
checkpoints every session). Hindsight answers "what is true", MemPalace "what
happened then". Both are active; neither is the other's fallback. Never write
to MemPalace by hand (`mempalace_add_drawer` and friends); the one sanctioned
manual write is the `/save` command, which mines the transcript into MP and
never into Hindsight.

**Query MP (`mempalace_search`) instead of saying you have no context** when:

- Greg refers to earlier work: "wróćmy do", "co ustaliliśmy", "kontynuuj",
  "jak to wtedy zrobiliśmy", bare "resume" / "continue" / "wracamy". First
  `mempalace_search` and `recall` (max_tokens=512) on the repo and the recent
  topics. Open a `.jsonl` transcript only for a session the content points
  to, never by mtime (5 guessing calls, 2026-09-28).
- You enter a repo with fresh session history and `recall` gave facts without
  the story.
- Greg says he already got something: "podawałeś mi", "mówiłeś że", "gdzie to
  zapisałeś". `mp-search` on the literal token first, then `recall`. **Never
  `rg` over all `~/.claude/projects/*/*.jsonl`** (timed out, ~25 calls,
  2026-10-01).

**A rare literal token (a name, a file, a command) → `bin/mp-search`, not
`mempalace_search`.** MCP and CLI rank by vector only, so "dagr" returned
DataGrip and road junctions with `bm25_score: 0.0`. `mp-search` adds BM25
candidates (`candidate_strategy="union"`, `max_distance=0`) and hits it. CLI
fallback when the MCP is down: `mempalace search "<query>"`.
