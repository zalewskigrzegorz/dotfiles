---
description: Proactively use Serena (LSP) + CocoIndex (semantic search) for code navigation
alwaysApply: true
---

# Proactive Code Indexing — Use Serena & CocoIndex By Default

Two local, zero-key code-intelligence MCP servers are always available: **Serena**
(LSP-based symbol navigation) and **CocoIndex** (`ccc`, local AST semantic search).
Reach for them **on your own initiative** — the user should NOT have to ask.
Treat them as the default way to understand an unfamiliar codebase, ahead of
blind `grep`/`rg` sweeps or reading files top-to-bottom.

## When to use which — decide automatically

**Serena** — when you need *structure and exact symbols* in a language with LSP
support (TypeScript/JavaScript, Python, Go, Rust, and the rest Serena supports):

- "where is `X` defined" → find the symbol, don't grep for the string.
- "who calls `X` / what references it" → use reference-finding, not text search.
- "what's in this file / module" → get a symbols overview before reading raw.
- any refactor/impact question that hinges on real call graphs.

**CocoIndex** (`ccc search "<intent>"` or its MCP `search` tool) — when the
question is *conceptual* and you don't know the exact symbol name, or the repo is
mixed / weakly-LSP (shell, nushell, yaml, markdown, config):

- "where is functionality X handled", "how does Y work here", "what sets Z".
- first-pass orientation in a large repo you don't know yet.
- finding scattered, cross-file concerns that a single grep pattern would miss.

Serena and CocoIndex are complementary — it's normal to use CocoIndex to locate
the area, then Serena to nail the exact symbol and its callers.

## Hardening rules — make it reliable, not noisy

1. **Default first, grep second.** In any non-trivial codebase, try Serena/CocoIndex
   before a wide `grep`/`rg`/manual read. Fall back to grep only when they don't
   fit (e.g. a literal string/regex, a one-file known location) or return nothing.
2. **CocoIndex needs an index.** If a repo has no `.cocoindex_code/` yet, its
   search will be empty — say so and offer to run `ccc index <repo>` rather than
   silently giving up or pretending you searched. **Never run `ccc index`
   without the user's OK** (indexing is opt-in). Serena needs no pre-indexing.
3. **Never claim you searched semantically when a tool errored or was empty.**
   Report the miss and fall back explicitly. Evidence over assertion.
4. **Don't over-fire.** For a trivially known single location, or a repo where
   neither tool is set up, just read/grep directly — don't perform ceremony.
5. **Local + free.** These run fully offline (local embeddings, no API key), so
   there is no cost reason to avoid them — prefer them liberally.
6. **Not a web tool.** Never send the user to a browser/dashboard URL for these;
   they are used via their MCP tools or the `ccc` CLI only.
