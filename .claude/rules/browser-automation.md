---
paths:
  - "agent-skills/agent-browser/**"
  - "agent-skills/browsentic/**"
  - "private_dot_browsentic/**"
  - "run_onchange_after_12-npm-globals.sh.tmpl"
  - "docs/browser-automation.md"
---

# Browser automation sources (Mac)

When to use which: `agent-rules/browser-stacks.md`.

- `agent-browser` → `agent-skills/agent-browser/`
- `browsentic` → stage 12 npm globals + `agent-mcp/mcp-servers.json.tmpl` + `agent-skills/browsentic/` + `private_dot_browsentic/` (config, profile)
- `vimma` MCP → `agent-mcp/mcp-servers.json.tmpl`
- Retired `claude-in-chrome`: `docs/browser-automation.md`.
