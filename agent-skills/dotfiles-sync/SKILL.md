---
name: dotfiles-sync
description: Audits drift between live system and ~/Code/dotfiles (Brewfile, Claude plugins/MCP/skills/hooks/settings, dot_config/, chezmoi diff) and syncs missing pieces back. Use for "sync dotfiles", "audit drift", "add new app/brew/plugin/MCP/skill to dotfiles", or verifying `chezmoi apply` reproduces setup.
---

# dotfiles-sync

## When to use

- "Sync my dotfiles" / "audit my dotfiles" / "what's drifted?"
- "I installed `<app>`, add it to my dotfiles"
- "I added a Claude plugin / MCP server / skill — persist it"
- Before reinstalling on a new machine: confirm `chezmoi apply` reproduces current state.

## Repo facts (do not relearn)

- Repo root: `~/Code/dotfiles`. Source of truth for `chezmoi apply`.
- Naming: `dot_*` → `~/.* `, `*.tmpl` → templated, `private_*` → 0600, `executable_*` → 0755.
- Sync scripts run in numeric order on `chezmoi apply`:
  - `10-brew-bundle` — applies Brewfile
  - `30-agent-skills-sync` — rsyncs `agent-skills/` → `~/.claude/skills` + `~/.cursor/skills`
  - `31-agent-rules-sync` — rsyncs `agent-rules/`
  - `32-agent-mcp-sync` — applies `agent-mcp/mcp-servers.json.tmpl`
  - `33-claude-plugins-sync` — applies `agent-plugins/plugins.json.tmpl`
- Commit directly to `master`. No PRs. Personal repo.

## Two modes

Pick mode based on the user's ask:
- **Audit mode** (default): scan everything, show drift, fix per item.
- **Add-app mode**: user named a specific app/plugin/MCP/skill to persist.

If unclear, ask once: "audit drift, or add a specific app?"

---

## Audit mode

### Step 1 — Run all drift checks in parallel

Run these in one batch (independent commands):

| Check | Command | Compare against |
|---|---|---|
| chezmoi pending | `chezmoi diff` | (any output = drift in tracked files) |
| Brew formulae | `brew leaves` | `grep '^brew "' dot_Brewfile.tmpl` |
| Brew casks | `brew list --cask` | `grep '^cask "' dot_Brewfile.tmpl` |
| Brew taps | `brew tap` | `grep '^tap "' dot_Brewfile.tmpl` |
| Claude plugins | `claude plugin list` (or `ls ~/.claude/plugins/`) | `agent-plugins/plugins.json.tmpl` |
| Claude MCP servers | `claude mcp list` | `agent-mcp/mcp-servers.json.tmpl` + `nushell-mcp.json.tmpl` |
| Claude skills | `ls ~/.claude/skills/` | `ls agent-skills/` |
| Claude hooks | `ls ~/.claude/hooks/` | `ls dot_claude/hooks/` |
| Claude output-styles | `ls ~/.claude/output-styles/` | `ls dot_claude/output-styles/` |

Notes:
- Brewfile is templated; render with `chezmoi execute-template < dot_Brewfile.tmpl > /tmp/Brewfile.rendered` before diffing if templating matters.
- For Claude plugins/MCP, the source-of-truth `.tmpl` is what `chezmoi apply` installs. Drift = installed locally but not in `.tmpl`.

### Step 2 — Build a drift table

Present one table, grouped by source. Mark each row:

- `LIVE_ONLY` — installed but not in repo. **Action: add to repo.**
- `REPO_ONLY` — in repo but not installed. **Action: run `chezmoi apply` or note as intentional removal.**
- `MODIFIED` — exists in both, content differs. **Action: `chezmoi re-add` (live → repo) or `chezmoi apply` (repo → live).**

Example:

```
Source            Item                          State        Suggested action
brew              ripgrep                       LIVE_ONLY    add to dot_Brewfile.tmpl
brew (cask)       raycast                       REPO_ONLY    brew install --cask raycast
claude plugin     superpowers                   LIVE_ONLY    add to agent-plugins/plugins.json.tmpl
claude mcp        playwright                    LIVE_ONLY    add to agent-mcp/mcp-servers.json.tmpl
claude skill      my-new-skill                  LIVE_ONLY    cp -r ~/.claude/skills/my-new-skill agent-skills/
chezmoi tracked   dot_config/nvim/init.lua      MODIFIED     chezmoi re-add ~/.config/nvim/init.lua
```

### Step 3 — Confirm per group, then apply

Ask the user once per source group: "Apply suggested actions for `brew` (3 items)?" Don't ask per row unless they want granular control.

Apply order (matters):
1. Edit `.tmpl` files first (declarative state).
2. Run `chezmoi re-add` for tracked file drift.
3. Run `chezmoi apply` last to verify the resulting state.

### Step 4 — Verify

After applying, re-run `chezmoi diff`. Output should be empty. Report what was committed and what's staged but uncommitted.

Do **not** commit automatically — surface a suggested commit message, let the user run `g-commit`.

---

## Add-app mode

User says: "I installed `<X>`, add it to my dotfiles" or "add `<X>` to my dotfiles".

### Decision tree

1. Is `<X>` a brew formula/cask? → check `brew info <X>`. If yes:
   - Append to the matching section of `dot_Brewfile.tmpl` (taps, formulae, casks — keep alphabetical within section).
   - If app has config in `~/.config/<X>` or `~/.<X>rc`, run `chezmoi add ~/.config/<X>` (or the dotfile path).
2. Is `<X>` a Claude plugin? → edit `agent-plugins/plugins.json.tmpl`.
3. Is `<X>` an MCP server? → edit `agent-mcp/mcp-servers.json.tmpl` (or `nushell-mcp.json.tmpl` if it's for nushell mcp).
4. Is `<X>` a Claude skill? → `cp -r ~/.claude/skills/<X> agent-skills/<X>` (or write the SKILL.md directly there).
5. Is `<X>` an arbitrary dotfile? → `chezmoi add <path>`, then verify the source-name convention is correct (`dot_*`, `private_*`, etc.).

After any of the above: run `chezmoi diff` to confirm the change is captured. For Brewfile changes, optionally run `chezmoi apply` so `brew bundle` installs it cleanly via the sync script.

### What NOT to do

- Don't `cp` files directly into the repo if `chezmoi add` would work — chezmoi sets the source name based on the target path.
- Don't manually edit synced output (e.g. `~/.claude/skills/...`) when the source (`agent-skills/...`) exists. Edit the source.
- Don't commit until the user asks. Always end with: "ready to commit — run `g-commit`?"

---

## Reading templated files

`dot_Brewfile.tmpl`, `*.json.tmpl`, `settings.json.tmpl` use Go templating. To see the rendered output for a given machine:

```bash
chezmoi execute-template < dot_Brewfile.tmpl
```

Useful for diffing actual installed state against what `chezmoi apply` would produce.

---

## Helper scripts (token-savers)

Two helpers live in `~/.claude/skills/dotfiles-sync/scripts/`. Use them instead of reading whole files and reasoning about diffs in-context.

### `audit-drift.sh`

Compact classified view of `chezmoi diff`. Each row is `PATH | KIND | SUGGESTED_ACTION`:

- `FILE_DRIFT` — plain file, `chezmoi re-add` captures it
- `TEMPLATE_DRIFT` — source is `.tmpl`; `chezmoi re-add` may no-op even when live differs (template still renders to live). Manual rewrite needed — see next section.
- `BINARY_DRIFT` — same as file, but watch the exec bit (re-add can drop it if source lacks `executable_` prefix or wasn't tracked with mode 100755).
- `FAKE_SCRIPT` — `run_*` script that always appears in `chezmoi diff` because it executes on every apply. Not real drift; nothing to capture.

Run it first whenever the user says "sync dotfiles" or "what's drifted" — it answers the question in seconds without loading any file content.

### `render-and-diff.sh <source-or-target-path>`

Render a `.tmpl` and byte-diff it against its chezmoi target (or the other way around — either path resolves to the pair).

- Exit 0 → `MATCH` (byte-identical, no work needed)
- Exit 1 → `DIFF` (unified diff printed; act on it)
- Exit 2 → invocation error

Use this as the loop terminator while doing template-aware re-sync: rewrite → run → repeat until `MATCH`.

---

## Template-aware re-sync (live → .tmpl)

The case: source is `.tmpl`, live drifted, **live is the truth** (e.g. Claude Code reformatted `~/.claude/settings.json` and rewrote key ordering; the cosmetic shape is now canonical because Claude will keep producing it). `chezmoi re-add` won't help — it keeps the template untouched when the rendered output still parses to the same data.

### Workflow

1. **Confirm "live is truth"** with the user. If source is canonical and live got mangled by some background tool, the answer is `chezmoi apply` (revert live), **not** a rewrite. Only proceed when the user explicitly wants live → source.

2. **Inventory template tokens to preserve.** Read the existing `.tmpl` and list everything inside `{{ ... }}` — typically:
   - `{{ .chezmoi.homeDir }}`, `{{ .chezmoi.os }}` (path / OS substitutions)
   - `{{- if eq .chezmoi.os "darwin" }}...{{- end }}` (OS-conditional blocks)
   - `{{ includeTemplate "..." . | ... }}` (cross-file references)
   - Anything with `.chezmoi.*`, `.profile.*`, secret functions (`onepasswordRead`, etc.)

   These must survive the rewrite or `chezmoi apply` on a fresh machine will break (wrong paths, missing OS branches, secrets gone).

3. **Rewrite the `.tmpl` to mirror live byte-for-byte, then re-insert the tokens.** Concretely: copy live verbatim into the `.tmpl`, then walk through the preserved-token list and put each one back where it belongs. For OS-conditional blocks, you'll need to look at git history or ask the user which fields are platform-specific (live shows only the current platform's view).

4. **Verify byte-identity:**

   ```bash
   ~/.claude/skills/dotfiles-sync/scripts/render-and-diff.sh <source.tmpl>
   ```

   Exit 0 = done. Exit 1 = patch and re-run.

5. **Sanity check on the other platform.** If the file has `{{ if eq .chezmoi.os "..." }}` branches, mentally render the *other* OS case and confirm it's still valid JSON/YAML/whatever. There's no automatic check for this — the user runs both machines, so they can spot-check on the lab.

### Caveats

- **`chezmoi re-add` on a templated file is mostly a no-op** when the template still renders to live content (even if the live formatting differs from what the template would render). Don't be surprised when it does nothing — that's the trigger for manual rewrite.
- **Beware of self-rewriting tools.** If Claude Code, an IDE, or a daemon keeps rewriting the live file, the diff will come back. Decide once: either match live (this section) and accept re-sync on changes, or keep the canonical template and `chezmoi apply` to revert live whenever it drifts. Don't oscillate.
- **`includeTemplate` indirection.** If the original template sourced data from another file (e.g. `agent-plugins/plugins.json.tmpl`), dropping it inlines the data — duplication risk. Keep the indirection if the data is shared with another consumer; drop it if the indirection is only for this one file.

## Idempotency

Re-running this skill on an already-clean repo should produce: "No drift detected. `chezmoi diff` is clean." Never write changes unless drift is found.

## Failure modes to watch for

- `claude` CLI not on PATH — fall back to listing `~/.claude/plugins/`, `~/.claude/skills/`, parsing `~/.claude.json` for MCP entries.
- Brewfile is templated — raw grep can miss items behind `{{ if }}` blocks. If unsure, render first.
- `.chezmoiignore` may exclude some files from sync intentionally — check it before flagging "missing in repo".
- `agent-skills/`, `agent-rules/`, `agent-mcp/` are synced **into** `~/.claude/...` by `run_onchange_*` scripts. Live drift in `~/.claude/skills/<name>/` will be **overwritten** on next `chezmoi apply` unless persisted back into `agent-skills/`.
