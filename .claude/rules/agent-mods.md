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
- **Check in three steps, one command:** `bin/mod-check <mod>` runs
  `claude plugin validate`, `tsc` (types of the mod's `dependencies` included)
  and `claude plugin test`. Its tsc needs the `.d.ts` the plugin-authoring
  skill lays, so load that skill once first. An edit reaches the session only
  after `/reload-plugins`. UI tests
  (`$.ui.mount`, a `ui.render` hook beneath standing for other plugins) catch
  what types don't: `$.prompt.submit('/cmd')` is refused, a command runs
  through `$.command.run({ command, args })` (e4d8288c).
- **A mod's command name must not collide with a repo skill.** pr-band's `/pr`
  threw `"/pr" refused: it is the user's /pr` in work worktrees (team skill
  `pr`), and a throw in `session.start` skips the whole hook: PR polling never
  started there, silently (30c41c3e). Give commands specific names (`pr-peek`,
  not `pr`), end `$.command.register(...)` with `.catch(() => {})`, and
  reproduce with headless `claude -p` run inside a real worktree that has the
  team skills, not a clean dir.
- **Headless probe: prompt first.** `claude -p "<prompt>" --allowedTools
  "Bash(x *)" --plugin-dir <copy> </dev/null`. A list flag before the prompt
  eats it (`Input must be provided either through stdin or as a prompt
  argument`). Waiting is the mod's job (`$.clock.sleep`), not a `sleep` in the
  prompt; Haiku refuses it.
- **A band composes:** an `AbovePrompt` hook returns
  `<Box flexDirection="column">{own}{await next(e)}</Box>`. A tree returned
  without `next` hides every other mod's band.
- **A dev copy plus the installed copy loads the mod twice.** After
  installing, delete `~/.claude/dev-mods/<session>/<mod>`.
- **Safety guards stay in shell hooks** (`block-dangerous-commands.sh`): a mod
  hook that throws is skipped and the tool runs anyway. Mods do lint, bands,
  panes.
- **A pane opened unasked seats only from 144 columns**; a tiled tuios window is
  often narrower, so it waits undrawn (`isPlaced: false`). Give the mod a command that opens it
  (asked = any width) and toast that command when `isPlaced` is false.
- **`Image` inside tuios**: Claude Code turns images off there (it
  answers XTVERSION `tuios`); `CLAUDE_CODE_FORCE_TERMINAL_IMAGES=1` in `env.nu`
  turns them back on. Verified with the fullscreen (alt screen) renderer. Shrink
  with `sips -Z 1600` first (herdr dropped > ~6 M px). A preview nobody picks
  from is useless: shot-pane (a pane with the newest shot) gave way to
  shot-pick (fzf in a split, kitty preview by hand, the pick typed into the
  prompt) on 2026-10-30. Kitty images from a **tuios popup** drew once and then
  never again, server restart included; a tiled split draws them. chafa text
  previews of terminal screenshots were unreadable.
- **`greg-mods` mods load from `agent-mods/<mod>` itself.** `~/.claude/plugins/cache/greg-mods/<mod>/0.1.0/` is a stale copy from install day; never diff against it (`claude plugin update` says "read from its folder: nothing to update"). An edit reaches a session through `/reload-plugins` or a new session.
- **The `[-]` beside an `AbovePrompt` band is the engine's collapse**, not a mod button. A mod cannot draw a `[+]` for a collapsed band; it comes back with `ctrl+x ctrl+a` or a click on the "plugin panel hidden" line.
