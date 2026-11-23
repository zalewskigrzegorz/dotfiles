---
name: agent-browser
description: The UNATTENDED browser — Chrome/CDP on its own profile, accessibility snapshots with @eN refs, cheapest in tokens. Use on "agent browser", "strzel na tę stronę", "sprawdź tę stronę", "zescrapuj", "odpal test na deployu", or any browser job with no login and no watching: fetch or scrape a public page, read the DOM, screenshot, smoke-test a deployed URL. His login, bot-block, captcha, 2FA or him watching → `browsentic`.
allowed-tools: Bash(agent-browser:*) Bash(npx agent-browser:*)
---

# agent-browser

Stack choice and anti-bot sites: rule `browser-stacks.md` (OLX works here, otomoto does not). This file is a pointer: the version-matched guide ships with the CLI, load it before any work:

```bash
agent-browser skills get core --full
agent-browser skills list    # specialised: electron, slack, dogfood, agentcore, vercel-sandbox (… get <name> --full)
```

## Core loop

```bash
agent-browser open <url>
agent-browser snapshot -i       # interactive elements → @e1, @e2 …
agent-browser click @e3         # also fill/type/press/select/check/upload, find role|text|label|testid …
agent-browser snapshot -i       # refs go stale after ANY page change
agent-browser close             # or close --all
```

- A daemon keeps the browser between commands; chain with `&&` for atomic sequences.
- Wait on a state (`wait @e1`, `--text`, `--url`, `--load networkidle`), not bare `wait <ms>`.
- `snapshot -i` (~200–400 tokens) over `get html`. `screenshot --annotate` for vision.
- Credentials: `agent-browser auth save/login`, never shell history.
- Shell state dies between Bash calls: write `agent-browser --session-name <slug> …` in full each call instead of a helper function.
- Playwright `.spec.ts` in the work repo is a different job: the `pwt` nushell helper (`test e2e`). The playwright MCP and global `@playwright/cli` were removed 2026-07-27; the restore recipe is a comment in `agent-mcp/mcp-servers.json.tmpl`.
