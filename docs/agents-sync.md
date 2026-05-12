# Agent config sync (Claude Code + Cursor)

This repo is the single source of truth for both AI agents. Everything in `agent-skills/`, `agent-rules/`, and `agent-mcp/` ships to **both** Claude Code and Cursor; `chezmoi apply` performs the sync.

## Layout

```
dotfiles/
├── agent-skills/                  # shared skills — both agents
│   └── <name>/SKILL.md
├── agent-rules/                   # shared global rules
│   └── <name>.md                  # plain markdown with Cursor-style frontmatter
├── agent-mcp/
│   └── mcp-servers.json.tmpl      # shared MCP servers — both agents
├── dot_cursor/
│   ├── skills-cursor/<name>/      # Cursor-only skills (chezmoi-managed)
│   ├── settings.json
│   ├── mcp.json.tmpl              # one-line include of agent-mcp/
│   ├── hooks.json
│   └── hooks/
└── dot_claude/
    ├── settings.json.tmpl
    └── hooks/
```

The `agent-*` directories are listed in `.chezmoiignore` so they don't materialize at `$HOME` — only their rendered/synced outputs do.

## What gets rendered where

| Source | Cursor target | Claude target |
| --- | --- | --- |
| `agent-skills/<name>/` | `~/.cursor/skills/<name>/` | `~/.claude/skills/<name>/` |
| `agent-rules/<name>.md` | `~/.cursor/rules/<name>.mdc` (frontmatter preserved) | `~/.claude/CLAUDE.md` (only entries with `alwaysApply: true`) |
| `agent-mcp/mcp-servers.json.tmpl` | `~/.cursor/mcp.json` (via `dot_cursor/mcp.json.tmpl`) | Claude user scope via `claude mcp add` (in `~/.claude.json`) |
| `dot_cursor/skills-cursor/<name>/` | `~/.cursor/skills-cursor/<name>/` | — (not pushed) |

The sync runs from three chezmoi scripts in the repo root: `run_onchange_after_30-agent-skills-sync.sh.tmpl`, `…31-agent-rules-sync.sh.tmpl`, `…32-agent-mcp-sync.sh.tmpl`. Each carries a fingerprint derived from its source files; chezmoi re-runs it whenever the fingerprint changes.

## Adding a new skill (shared)

1. Create `agent-skills/<name>/SKILL.md` (and any helper scripts) in this repo.
2. `chezmoi apply` — it appears in both `~/.cursor/skills/` and `~/.claude/skills/`.

Quick ad-hoc resync without re-applying everything: `sync-agent-skills` (uses rsync to both targets).

## Adding a Cursor-only skill

1. Create `dot_cursor/skills-cursor/<name>/SKILL.md`.
2. `chezmoi apply`.

## Adding a new global rule

1. Create `agent-rules/<name>.md` with frontmatter:

   ```markdown
   ---
   description: One-line description
   alwaysApply: true        # set to false for glob-scoped rules
   globs: src/**/*.ts       # optional, Cursor-only
   ---

   # Rule body in markdown
   ```

2. `chezmoi apply`. The renderer:
   - Writes `~/.cursor/rules/<name>.mdc` (frontmatter passes through verbatim).
   - If `alwaysApply: true`, appends the body to `~/.claude/CLAUDE.md`. If `false`, Claude is skipped — globs would over-apply in Claude's always-loaded global file.

## Adding a new MCP server

1. Edit `agent-mcp/mcp-servers.json.tmpl` and add an entry under `mcpServers`. Use chezmoi template syntax for any environment-specific paths (e.g. `{{ .chezmoi.homeDir }}`).
2. For secrets, use `{{ onepasswordRead "op://Dotfiles/<item>/<field>" }}`. Don't put PATs/credentials in the file.
3. `chezmoi apply`. Cursor reads the regenerated `~/.cursor/mcp.json`; Claude gets `claude mcp remove` + `add --scope user` for each server.

Verify:

```bash
cat ~/.cursor/mcp.json | jq '.mcpServers | keys'
claude mcp list
```

Restart Cursor for it to pick up new MCP entries; Claude Code reloads them automatically.

## Removing entries

- Delete the file/folder from `agent-skills/`, `agent-rules/`, or the entry from `agent-mcp/mcp-servers.json.tmpl`.
- `chezmoi apply`:
  - Skills/rules: rsync `--delete` removes the corresponding target dirs/files.
  - MCP: the sync script only adds servers listed in the JSON; previously-added servers that are no longer in the file remain in `~/.claude.json` until you `claude mcp remove --scope user <name>` manually (rare; usually you're modifying, not removing).

## Secrets via 1Password

`chezmoi apply` shells out to `op read` whenever a template calls `onepasswordRead`. Make sure the 1Password CLI is signed in (`op whoami` works) before applying. On a fresh machine: `op account add`, then sync.

The vault name comes from `~/.config/chezmoi/chezmoi.toml` (`onePasswordVault = "Dotfiles"`).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Skill appears in only one agent | Check `~/.cursor/skills/<name>` and `~/.claude/skills/<name>` — should be identical. If not, run `sync-agent-skills`. |
| `chezmoi apply` fails on MCP | Check `~/.config/chezmoi/chezmoi.toml` is loaded and `op` is signed in (only matters when a template uses `onepasswordRead`). |
| Claude doesn't see a new MCP server | `claude mcp list`. If missing, re-run `chezmoi apply --force`. If `chrome-devtools`/stdio servers fail with "unknown option" — confirm the sync script uses `--` between the server name and its command. |
| Claude `CLAUDE.md` doesn't reflect a new rule | Confirm `alwaysApply: true` in the rule's frontmatter; otherwise it's skipped intentionally. |
| `~/.cursor/skills/dotfiles-skills` reappears | That's `skills-cli` (`@dhruvwill/skills-cli`) syncing a single wrapper-skill. We don't use it for shared dotfiles content (rsync is the path). Run `skills source remove dotfiles-skills` if it's been re-added. |

## Implementation notes

- **Why rsync, not `skills-cli`, for shared skills?** `skills-cli` treats `agent-skills/` as one skill named after the source ("dotfiles-skills") and ships the whole tree as a single wrapper. We need each subdirectory to be its own top-level skill at the target. Rsync gives us that directly. `skills-cli` stays installed for adding **community/remote** skills (`skills source add <github-url> --remote`), which then sync to the same `cursor`+`claude` targets it knows about.
- **Why no Claude global `~/.claude.json` template?** Claude rewrites that file as runtime state — templating it would race with the app. Instead, the sync script invokes `claude mcp add --scope user` per server, which is the supported way to register MCP user-scope.
- **Why is `nushell-mcp.json.tmpl` (at repo root) separate from `agent-mcp/`?** It's read by Raycast from `~/nushell-mcp.json`, a fixed path. The nushell server itself is also listed in `agent-mcp/mcp-servers.json.tmpl` for Claude+Cursor. Both files reference the same binary.
