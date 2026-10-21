# Browser automation — internals

**`claude-in-chrome` RETIRED 2026-08-23** — kept hanging, and `agent-browser` and
`bsk` cover it. It was never a config-file MCP (not in `agent-mcp/`); it ships
with the harness and pairs via the Chrome extension, so the only repo-side gate
is `mcp__claude-in-chrome__*` in `permissions.deny`
(`.chezmoitemplates/claude-settings.json`) — that blocks calls but the tools
still load if the extension is paired. Untrack-able off-switch (lives in
`~/.claude.json` → `claudeInChromeDefaultEnabled`): `/chrome` → turn off
"Enabled by default", or disable the extension (`fcoeoabgfenejglbffodgkkbkcdhcgfn`)
in `chrome://extensions`. Don't re-add it.

**BrowserSkill** ([Tencent/BrowserSkill](https://github.com/Tencent/BrowserSkill),
MIT) drives Greg's **real, logged-in Comet profile** from the CLI in a separate,
visible **Agent Window** — his own windows are left alone unless a tab is
explicitly `bsk tab borrow`ed. Policy lives in
`agent-rules/browserskill-agent-window.md`.

- CLI + daemon → `~/.local/bin/bsk`, state in `~/.bsk` (runtime only, not tracked).
  Upgrade with `bsk update`; health check `bsk doctor` (all rows `ok`/`N/A`).
  `agent skill up to date → N/A` is expected — see the skill bullet below.
- Extension is **hand-installed** from the [Chrome Web Store](https://chromewebstore.google.com/detail/hhcmgoofomhgciiibhipgmgkgnoenaoi)
  (id `hhcmgoofomhgciiibhipgmgkgnoenaoi`) and lives in Comet's `Default` profile.
  A script cannot install it — `0 browsers connected` in `doctor` means it's off.
- **Skill dir is `bsk`, not `browser-skill`** (renamed 2026-08-23 so Greg can
  just say "agent-browser" or "bsk" and hit the right one). It comes from
  `agent-skills/bsk/` via stage 30, **not** from `bsk install-skill` (rsync
  `--delete` would fight it). Side effect: `bsk doctor` looks for
  `~/.claude/skills/browser-skill` and now reports `agent skill up to date →
  N/A no agent skill installed`. That's by design. To refresh after `bsk update`:
  `bsk install-skill --harness claude-code --yes`, copy
  `~/.claude/skills/browser-skill/SKILL.md` into `agent-skills/bsk/SKILL.md`,
  **keep our `name: bsk` frontmatter + trigger phrases**, then `bin/sync` (the
  rsync deletes the stray `browser-skill/` dir).
- **`npm install bsk` is the wrong package** — an abandoned 2017 Vue app squatting
  that name. Only the GitHub release installer is correct.
