# mcp-digest

Big results from read-only connectors eat the context. This mod passes them through Haiku first.

- Applies to read tools (search, get, list, read, fetch…) of Slack, Sentry, Google Drive, Docs and Gmail, when the result is over ~2,000 tokens.
- Claude gets Haiku's notes, which keep names, ids, numbers, dates, links and errors, plus the path to the full result in `~/.claude/mcp-digest/` if it needs more. Files older than 2 days are deleted.
- Writes and sends are never touched.
- `/mcp-digest off` turns it off, `/mcp-digest on` back on, `/mcp-digest` shows the state.
