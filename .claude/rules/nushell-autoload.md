---
paths:
  - "dot_config/nushell/**"
  - "bin/**/*.nu"
---

# Nushell autoload gotchas (`dot_config/nushell/autoload/`, nu 0.115.1)

- **`$nu.home-path` does not exist** — use `$env.HOME`.
- **`mktemp -d -t <name>` needs an `-XXXXXX` suffix**, e.g. `mktemp -d -t "firefly-import-XXXXXX"`.
- **`print $"...(ansi green)..."` parses the parenthesised call**, so a stray parenthesis in the literal breaks the whole string.
- **A new autoload file doesn't load in an open session.** `bin/sync` copies it; open a fresh terminal or `source` it.
- **`env.nu` is a template**: edit `dot_config/nushell/env.nu.tmpl` (per-process env flags go there, see `dotfiles-ops.md`).
- **`open --raw` for env and log files**: plain `open` parses by extension and mangles `.env`/`.log` (7b03e066).
- **A multi-line external call inside a closure needs `( … )`**, or the call ends at the first newline.
- **Check a script with `nu --ide-check 10 <file>`** before telling Greg it works.
- Interactive pickers: `input list --multi` is the house pattern (`firefly.nu`).
- **Test the `pay-respects` wrapper in `noconfirm` mode from a throwaway scratchpad dir**: `noconfirm` applies the suggestion (it once created an empty `/private/tmp/.git`). `inline` is safe.

## History

- **`Ctrl+R` = fzf** over the sqlite history (`autoload/fzf-history.nu`). `Alt+T` = Television smart-autocomplete (`tv.nu`). TV's `nu-history` channel is **not** wired to Ctrl+R: its filtering is too weak.
- **No Atuin** until [atuinsh/atuin#2900](https://github.com/atuinsh/atuin/issues/2900) (executehostcommand pastes literal text) and [#2820](https://github.com/atuinsh/atuin/issues/2820) (nu integration broken) close; re-verify with `gh issue view` before recommending.
