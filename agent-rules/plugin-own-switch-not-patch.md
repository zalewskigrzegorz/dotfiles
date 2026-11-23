---
description: Change a third-party plugin's behaviour through its own switch, never by patching its cached files
alwaysApply: true
---

# A Plugin Is Changed Through Its Own Switch

Asked to turn the ponytail band buttons off, a session patched `register.tsx` in the plugin cache plus a re-patch script; Greg: "można to wyłączyć, nie trzeba usuwać" (a0134a23). A patch dies on the next update.

- **"Hide / disable part of a plugin" → find its switch first**: slash-command args, a flag file, an env var (`rg -i 'off|disable|hide'` over its `README`, `commands/`, `skills/`). Use it and track its state file in dotfiles with `chezmoi add`.
- **No switch** → "plugin nie ma przełącznika" in one line, files untouched.
- **Patching `~/.claude/plugins/**`** or adding a patch script needs his explicit "zmień kod pluginu".
