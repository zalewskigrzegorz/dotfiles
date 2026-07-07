---
description: Two-way DataGrip workflow over the JetBrains MCP — write/replace SQL in the active console, read the currently open query, ask the user to run it, then pull the result rows back via clipboard so Claude can see them without DB credentials. Use whenever the user wants Claude to draft, edit, or inspect SQL inside DataGrip, or wants Claude to "see" what a query returned — phrases like "napisz query", "widzisz wynik?", "co zwraca to query", "sprawdź co zwróciło", "pokaż wynik", "popraw to query", "zobacz w DataGripie", "what did the query return", "can you see the result". Trigger even when the user doesn't explicitly name DataGrip — if SQL is involved and they're working in a JetBrains IDE, this is the right skill.
---

# g-datagrip

Two-way workflow with the user's DataGrip session over the JetBrains MCP. Claude can read and rewrite the active query, ask the user to execute it (Cmd+Enter), and then read the result rows by routing them through the macOS clipboard — no DB credentials required.

## Required tools

JetBrains MCP:
- `mcp__jetbrains__get_open_in_editor_file_path` — what console/query is active
- `mcp__jetbrains__get_open_in_editor_file_text` — full current query
- `mcp__jetbrains__get_selected_in_editor_text` — current selection only
- `mcp__jetbrains__replace_current_file_text` — overwrite the whole console
- `mcp__jetbrains__replace_selected_text` — replace just the selection
- `mcp__jetbrains__execute_action_by_id` — trigger DataGrip actions (export, fetch-all, etc.)
- `mcp__jetbrains__execute_terminal_command` — runs in DataGrip's terminal (**nushell**)
- `mcp__jetbrains__get_terminal_text` — last terminal output

Plus: `Read` on `/tmp/dg-out.tsv`.

## Operations

### Inspect the active query

Always start by checking what's in the editor:

```
mcp__jetbrains__get_open_in_editor_file_path
mcp__jetbrains__get_open_in_editor_file_text
```

DataGrip consoles live under `~/Library/Application Support/JetBrains/<IDE>/consoles/db/<uuid>/console_<N>.sql`. If the path is empty, the user has no active editor — ask them to open or focus a console.

For surgical edits, read just the selection:

```
mcp__jetbrains__get_selected_in_editor_text
```

### Write or replace the query

Whole console (default for fresh queries):

```
mcp__jetbrains__replace_current_file_text  text="SELECT * FROM subscriptions;\n"
```

Just the selection (when iterating on a fragment):

```
mcp__jetbrains__replace_selected_text  text="..."
```

After writing, tell the user briefly what's there and that they should run it (Cmd+Enter). Don't try to execute via an action — leave Run to the user, it's faster and avoids "no DB connected" failure modes.

### Read query results (the no-credentials route)

Results are not exposed by the MCP. Route them through the clipboard:

**Step 1 — focus reminder (non-negotiable):**

The export action only works when focus is on the result table. Before triggering anything, say to the user:

> "Kliknij raz w komórkę wyniku w DataGripie (gdziekolwiek w tabeli) i daj znać kiedy gotowe."

Wait for `ok` / `gotowe` / `done`. Running the action with editor focus copies SQL code or stale clipboard contents and you'll confidently report nonsense.

**Step 2 — export to clipboard:**

```
mcp__jetbrains__execute_action_by_id  actionId="Console.TableResult.ExportToClipboard"
```

The `ok` response only confirms dispatch, not success. Verify in step 3.

**Step 3 — pipe clipboard to file and read:**

DataGrip's terminal is **nushell**, not bash. Use pipe + `save`, never `&&` or POSIX `>`:

```
mcp__jetbrains__execute_terminal_command  command="pbpaste | save -f /tmp/dg-out.tsv; wc -l /tmp/dg-out.tsv"
```

Then `Read /tmp/dg-out.tsv`.

**Step 4 — detect wrong-focus failure:**

If `/tmp/dg-out.tsv` is empty, contains SQL keywords (`SELECT`/`FROM`/etc.), or unrelated text (URL, chat snippet), the user clicked somewhere else. Don't loop silently:

> "Clipboard miał `<co tam było>` — focus nie był na wyniku. Kliknij komórkę tabeli wyniku jeszcze raz i daj znać."

Then retry steps 2–3.

### Fetch all rows before exporting (when needed)

DataGrip's clipboard export honors the visible page (default 500 rows). If the user expects "all rows":

```
mcp__jetbrains__execute_action_by_id  actionId="Console.TableResult.FetchAllData"
```

Then proceed with steps 2–3. If that action ID is wrong on the user's DataGrip version, fall back to telling the user to press `Cmd+Alt+End` (`⌘⌥End`) to fetch all, then continue.

### Read DataGrip's terminal output

Useful when the user runs CLI tools (psql, mysql, sqlite3) in DataGrip's embedded terminal:

```
mcp__jetbrains__get_terminal_text
```

Captures the first terminal tab only.

## Why not save direct to a file?

`Console.TableResult.ExportToFile` and "Dump Data" both open a save dialog — there is no headless save-to-fixed-path action in DataGrip (verified on 2025.1). Even with a remembered last path the dialog still appears. Clipboard is the only zero-click route.

## Result format

DataGrip's default clipboard export is a small box-drawing grid:

```
+-----+----+
|count|3059|
+-----+----+
```

For multi-row results: header line + N data rows. When reporting back, strip the `+---+` borders and present as a clean markdown table or plain TSV. For one-cell results just say the value.

## Pitfalls

- **Nushell, not bash.** `pbpaste > x` errors with `shell_andand` / redirection complaints. Always use `pbpaste | save -f x`.
- **`ok` is not success.** `execute_action_by_id` returns `ok` even when nothing happened (wrong focus, action not applicable). Always verify by reading the file.
- **First terminal only.** `get_terminal_text` and `execute_terminal_command` target the first terminal tab. Keep DataGrip's terminal at a single tab during this flow.
- **Don't execute queries from Claude.** There's an action for it but it tends to fail silently when no DB is connected and the user can't always tell why. Let them press Cmd+Enter.
- **Console paths are UUID-keyed.** Don't memoize console paths across sessions — DataGrip rotates them.
