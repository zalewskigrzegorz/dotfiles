---
paths:
  - "dot_config/nushell/**"
  - "bin/**/*.nu"
---

# Nushell autoload gotchas (`dot_config/nushell/autoload/`)

Three of these cost a debug loop each while writing `firefly.nu` (nu 0.115.1):

- **`$nu.home-path` does not exist** — use `$env.HOME`. `$nu` has no home field.
- **`mktemp -d -t <name>` needs an `-XXXXXX` suffix in the template**, e.g. `mktemp -d -t "firefly-import-XXXXXX"`.
- **Watch string interpolation around `(ansi …)`** — `print $"...(ansi green)..."` parses the parenthesised call, so any stray parenthesis in the literal breaks the whole string.
- **A newly added autoload file does not load in an already-open session.** `bin/sync` copies it, but you need a fresh terminal (or `source` it by hand) before the command exists.
- **`env.nu` is a template**: edit `dot_config/nushell/env.nu.tmpl`. A per-process env flag (a renderer flag) goes there, never into `settings.json`.
- **`open --raw` for env and log files**: plain `open` parses by extension and mangles or errors on `.env`/`.log` (7b03e066).
- **A multi-line external call inside a closure needs `( … )`**, or the parser ends the call at the first newline (7b03e066).
- **Check a script with `nu --ide-check 10 <file>`** before telling Greg it works (7b03e066).
- Interactive pickers inside a command: `input list --multi` works and is the house pattern (see `firefly.nu`).
- **Test the `pay-respects` wrapper in `noconfirm` mode from a throwaway dir in the scratchpad.** `noconfirm` really applies the suggestion (it once created an empty `/private/tmp/.git`, then `not a git repository` and `dubious ownership` errors). `inline` is safe.
