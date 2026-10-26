---
paths:
  - "agent-mods/**"
  - "agent-plugins/**"
  - "run_onchange_after_33-claude-plugins-sync.sh.tmpl"
---

# Claude Code mods (`agent-mods/`)

Load the `plugin-authoring` skill before writing one; its `types/claude-code.d.ts`
is the API.

- **The `greg-mods` marketplace reads the main checkout**
  (`~/Code/dotfiles/agent-mods`), not a worktree. From a worktree: push, then
  fast-forward the main checkout, then `/reload-plugins` (0af8b7a3).
- **Register every mod twice**: `agent-mods/.claude-plugin/marketplace.json`
  and `agent-plugins/plugins.json.tmpl`. One missing → stage 33 uninstalls it.
  Add the marketplace by local path, never a GitHub `tree/…` URL.
- **`git check-ignore -v agent-mods/<mod>` before the commit**: root
  `.gitignore` has `*token*`, which silently dropped `agent-mods/token-weather`.
- **Check in three steps:** `claude plugin validate <dir>`, `tsc` with the
  tsconfig from the types header, `claude plugin test <dir>`. UI tests
  (`$.ui.mount`, a `ui.render` hook beneath standing for other plugins) catch
  what types don't: `$.prompt.submit('/cmd')` is refused, a command runs
  through `$.command.run({ command, args })` (e4d8288c).
- **A band composes:** an `AbovePrompt` hook returns
  `<Box flexDirection="column">{own}{await next(e)}</Box>`. A tree returned
  without `next` hides every other mod's band.
- **A dev copy plus the installed copy loads the mod twice.** After
  installing, delete `~/.claude/dev-mods/<session>/<mod>`.
- **Safety guards stay in shell hooks** (`block-dangerous-commands.sh`): a mod
  hook that throws is skipped and the tool runs anyway. Mods do lint, bands,
  panes.
- **A pane opened unasked seats only from 144 columns**; a herdr pane is ~125, so
  it waits undrawn (`isPlaced: false`). Give the mod a command that opens it
  (asked = any width) and toast that command when `isPlaced` is false.
- **`Image` inside herdr needs three things** (shot-pane, e4d8288c):
  `kitty_graphics = true` in herdr's `[terminal]` (server restart),
  `CLAUDE_CODE_FORCE_TERMINAL_IMAGES=1` in `env.nu` (herdr reports
  `TERM_PROGRAM=herdr`, so Claude Code draws only the `alt`), and a picture under
  ~6 M decoded pixels (herdr drops bigger ones silently: `sips -Z 1600` first).
