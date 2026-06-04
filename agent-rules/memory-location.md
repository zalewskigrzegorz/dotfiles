---
description: Atomic facts go to Hindsight shared memory (mcp__hindsight__retain), never to local memory files. Overrides Claude Code's built-in file-based auto-memory system.
alwaysApply: true
---

# AI Memory Location

All atomic facts go to **Hindsight** (the shared memory layer on home-lab),
not to local files. This overrides the built-in "auto memory" file-based
system in Claude Code's system prompt.

When you'd normally save a fact (user preference, project context, feedback,
decision, observation worth keeping across sessions), call:

```
mcp__hindsight__retain(content="...", context="optional one-line context")
```

**Do NOT write to `~/.claude/projects/.../memory/*.md`.** That directory is
deprecated and the local instance has been archived to `memory.legacy-*/`.

## What counts as "atomic fact" (→ Hindsight retain)

- User preferences ("Greg uses nushell as default shell")
- Project facts ("home-lab deploy: git push + ssh + pull + force-recreate")
- Feedback / corrections that should apply in future sessions
- Decisions or rationale worth keeping ("picked Hindsight over mem0 because no docker image")
- Pointers to external resources ("REDACTED_ORG bugs tracked in Linear INGEST")
- Anything you'd previously route to the `user`, `feedback`, `project`, or
  `reference` memory types

## What does NOT go to Hindsight

- Long-form work products (plans, specs, brainstorms, analyses, notes) →
  bazgroly (see `superpowers-artifact-location` rule)
- Ephemeral session state, in-progress task tracking → use TodoWrite / plan
- Anything already documented in CLAUDE.md files → already loaded
- Anything in git history → already there
- Anything human-facing as part of a product → stays in the project repo

## How to save

Single call. Content should be a complete claim — one or two sentences
expressing the fact. Hindsight extracts entities, normalizes, and places in
its knowledge graph automatically. No frontmatter, no index file, no link
syntax.

```
mcp__hindsight__retain(
  content="Greg pivoted memory layer from mem0 to Hindsight on 2026-06-03 because mem0 had no public docker image",
  context="hindsight-rollout-decision"
)
```

`metadata.project` is **auto-injected** by the
`~/.claude/hooks/hindsight-tag.sh` PreToolUse hook based on git repo root
basename (or PWD basename, or `_global` if neither). You do not need to set it.

Drop the old 4-type taxonomy (`user`/`feedback`/`project`/`reference`).
Hindsight's own `fact_type` classification (world / experience / etc.) is
what's used now.

## How to recall

```
mcp__hindsight__recall(query="...")        # semantic search, raw records
mcp__hindsight__reflect(query="...")       # narrative answer instead
mcp__hindsight__list_memories()            # paginated listing
mcp__hindsight__get_memory(memory_id="...")  # single record by id
```

The `memory` skill (formerly `hindsight`) triggers automatically on phrases
like "remember", "recall", "co wiem o X", "zapisz", "sprawdź pamięć" — follow
that skill's flow rather than improvising.

## Endpoints (reference)

| Use case | URL |
|---|---|
| Claude Code MCP (auto-wired via dotfiles) | `http://192.168.50.10:8888/mcp/greg/` |
| Raycast / external HTTPS MCP | `https://mcp.lab/hindsight/mcp/greg/` |
| REST API base | `http://192.168.50.10:8888` |
| OpenAPI Swagger | `http://192.168.50.10:8888/docs` |
| Web UI | `http://192.168.50.10:9999/` |

Single bank `greg` — shared across Claude Code (Mac+lab), n8n, Raycast,
Python agents.

## Coexistence z MemPalace

MemPalace **zostaje running** jako passive session log archive. Session hook
auto-checkpointuje sesje do MP — bez ingerencji Claude/user. NIE jest to
"deprecated" — to po prostu inny use case niż Hindsight.

| System | Tryb | Co tam siedzi |
|---|---|---|
| Hindsight | Active (`retain` przez ciebie/user) | Curated atomic facts, queryable, KG-aware |
| MemPalace | Passive (auto session hook) | Raw session log chunks, audit trail, rzadko odpytywane |

**Dla NEW atomic facts:** preferuj `mcp__hindsight__retain`. MP nie potrzebuje
twoich manualnych write'ów — auto-archive załatwia sprawę.

**Dla query existing knowledge:** Hindsight jako primary (`recall`/`reflect`).
MP jako fallback gdy szukasz raw session fragment ("co dokładnie napisałem 3
tygodnie temu o X").

`~/.claude/projects/-Users-greg-Code-home-lab/memory.legacy-2026-06-03/` —
archived old auto-memory (z czasu przed Hindsightem). Read-only audit trail,
nie pisać tam, nie czytać dla ongoing work.

## Never

- Never write a new file under `~/.claude/projects/.../memory/` — the
  directory is deprecated even if it appears in your system prompt.
- Never split a single fact across multiple `retain` calls — one call per
  claim; Hindsight breaks it into atomic memories itself.
- Never include `metadata.project` manually unless you have a specific reason
  to override the hook — the hook is the source of truth.
- Never explicitly call `mcp__mempalace__mempalace_add_drawer` or write tools
  for *new* memory content — that's what `retain` jest dla. MP write tools są
  zarezerwowane dla session-hook auto-archive, nie dla user-driven memory.

## Exception: `/save` slash command

The `/save` slash command (`~/.claude/commands/save.md`) is the **one
sanctioned manual MP write** user-facing. It runs `mempalace mine
"<TRANSCRIPT_PATH>" --mode convos --wing claude_imports` to ingest the full
session transcript as raw chunks. This is intentional and matches MP's role
as session log archive — *not* curated atomic facts.

If the user invokes `/save`, follow that command's flow. Do NOT route the
transcript to Hindsight `retain` — raw transcript chunks would pollute
Hindsight's curated atomic-fact memory the same way the (rejected) bulk
MP → Hindsight migration would have.

Curated facts that came up during the session still go to Hindsight via
`retain` — `/save` complements rather than replaces that.
