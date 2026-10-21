---
description: Change a third-party plugin's behaviour through its own switch, never by patching its cached files
alwaysApply: true
---

# A Plugin Is Changed Through Its Own Switch

Greg asked to turn the ponytail band buttons off. The session patched
`register.tsx` in the plugin cache and added a `run_after_*` script to
re-patch it; Greg: "można to wyłączyć, nie trzeba usuwać", then "o to
chodziło, nie o ingerencję w kod" (a0134a23, reverted in a622edd). A patch
dies on the next plugin update and needs a script to resurrect it.

- **"Hide / disable part of a plugin" → look for its switch first**: slash
  command args, a flag file, an env var (`rg -i 'off|disable|hide'` over the
  plugin's `README`, `commands/`, `skills/`). Use it and track its state file
  in dotfiles with `chezmoi add`.
- **No switch** → say "plugin nie ma przełącznika" in one line and leave the
  files alone.
- **Patching `~/.claude/plugins/**`** or adding a patch script needs his
  explicit "zmień kod pluginu".
