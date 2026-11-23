---
paths:
  - "agent-mods/**"
  - "agent-plugins/**"
  - "run_onchange_after_33-claude-plugins-sync.sh.tmpl"
---

# Claude Code mods (`agent-mods/`)

Load the `plugin-authoring` skill before writing one; its `types/claude-code.d.ts` is the API.

- **`greg-mods` mods load from `agent-mods/<mod>` in the main checkout** (`~/Code/dotfiles`), not a worktree and not `~/.claude/plugins/cache/greg-mods/<mod>/0.1.0/` (a stale install-day copy; never diff against it). From a worktree: push, fast-forward the main checkout (`dotfiles-ops.md`). An edit reaches a session only via `/reload-plugins` or a new session.
- **Register every mod twice**: `agent-mods/.claude-plugin/marketplace.json` and `agent-plugins/plugins.json.tmpl`; one missing → stage 33 uninstalls it. Add the marketplace by local path, never a GitHub `tree/…` URL.
- **`git check-ignore -v agent-mods/<mod>` before the commit**: root `.gitignore` has `*token*`, which silently dropped `agent-mods/token-weather`.
- **Check with `bin/mod-check <mod>`**: `claude plugin validate`, `tsc` (incl. the mod's `dependencies`) and `claude plugin test`. Its tsc needs the `.d.ts` the plugin-authoring skill lays, so load it once first. UI tests (`$.ui.mount`, a `ui.render` hook standing in for other plugins) catch what types don't: `$.prompt.submit('/cmd')` is refused; run commands via `$.command.run({ command, args })`.
- **A command name must not collide with a repo skill.** pr-band's `/pr` threw `"/pr" refused: it is the user's /pr` in work worktrees (team skill `pr`), and a throw in `session.start` skips the whole hook, silently (30c41c3e). Use specific names (`pr-peek`), end `$.command.register(...)` with `.catch(() => {})`, reproduce with headless `claude -p` inside a real worktree with the team skills.
- **Headless probe: prompt first.** `claude -p "<prompt>" --allowedTools "Bash(x *)" --plugin-dir <copy> </dev/null`; a list flag before the prompt eats it. Waiting is the mod's job (`$.clock.sleep`); Haiku refuses a `sleep` in the prompt.
- **A band composes:** an `AbovePrompt` hook returns `<Box flexDirection="column">{own}{await next(e)}</Box>`; without `next` it hides every other mod's band.
- **The `[-]` beside an `AbovePrompt` band is the engine's collapse**, not a mod button; a mod can't draw a `[+]`. It comes back with `ctrl+x ctrl+a` or a click on "plugin panel hidden".
- **Dev copy plus installed copy loads the mod twice**: after installing, delete `~/.claude/dev-mods/<session>/<mod>`.
- **Safety guards stay in shell hooks** (`block-dangerous-commands.sh`): a mod hook that throws is skipped and the tool runs anyway. Mods do lint, bands, panes.
- **An unasked pane seats only from 144 columns**; tiled tuios windows are often narrower (`isPlaced: false`). Give the mod a command that opens it (asked = any width) and toast it when `isPlaced` is false.
- **`Image` inside tuios**: Claude Code turns images off there (XTVERSION `tuios`); `CLAUDE_CODE_FORCE_TERMINAL_IMAGES=1` in `env.nu` turns them on (verified with the alt-screen renderer). Shrink with `sips -Z 1600` first. Kitty images in a **tuios popup** draw once, then never; a tiled split works. chafa previews of terminal shots were unreadable. A preview nobody picks from is useless: shot-pick (fzf in a split, pick typed into the prompt) replaced shot-pane.
