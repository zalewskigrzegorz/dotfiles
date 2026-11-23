---
description: Cloud routines (scheduled Claude agents) live only in the cloud — diagnose through RemoteTrigger, not by grepping the repo; their prompts cannot use gh
alwaysApply: true
---

# Cloud routines: `RemoteTrigger`, not the repo

"Padły routines / workflowy w chmurze" (11 blind calls and a repo `rg` once):

1. **They are in no repo.** `RemoteTrigger list` (deferred, load via `ToolSearch`) is the inventory; `get_run_log` on the last failed run is the diagnosis.
2. **`list` output is ~57 KB, saved to a file** starting with `HTTP 200`: `sed 1d <file> | jq`.
3. **No `gh` in the cloud environment.** GitHub goes through GitHub MCP tools (exact `ToolSearch select:…`), blocked hosts through `WebFetch`.
4. **No delete action.** Disable with `update {enabled:false}`; the delete is Greg's click in the UI (open it with `browsentic`).
5. After rewriting a routine, check its first run with `list_runs` before calling it fixed.
