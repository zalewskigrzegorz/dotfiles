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

Put this into `~/.cursor/mcp.json` (or render from `dot_cursor/mcp.json.tmpl`):

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

## Claude Code (recommended: project-scoped, committed)

Create/update `.mcp.json` in repo root:

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
