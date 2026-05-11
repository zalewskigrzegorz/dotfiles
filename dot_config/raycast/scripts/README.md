# Raycast Script Commands

## Installation

1. Open Raycast.
2. Go to **Raycast Settings** → **Extensions** → **Script Commands**.
3. Click **Add Script Directory**.
4. Select `~/Code/Labs/shortcuts`.

The dotfiles compatibility hook copies rendered scripts from
`~/.config/raycast/scripts` into `~/Code/Labs/shortcuts` on every chezmoi apply,
and keeps Raycast configured to use that directory. It also refreshes legacy
copies in `~/raycast/script-commands` and
`~/raycast/script-commands/commands/dotfiles`.

Scripts that need the work project root are rendered by chezmoi templates from
the same 1Password-backed pieces used by the Nushell `WORK_PROJECT_DIR`
expression: `WORKSPACE_DIR`, `WORK_COMPANY`, and `WORK_MAIN_PROJECT`.

## Available Scripts

- `clearGithubNotification.sh` - mark GitHub notifications as read.
- `create-new-branch.sh` - update `main` and create a typed branch in the work project.
- `navi-cheatsheets-nu.nu` - search Navi cheatsheets from Raycast.
- `resolve-email-alias.sh` - map `maksim009+<tag>@gmail.com` to `<tag>@zinsoft.bulc.club` (argument or clipboard).
- `run-e2e-on-github.sh` - trigger GitHub E2E by toggling the `run_e2e` label.

## MCP on macOS (Raycast, no repo)

- Use only HTTPS in Raycast MCP URLs (Apple policy):
  - `https://mcp.lab/homey/mcp`
  - `https://mcp.lab/excalidraw/mcp`
- HTTP (`http://...`) can still be used for LAN/server-side tests, but not as a Raycast MCP URL on macOS.
- Server-side setup uses one wildcard certificate (`*.lab`) with SAN entries for `*.lab` and `mcp.lab`.
- On the Mac (same network), open `https://mcp.lab/cert/cert.pem` in Safari once, import to Keychain, set trust to **Always Trust**, then fully restart Raycast.
- DNS note: a separate `mcp.lab` record is not required when your wildcard (for example `*.lab`) already points to the same Traefik IP.
- Traefik serves one HTTPS host/certificate with two paths (`/homey/mcp`, `/excalidraw/mcp`) from `docker/config/traefik/mcp-gateway.yml`.

### TLS error quick fix (`Reason: A TLS error caused the secure connection to fail`)

1. Remove any old `mcp.lab` self-signed cert from Keychain (`login` and `System`).
2. Import fresh `https://mcp.lab/cert/cert.pem` to **System** keychain and set **Always Trust**.
3. Verify SAN/hostname on Mac:
   - `openssl s_client -connect mcp.lab:443 -servername mcp.lab </dev/null | openssl x509 -noout -subject -issuer -text | rg "Subject:|Issuer:|DNS:"`
   - Ensure SAN includes `DNS:*.lab` and `DNS:mcp.lab`.
4. Verify DNS resolution points to Traefik:
   - `dig +short mcp.lab`
5. Quit Raycast completely and launch again.
