---
description: Atomic facts go to Hindsight shared memory (mcp__hindsight__retain), never to local memory files. Overrides Claude Code's built-in file-based auto-memory system.
alwaysApply: true
---

# AI Memory Location

Atomic facts go to **Hindsight** (shared memory on home-lab). This overrides Claude Code's built-in auto memory: **never write under `~/.claude/projects/.../memory/`** (deprecated; the old copy in `memory.legacy-*/` is a read-only audit trail).

- **Save**: `mcp__hindsight__retain(content="…", context="<topic>")`, one call per claim in one or two complete sentences; Hindsight splits and classifies it. `metadata.project` is injected by a hook, don't set it. In scope: preferences, project facts, corrections, decisions with rationale, pointers to external resources. Out: plans/specs/analyses (→ bazgroly), in-progress state (→ TodoWrite / plan), anything in a CLAUDE.md or git history, product docs.
- **Recall**: `recall(query, max_tokens=512)` for raw records (guard denies it without `max_tokens`; `budget` is not the lever), `reflect(query)` for a narrative answer. The `memory` skill triggers on "remember", "recall", "co wiem o X", "zapisz", "sprawdź pamięć".

## MemPalace: what happened, next to Hindsight's what is true

MemPalace is a passive session archive (a hook checkpoints every session); both are active, neither is the other's fallback. Never write to it by hand (`mempalace_add_drawer` …); the one manual write is `/save`, which mines the transcript into MP only.

**Search MP instead of saying you have no context** when Greg refers to earlier work ("wróćmy do", "co ustaliliśmy", "kontynuuj", "jak to wtedy zrobiliśmy", bare "resume"/"continue"/"wracamy"), when you enter a repo with fresh history and `recall` gave facts without the story, or when he says he already got something ("podawałeś mi", "mówiłeś że", "gdzie to zapisałeś"). First `mempalace_search` (guard caps `limit` at 3) and `recall`; open a `.jsonl` transcript only for a session the content points to, never by mtime; never `rg` over all session transcripts (guard denies it).

**A rare literal token (name, file, command) → `bin/mp-search`**: MCP and CLI rank by vector only ("dagr" returned DataGrip with `bm25_score: 0.0`), `mp-search` adds BM25 candidates. CLI fallback when the MCP is down: `mempalace search "<query>"`.
