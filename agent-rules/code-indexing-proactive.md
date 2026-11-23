---
description: Proactively use Serena (LSP) for code navigation
alwaysApply: true
---

# Proactive Code Indexing: Serena by default

**Serena** (local LSP MCP, no key, no pre-indexing) is the default for understanding code in an LSP language (TS/JS, Python, Go, Rust, …); use it unasked, before wide `rg` sweeps or top-to-bottom reads:

- "where is `X` defined" → find the symbol; "who calls `X`" → referencing symbols; "what's in this file" → symbols overview; refactor/impact → real call graphs.
- **Its tools are deferred**: load `ToolSearch select:mcp__serena__get_symbols_overview,mcp__serena__find_symbol,mcp__serena__find_referencing_symbols` first. A file >500 lines gets an overview before ranged `Read`s.
- Grep only for literal strings/regex, a known one-file location, or when Serena returns nothing. Never claim a semantic search when the tool errored or was empty: say so and fall back.
- No ceremony for a trivially known location or a repo without Serena. Swift via sourcekit-lsp is unverified: test once, then record it.
- MCP tools only, never a browser/dashboard URL. CocoIndex (`ccc`) was removed 2026-08-05: don't use or reinstall it.
