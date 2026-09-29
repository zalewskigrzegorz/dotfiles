---
description: Cloud routines (scheduled Claude agents) live only in the cloud — diagnose through RemoteTrigger, not by grepping the repo; their prompts cannot use gh
alwaysApply: true
---

# Cloud routines: `RemoteTrigger`, not the repo

"Padły routines / workflowy w chmurze" (2026-09-22 cost 11 blind `RemoteTrigger`
calls and an `rg` over the repo first):

1. **They are not in any repo.** `RemoteTrigger list` (deferred tool, load via
   `ToolSearch`) is the inventory; `get_run_log` on the last failed run is the
   diagnosis. Don't grep for "routine".
2. **`list` output is ~57 KB and lands in a file** whose first line is
   `HTTP 200`; parse with `sed 1d <file> | jq`.
3. **No `gh` in the cloud environment.** A routine prompt that shells out to
   `gh` fails. GitHub goes through the GitHub MCP tools (loaded with an exact
   `ToolSearch select:…`), and hosts the sandbox blocks go through `WebFetch`.
4. **No delete action.** Disable with `update {enabled:false}`; the actual
   delete is a click in the UI through `bsk` with `request-help --target` on
   the Delete button — irreversible, so it stays Greg's click.
5. After rewriting a routine, check its first run with `list_runs` before
   calling it fixed; two rewrites from 2026-09-22 were never verified.
