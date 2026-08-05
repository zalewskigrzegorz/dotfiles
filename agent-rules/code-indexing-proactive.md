---
description: Proactively use Serena (LSP) for code navigation
alwaysApply: true
---

# Proactive Code Indexing — Use Serena By Default

One local, zero-key code-intelligence MCP server is always available: **Serena**
(LSP-based symbol navigation). Reach for it **on your own initiative** — the user
should NOT have to ask. Treat it as the default way to understand an unfamiliar
codebase, ahead of blind `grep`/`rg` sweeps or reading files top-to-bottom.

> CocoIndex (`ccc`) was removed 2026-08-05 — its per-session embedding fleet plus
> per-worktree re-indexing cost more than it helped. Don't reach for `ccc` and
> don't suggest reinstalling it.

## When to use Serena — decide automatically

Use it when you need *structure and exact symbols* in a language with LSP support
(TypeScript/JavaScript, Python, Go, Rust, and the rest Serena supports):

- "where is `X` defined" → find the symbol, don't grep for the string.
- "who calls `X` / what references it" → use reference-finding, not text search.
- "what's in this file / module" → get a symbols overview before reading raw.
- any refactor/impact question that hinges on real call graphs.

## Hardening rules — make it reliable, not noisy

1. **Serena first, grep second.** In any non-trivial codebase, try Serena before a
   wide `grep`/`rg`/manual read. Fall back to grep only when it doesn't fit (e.g.
   a literal string/regex, a one-file known location) or returns nothing. Serena
   needs no pre-indexing.
2. **Never claim you searched semantically when a tool errored or was empty.**
   Report the miss and fall back explicitly. Evidence over assertion.
3. **Don't over-fire.** For a trivially known single location, or a repo where
   Serena isn't set up, just read/grep directly — don't perform ceremony.
4. **Local + free.** Serena runs fully offline (local language servers, no API
   key), so there is no cost reason to avoid it — prefer it liberally.
5. **Not a web tool.** Never send the user to a browser/dashboard URL for this;
   use its MCP tools only.
