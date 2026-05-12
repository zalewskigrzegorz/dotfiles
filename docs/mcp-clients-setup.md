# MCP setup (Raycast, Cursor, Claude)

Endpoints:

- Excalidraw AI app: `http://draw-ai.lab`
- Raycast/HTTP MCP gateway:
  - `https://mcp.lab/excalidraw/mcp`
  - `https://mcp.lab/homey/mcp`
- Cert download: `https://mcp.lab/cert/cert.pem`
- Other apps pattern: `http://{service-name}.lab`

## What can be automated from dotfiles

- Raycast MCP servers: **no stable public config file** to manage safely in this repo; keep manual setup in Raycast UI.
- Cursor MCP: **yes** (`~/.cursor/mcp.json` for global, or `.cursor/mcp.json` per-project).
- Claude Code MCP: **yes** (recommended as project-scoped `.mcp.json` in repo; user/local scope is stored in `~/.claude.json`).

> **As of the agent-sync rework**, both Cursor and Claude Code now share a single source of truth at `agent-mcp/mcp-servers.json.tmpl`. `chezmoi apply` renders it into `~/.cursor/mcp.json` (via `dot_cursor/mcp.json.tmpl`) and calls `claude mcp add --scope user` for each server. See `docs/agents-sync.md` for the full layout.

## One-time macOS certificate step (required for Raycast HTTPS)

1. Open `https://mcp.lab/cert/cert.pem` in Safari.
2. Import to Keychain Access (`System` keychain recommended).
3. Set trust to `Always Trust`.
4. Restart Raycast.

## Raycast (manual)

In Raycast MCP settings add:

- `https://mcp.lab/homey/mcp`
- `https://mcp.lab/excalidraw/mcp`

## Cursor (global dotfile-managed)

`dot_cursor/mcp.json.tmpl` is a one-line include of the shared `agent-mcp/mcp-servers.json.tmpl`; `chezmoi apply` renders both Cursor and Claude from the same source. Edit `agent-mcp/mcp-servers.json.tmpl` instead of the rendered file. Example shared servers (current state):

```json
{
  "mcpServers": {
    "homey-http": {
      "type": "http",
      "url": "https://mcp.lab/homey/mcp"
    },
    "excalidraw-http": {
      "type": "http",
      "url": "https://mcp.lab/excalidraw/mcp"
    }
  }
}
```

Restart Cursor after changes.

## Claude Code (global user scope, dotfile-managed)

User-scope MCP servers are registered automatically by `run_onchange_after_32-agent-mcp-sync.sh` (driven off `agent-mcp/mcp-servers.json.tmpl`). It calls `claude mcp remove --scope user <name>` then `claude mcp add --scope user <name> -- <cmd> <args>` per server. Verify with `claude mcp list`.

### Project-scoped (per-repo, committed)

For a per-repo MCP entry that's not global, create/update `.mcp.json` in that repo's root:

```json
{
  "mcpServers": {
    "homey-http": {
      "type": "http",
      "url": "https://mcp.lab/homey/mcp"
    },
    "excalidraw-http": {
      "type": "http",
      "url": "https://mcp.lab/excalidraw/mcp"
    }
  }
}
```

Alternative (user scope via CLI, not committed):

```bash
claude mcp add --transport http --scope user homey-http https://mcp.lab/homey/mcp
claude mcp add --transport http --scope user excalidraw-http https://mcp.lab/excalidraw/mcp
```

## Notes

- Keep MCP auth secrets in environment variables, not committed JSON.
- For Raycast on macOS, always use `https://...` MCP URLs.
- For `mcp-server-nu` in Raycast (stdio), use `~/.config/nushell/config.nu` and `~/.config/nushell/env.nu` to avoid spaces in `Application Support`.
