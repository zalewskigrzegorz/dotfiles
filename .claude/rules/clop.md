---
paths:
  - "run_onchange_after_14-macos-defaults.sh.tmpl"
  - "bin/clop-share"
  - "agent-mcp/mcp-servers.json.tmpl"
---

# Clop

## "Nie widzę dropzone / progressu" — check in this order (3c5d8334, ~15 calls)

1. **Onboarding finished?** Its window can sit hidden under Finder on the ultrawide. Look for off-screen windows and bring Clop to the front.
2. **Grants.** With no Accessibility, drag detection never starts. A missing grant goes through `grant-failure-ask` and `open-here`, never a TCC reset.
3. **Which screen has the cursor.** Floating results show there; they appeared on the left monitor at X=-1920.
4. **The drop zone only shows during a drag.** Say so before debugging it.
5. A fresh PNG on `~/Desktop` may not trigger the watcher while a clipboard copy does.

## MCP traps

- `clop_settings_schema` is ~88 KB and overflows the MCP limit: `jq '.settings[] | select(…)'` over the saved `tool-results/*.txt`, never another unfiltered call.
- A script in `clop_pipeline_run` that dies with `exit 1` hides the cause: run it by hand first, on a file name with a space.
- `bin/clop-share` uploads with an anonymous `PUT` to the drop host, which answers with a link. Delete test uploads afterwards.

## What dotfiles tracks

Tracked: watched folders and `mcpEnabled` (stage 14 `defaults write`), `bin/clop-share`, the MCP entry. **Not tracked yet:** conversion rules and pipelines, which live only in Clop's plist. A new Mac does not get them; exporting them is a separate task.
