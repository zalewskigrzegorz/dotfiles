# Browser automation — internals

Which stack to use: `agent-rules/browser-stacks.md`.

**`claude-in-chrome` RETIRED 2026-08-23** — kept hanging, and `agent-browser` and
`browsentic` cover it. It was never a config-file MCP (not in `agent-mcp/`); it ships
with the harness and pairs via the Chrome extension, so the only repo-side gate
is `mcp__claude-in-chrome__*` in `permissions.deny`
(`.chezmoitemplates/claude-settings.json`) — that blocks calls but the tools
still load if the extension is paired. Untrack-able off-switch (lives in
`~/.claude.json` → `claudeInChromeDefaultEnabled`): `/chrome` → turn off
"Enabled by default", or disable the extension (`fcoeoabgfenejglbffodgkkbkcdhcgfn`)
in `chrome://extensions`. Don't re-add it.

**BrowserSkill (`bsk`) REMOVED 2026-10-30** once Browsentic was configured: the
CLI (`~/.local/bin/bsk`, `~/bin/bsk`), its state (`~/.bsk`), stage 27, the skill
and its permissions are gone. The extension (`hhcmgoofomhgciiibhipgmgkgnoenaoi`)
is removed from Comet by hand; Comet itself stays. Don't re-add it.

**Browsentic** settings that live in the extension, not in
`~/.browsentic/config.json`, so `chezmoi apply` cannot restore them: Blocked
sites (`ingbank.pl`, `ing.pl`, `1password.com`) and "Show what the agent does"
(on). Re-enter them by hand on a new Mac.
