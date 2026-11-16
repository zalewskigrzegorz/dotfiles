---
paths:
  - "dot_config/nushell/**"
---

# Nushell autoload gotchas (`dot_config/nushell/autoload/`)

Three of these cost a debug loop each while writing `firefly.nu` (nu 0.115.1):

- **`$nu.home-path` does not exist** — use `$env.HOME`. `$nu` has no home field.
- **`mktemp -d -t <name>` needs an `-XXXXXX` suffix in the template**, e.g. `mktemp -d -t "firefly-import-XXXXXX"`.
- **Watch string interpolation around `(ansi …)`** — `print $"...(ansi green)..."` parses the parenthesised call, so any stray parenthesis in the literal breaks the whole string.
- **A newly added autoload file does not load in an already-open session.** `bin/sync` copies it, but you need a fresh terminal (or `source` it by hand) before the command exists.
- **`env.nu` is a template**: edit `dot_config/nushell/env.nu.tmpl`. A per-process env flag (a renderer flag) goes there, never into `settings.json`.
- Interactive pickers inside a command: `input list --multi` works and is the house pattern (see `firefly.nu`).
- **Test the `pay-respects` wrapper in `noconfirm` mode from a throwaway dir in the scratchpad.** `noconfirm` really applies the suggestion (it once created an empty `/private/tmp/.git`, then `not a git repository` and `dubious ownership` errors). `inline` is safe.
