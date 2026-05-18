---
name: agent-browser
description: Automate browser interactions via the agent-browser CLI (Chrome/CDP, accessibility-tree snapshots with @eN refs). Use when the user asks to navigate, click, fill, extract text, take screenshots, log into a site, test a web app, or automate any browser task. Prefer this over the playwright-cli skill while the playwright MCP is disabled.
allowed-tools: Bash(agent-browser:*) Bash(npx agent-browser:*)
---

# agent-browser

Fast browser automation CLI for AI agents. Chrome/Chromium via CDP, no Playwright/Puppeteer dependency. Accessibility-tree snapshots with compact `@eN` refs.

## Load the real skill first

This SKILL.md is a thin pointer. The full, version-matched usage guide ships with the CLI — load it before doing any browser work:

```bash
agent-browser skills get core --full
```

For specialized tasks load the matching skill instead:

```bash
agent-browser skills list                  # see all available
agent-browser skills get electron --full   # VS Code, Slack desktop, Discord, Figma desktop
agent-browser skills get slack --full      # Slack web workspaces
agent-browser skills get dogfood --full    # exploratory UI testing / bug hunting
agent-browser skills get agentcore --full  # AWS Bedrock AgentCore cloud browsers
agent-browser skills get vercel-sandbox --full  # Vercel Sandbox microVMs
```

## The core loop (cheat sheet)

```bash
agent-browser open <url>        # 1. open
agent-browser snapshot -i       # 2. interactive elements only — gives @e1, @e2 ...
agent-browser click @e3         # 3. act on refs
agent-browser snapshot -i       # 4. re-snapshot after ANY page change (refs go stale)
agent-browser close             # 5. when done (or `close --all`)
```

The browser persists across commands via a daemon, so chained calls share state. Chain with `&&` in a single shell call when you want atomic sequences.

## Quick reference

```bash
# Reading
agent-browser get text @e1
agent-browser get html @e1
agent-browser get attr @e1 href
agent-browser get title
agent-browser get url

# Acting
agent-browser fill @e2 "hello"
agent-browser type @e2 " world"
agent-browser press Enter
agent-browser select @e4 "option-value"
agent-browser check @e3
agent-browser upload @e5 file.pdf
agent-browser scroll down 500

# Locators (when refs don't fit)
agent-browser find role button click --name "Submit"
agent-browser find text "Sign In" click
agent-browser find label "Email" fill "user@test.com"
agent-browser find testid "submit-btn" click

# Waiting (pick one; avoid bare `wait <ms>`)
agent-browser wait @e1
agent-browser wait --text "Success"
agent-browser wait --url "**/dashboard"
agent-browser wait --load networkidle

# Output
agent-browser screenshot result.png
agent-browser screenshot --full
agent-browser screenshot --annotate        # labeled screenshot for vision models
agent-browser pdf page.pdf

# Sessions / profiles
agent-browser --profile Default open gmail.com           # reuse Chrome login state
agent-browser profiles                                    # list available profiles
agent-browser --session-name myapp open example.com      # auto save/restore state
agent-browser state save ./auth.json                      # persist cookies + storage

# CDP / streaming
agent-browser --auto-connect snapshot                     # attach to running Chrome
agent-browser --cdp 9222 snapshot
agent-browser stream enable

# AI chat (uses Vercel AI Gateway via AI_GATEWAY_API_KEY)
agent-browser chat "open google.com and search for cats"
```

## Notes

- Refs (`@eN`) are reassigned on every snapshot. Always re-snapshot after page-changing actions.
- Snapshot output is ~200-400 tokens vs. raw HTML — prefer `snapshot -i` over `get html`.
- Default engine is Chrome. `AGENT_BROWSER_ENGINE=lightpanda` for headless light engine.
- For credentials use `agent-browser auth save/login` instead of shell history.
- Currently we test agent-browser as a replacement for the playwright MCP. If it underperforms, re-enable `playwright` in `agent-mcp/mcp-servers.json.tmpl`.
