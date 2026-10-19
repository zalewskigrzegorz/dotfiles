# MCP setup (Raycast, Claude)

Endpoints:

- Excalidraw AI app: `https://draw-ai.mrglaszki.com`
- Raycast/HTTP MCP gateway:
  - `https://mcp.mrglaszki.com/excalidraw/mcp`
  - `https://mcp.mrglaszki.com/homey/mcp`
- Cert download: `https://mcp.mrglaszki.com/cert/cert.pem`
- Other apps pattern: `https://{service-name}.mrglaszki.com`

## What can be automated from dotfiles

- Raycast MCP servers: **no stable public config file** to manage safely in this repo; keep manual setup in Raycast UI.
- Claude Code MCP: **yes** (recommended as project-scoped `.mcp.json` in repo; user/local scope is stored in `~/.claude.json`).

> **As of the agent-sync rework**, the single source of truth is `agent-mcp/mcp-servers.json.tmpl`. `chezmoi apply` calls `claude mcp add --scope user` for each server. See `docs/agents-sync.md` for the full layout.

## Certificate (no install needed — Let's Encrypt trusted)

## Raycast (manual)

In Raycast MCP settings add:

- `https://mcp.mrglaszki.com/homey/mcp`
- `https://mcp.mrglaszki.com/excalidraw/mcp`

## Claude Code (global user scope, dotfile-managed)

User-scope MCP servers are registered automatically by `run_onchange_after_32-agent-mcp-sync.sh` (driven off `agent-mcp/mcp-servers.json.tmpl`). It calls `claude mcp remove --scope user <name>` then `claude mcp add --scope user <name> -- <cmd> <args>` per server. Verify with `claude mcp list`.

### Project-scoped (per-repo, committed)

For a per-repo MCP entry that's not global, create/update `.mcp.json` in that repo's root:

```json
{
  "mcpServers": {
    "homey-http": {
      "type": "http",
      "url": "https://mcp.mrglaszki.com/homey/mcp"
    },
    "excalidraw-http": {
      "type": "http",
      "url": "https://mcp.mrglaszki.com/excalidraw/mcp"
    }
  }
}
```

Alternative (user scope via CLI, not committed):

```bash
claude mcp add --transport http --scope user homey-http https://mcp.mrglaszki.com/homey/mcp
claude mcp add --transport http --scope user excalidraw-http https://mcp.mrglaszki.com/excalidraw/mcp
```

## Notes

- Keep MCP auth secrets in environment variables, not committed JSON.
- For Raycast on macOS, always use `https://...` MCP URLs.
- For `mcp-server-nu` in Raycast (stdio), use `~/.config/nushell/config.nu` and `~/.config/nushell/env.nu` to avoid spaces in `Application Support`.
