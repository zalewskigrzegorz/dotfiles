---
description: Scan the conversation for Bash/MCP calls that hit a permission prompt, propose the widest safe allowlist patterns, confirm via popup, then edit settings.json.tmpl and chezmoi apply so the rule takes effect live. Explicit-invoke command (was the g-allow-add skill).
---

# g-allow-add

Greg keeps getting interrupted by permission popups for safe read-only tools. This command batches the additions in one quick round-trip instead of him hand-editing `settings.json.tmpl` each time.

## Where it goes

Source of truth: `~/Code/dotfiles/dot_claude/settings.json.tmpl`, key `permissions.allow` (flat JSON array of strings).

Live config `~/.claude/settings.json` is generated from the tmpl by `chezmoi apply`. **Never edit the live file** — chezmoi overwrites it on next apply.

After editing the tmpl you MUST run `chezmoi apply ~/.claude/settings.json` so the rule reaches the running Claude session. No restart needed — settings re-read on next tool call.

## Safety net

`~/.claude/hooks/pre-tool-use/block-dangerous-commands.sh` (PreToolUse) unconditionally denies:
- `sudo`, `gh pr merge`, push to protected branches, package publish
- `DROP TABLE/DATABASE/SCHEMA`, `DELETE FROM` without WHERE, `TRUNCATE`
- `rm -rf /`, `rm -rf ~`, `rm -rf $HOME`, `rm -rf <system-dir>`
- `curl | sh`, `> /dev/sdX`, `mkfs`, `dd of=/dev/...`

It also asks (guards) for any `rm`, force push, `chmod 777`, HTTP writes, dep installs, `git reset --hard`, `git clean -f`, PR create/edit.

**Consequence:** wide allow patterns like `Bash(sqlite3 *)`, `Bash(docker *)`, `Bash(brew *)` are safe — the hook catches dangerous variants regardless. Prefer **one wide entry** over five narrow ones; the hook is the policy layer, the allow list is the convenience layer.

## Pattern syntax — TWO STYLES coexist in the file

Greg's `settings.json.tmpl` uses **both** of these interchangeably:

- **Space-glob style**: `Bash(sqlite3 *)`, `Bash(ls *)`, `Bash(git status*)`
- **Colon style**: `Bash(grep:*)`, `Bash(mkdir:*)`, `Bash(chezmoi apply:*)`

Both work in Claude Code. When **checking for duplicates** before adding, you MUST grep for both shapes — a single naive `grep "Bash(grep "` misses the colon form and you'll propose adding something that's already there. Use:

```bash
grep -nE 'Bash\((cmd_name)[ :]' ~/Code/dotfiles/dot_claude/settings.json.tmpl
```

or list all `Bash(...)` entries and eyeball.

When **adding new entries**, match the surrounding block's style (space style around lines 21-110, colon style around lines 178-200).

Other prefix kinds: `Read(/path/**)`, `Edit(/path/**)`, `Write(/path/**)`, `WebFetch`, `WebSearch`, `Skill(<name>)`, MCP tool name like `mcp__server__tool`.

## Workflow

### 1. Scan the recent conversation

Signals to look for:
- Bash tool results that show the command ran AFTER a popup (user approved).
- `<bash-input>` user-blocks where Greg ran the command himself because Claude couldn't.
- Greg's complaints ("znowu pyta", "stop pytać", "irytuje").
- System reminders mentioning permission_mode / hook ask.
- Repeated calls to the same MCP tool that aren't in allow yet.

### 2. Filter out duplicates

For each candidate, grep the tmpl for both `Bash(<cmd> ` AND `Bash(<cmd>:` before proposing. If already present in any shape, drop it silently — don't waste a question slot on a non-change.

### 3. Group by widest safe pattern

For each tool, decide:
- Read-only family (`count`, `list`, `get`, `info`, `view`, `describe`, `dump`, `query`, `show`, `cat`-like) → go wide.
- Has destructive sub-commands too → still go wide IF the hook covers the dangerous variants. Otherwise narrow.

### 4. Ask Greg via AskUserQuestion (multi-select)

Use the `AskUserQuestion` tool with `multiSelect: true`. One option per candidate pattern. Format:

- **label** — the exact allow pattern (e.g. `Bash(sqlite3 *)`). Keep it short, no commentary in the label.
- **description** — one short line explaining what it unblocks and which hook/policy catches the dangerous case. PL+EN mix is fine.

Question text: short and direct, e.g. `"Które wpisy dodać do allow list?"`. Header: `"Allow list"`.

Cap the options at 4 (the tool's max). If you found more than 4 candidates, ship the 4 most useful ones (most frequently used, broadest impact); mention the leftover in your final confirm line ("plus zostały: X, Y — uruchom /g-allow-add jeszcze raz jeśli chcesz").

If you found **zero** new candidates (all already present), don't ask — just say so in one line and stop. Don't fire an empty popup.

### 5. Edit the tmpl

For each selected entry:
- Use the `Edit` tool with a unique anchor line nearby. Don't rewrite blocks.
- Match the indentation of surrounding lines (6 spaces).
- Match the surrounding block's pattern style (space vs colon) so the file stays consistent in each section.
- If the candidate is part of an obvious family (e.g. another `chezmoi` subcommand, another debug tool), insert near siblings.

### 6. Apply

```
chezmoi apply ~/.claude/settings.json
```

If it errors (most likely cause: malformed JSON) — show the error verbatim, stop, ask Greg before retrying. Don't `--force` anything.

### 7. Confirm in one line

Format: `Dodane: A, B, C. Apply przeszło — następne wywołania nie zapytają.`

Stop. No recap, no "let me know if...", no per-entry summary (already shown in the question).

## What NOT to add

- Anything the hook hard-denies — adding to allow won't help, hook wins.
- One-off commands unlikely to repeat. Only add patterns that will be used again.
- Anything overlapping an existing entry in **either** syntax style.
- Mode-gated stuff Greg already configured: if he's in `auto` mode the popups don't fire anyway. Mention it in the confirm line if relevant; don't add redundant rules.

## Edge cases

- **Tmpl contains handlebars** (`{{ .chezmoi.homeDir }}`) — don't break them. Use small targeted edits.
- **JSON validity** — if nervous, preview with `chezmoi execute-template < ~/Code/dotfiles/dot_claude/settings.json.tmpl | jq .` before applying.
- **Greg deselects everything** in the AskUserQuestion popup → he changed his mind, just say "OK, nic nie dodaję" and stop.
- **Apply errors** — show error verbatim, don't proceed. Almost always: a trailing comma or unescaped quote.
