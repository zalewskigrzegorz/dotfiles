---
paths:
  - "run_onchange_after_14-macos-defaults.sh.tmpl"
  - "bin/clop-share"
  - "agent-mcp/mcp-servers.json.tmpl"
---

# Clop

## "Nie widzę dropzone / progressu" — check in this order (3c5d8334)

1. **Onboarding finished?** Its window can hide under Finder on the ultrawide: find off-screen windows, bring Clop to the front.
2. **Grants.** Without Accessibility, drag detection never starts (`grant-failure-ask`, `open-here`).
3. **Which screen has the cursor.** Floating results show there (once on the left monitor at X=-1920).
4. **The drop zone only shows during a drag.** Say so before debugging it.
5. A fresh PNG on `~/Desktop` may not trigger the watcher while a clipboard copy does.

## MCP traps

- `clop_settings_schema` is ~88 KB and overflows the MCP limit: `jq '.settings[] | select(…)'` over the saved `tool-results/*.txt`, never another unfiltered call.
- A script in `clop_pipeline_run` that dies with `exit 1` hides the cause: run it by hand first, on a file name with a space.
- `bin/clop-share` uploads with an anonymous `PUT` to the drop host, which answers with a link. Delete test uploads afterwards.

## What dotfiles tracks

Tracked: watched folders and `mcpEnabled` (stage 14 `defaults write`), `bin/clop-share`, the MCP entry. **Not tracked yet:** conversion rules and pipelines (only in Clop's plist, so a new Mac lacks them; exporting is a separate task).
