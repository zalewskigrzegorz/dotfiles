---
paths:
  - "**/*.tmpl"
  - ".chezmoitemplates/**"
---

# Re-syncing live → `.tmpl`

When the source is a `.tmpl`, live drifted and live is the truth, `chezmoi re-add` is a no-op: rewrite by hand.

1. Inventory every `{{ ... }}` token in the template first (`.chezmoi.*`, `if eq .chezmoi.os` branches, `includeTemplate`, secret functions).
2. Copy live in verbatim, put each token back.
3. Verify byte-identity: `bin/render-and-diff <source.tmpl>` (0 = match, 1 = diff, 2 = bad invocation).
4. Render the *other* OS branch in your head before committing; nothing checks it.

Decide once whether live or the template is canonical and stop oscillating.
