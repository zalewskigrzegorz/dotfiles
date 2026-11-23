---
description: Scan the conversation for Bash/MCP calls that hit a permission prompt, propose the widest safe allowlist patterns in a popup, then edit .chezmoitemplates/claude-settings.json and chezmoi apply so they take effect live. Explicit-invoke command.
---

# g-allow-add

Batch allowlist additions in one round-trip instead of Greg hand-editing the settings.

## Where

`~/Code/dotfiles/.chezmoitemplates/claude-settings.json`, `permissions.allow` (flat string array). Never edit live `~/.claude/settings.json`. After editing: `chezmoi apply ~/.claude/settings.json` (re-read on the next tool call, no restart).

## Why wide is safe

`~/.claude/hooks/pre-tool-use/block-dangerous-commands.sh` denies `sudo`, `gh pr merge`, protected-branch pushes, publish, `DROP`/`TRUNCATE`/unscoped `DELETE`, `rm -rf` on `/ ~ $HOME` or system dirs, `curl | sh`, `mkfs`, `dd of=/dev/…`; and asks for any `rm`, force push, `chmod 777`, HTTP writes, dep installs, `reset --hard`, `clean -f`, PR create/edit. So prefer **one wide entry** (`Bash(sqlite3 *)`, `Bash(docker *)`): the hook is the policy layer, allow is convenience.

## Two pattern styles coexist

Space-glob `Bash(ls *)` and colon `Bash(grep:*)`. Dedupe against both: `grep -nE 'Bash\((cmd)[ :]' <tmpl>`. New entries match their block's style (space ~lines 21–110, colon ~178–200). Other kinds: `Read(/path/**)`, `Edit(…)`, `Write(…)`, `WebFetch`, `WebSearch`, `Skill(<name>)`, `mcp__server__tool`.

## Workflow

1. **Scan** the conversation: commands that ran after an approved popup, `<bash-input>` blocks Greg ran himself, complaints ("znowu pyta", "stop pytać"), permission-mode reminders, repeated MCP tools not yet allowed.
2. **Drop** candidates already present in either style, silently.
3. **Widen:** read-only families (`list`, `get`, `show`, `view`, `query`…) go wide; mixed tools go wide only if the hook covers the dangerous variants.
4. **Ask** one `AskUserQuestion`, `multiSelect: true`, header "Allow list", question like "Które wpisy dodać do allow list?"; label = the exact pattern, description = what it unblocks and what catches the dangerous case. Max 4: the most useful; name the rest in the final line. Zero candidates → one line, no popup. Nothing selected → "OK, nic nie dodaję".
5. **Edit** with `Edit` on a unique anchor, 6-space indent, near siblings, block's style. Keep `{{ … }}` intact; if unsure, `chezmoi execute-template < <tmpl> | jq .`.
6. **Apply**; an error (usually a trailing comma or quote) is shown verbatim, then stop and ask. Never `--force`.
7. **One line:** `Dodane: A, B, C. Apply przeszło — następne wywołania nie zapytają.` No recap.

Never add: what the hook hard-denies, one-off commands, overlaps in either style, rules made moot by Greg's auto mode (mention it instead).
