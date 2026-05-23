# Mocha Neon glyph atlas

Single source of truth for every nerd-font / unicode codepoint used across
the Mocha Neon stack (statusline, tmux, sketchybar, starship, nu prompt).
Pair with `docs/mocha-neon-palette.md` (which is the color SOT).

When swapping a glyph: edit ALL referenced files in lockstep. The "Where used"
column is the punch list.

## Convention

- Prefer the `nf-md-*` (Material Design Icons) family for category-wide UI
  glyphs — uniform bbox, large coverage, ~7000+ glyphs.
- Cyber-skull / unicorn-variant (`U+F14C8` / `U+F15C3`) are the **Mocha Neon
  signature glyphs** for prefix-active / prefix-idle / "this is our stack".
- Emoji ONLY when nerd-font lacks a clean equivalent (e.g. `⚡` for power).
- No multi-color emoji as primary signal — they fight the Mocha Neon palette.

## Signature glyphs

| Role | Glyph | Codepoint | Nerd-font name | Where used |
|---|---|---|---|---|
| Prefix-idle (Mocha Neon mascot) | `󱗃` | U+F15C3 | nf-md-unicorn-variant | `tmux.conf` status-left (idle), `starship.toml` `[character]` success_symbol |
| Prefix-active / service mode | `󱓈` | U+F14C8 | nf-md-skull-scan-outline | `tmux.conf` status-left (`client_prefix` ON) |
| AI / claude-sessions | `󰧑` | U+F0675 | nf-md-creation | sketchybar `widgets/claude_sessions.lua` (icon) |

## Per-surface glyphs

### Statusline (`dot_claude/executable_statusline.sh`)

| Segment | Glyph | Codepoint | Nerd-font name |
|---|---|---|---|
| `tool_seg` (tool-call counter) | `󰣖` | U+F08D6 | nf-md-hammer-wrench |
| `comp_seg` (compaction counter) | `󰑨` | U+F0468 | nf-md-recycle |
| `wait_seg` (waiting badge) | `󰂚` | U+F00A9 | nf-md-bell |

### tmux (`dot_config/tmux/tmux.conf`)

| Segment | Glyph | Codepoint | Nerd-font name |
|---|---|---|---|
| `status-left` prefix-active | `󱓈` | U+F14C8 | nf-md-skull-scan-outline |
| `status-left` prefix-idle | `󱗃` | U+F15C3 | nf-md-unicorn-variant |
| `status-right` session label | `󱎫` | U+F14CB | nf-md-clock-time-eight |
| `status-right` week label | `󰸗` | U+F0E37 | nf-md-calendar-week |
| reload banner / `display-message` | `󱗃` | U+F15C3 | nf-md-unicorn-variant |

### Sketchybar — workspace icons (`dot_config/sketchybar/items/spaces.lua`)

| Workspace | Glyph | Codepoint | Nerd-font name |
|---|---|---|---|
| chat | `󰭻` | U+F0B7B | nf-md-chat |
| web | `󰖟` | U+F059F | nf-md-web |
| term | `󰆍` | U+F018D | nf-md-console-line |
| code | `` | U+E796 | nf-dev-code_badge / similar |
| media | `󰝚` | U+F075A | nf-md-music |
| test | `󰙨` | U+F0668 | nf-md-test-tube |
| misc | `󰉋` | U+F024B | nf-md-folder |
| notes | `󰂺` | U+F00BA | nf-md-book-open-page-variant |
| mail | `󰇮` | U+F01EE | nf-md-email |
| mac | `󰍹` | U+F0379 | nf-md-monitor |

### Sketchybar — claude_sessions widget

| State | Glyph | Codepoint | Nerd-font name |
|---|---|---|---|
| Always | `󰧑` | U+F0675 | nf-md-creation (sparkle) |

### Sketchybar — apple item (kindavim mode)

Driven by `sketchybar-watcher` Go binary. State glyphs:

| State | Glyph | Note |
|---|---|---|
| Default | `🦄` | unicorn emoji (rendered via Iosevka emoji fallback) |
| Service mode | `💀` | skull emoji |
| Vim N | `N` | letter — set by watcher in `main.go` |
| Vim V | `V` | letter |
| Vim C | `C` | letter |
| Vim R | `R` | letter |

(See `bin/sketchybar-watcher/main.go` ~line 434 for the switch.)

### Starship (`dot_config/starship/starship.toml`)

| Module | Glyph | Codepoint | Nerd-font name |
|---|---|---|---|
| `[character]` success_symbol | `󱗃` | U+F15C3 | nf-md-unicorn-variant |
| `[character]` error_symbol | `🚨` | U+1F6A8 | emoji rotating-light |
| `[custom.claude_sessions]` format | `🔗` | U+1F517 | emoji link |

### Nushell vi-mode (`dot_config/nushell/autoload/starship.nu`)

| Mode | Glyph | Codepoint | Nerd-font name / Note |
|---|---|---|---|
| Insert (`PROMPT_INDICATOR_VI_INSERT`) | `❯` | U+276F | Heavy right-pointing angle bracket |
| Normal (`PROMPT_INDICATOR_VI_NORMAL`) | `⚡` | U+26A1 | High voltage / zap (gold #FFD700) |

> nu/reedline doesn't expose VISUAL / REPLACE prompt indicators — see
> polish brainstorm for upstream PR + local-hack workarounds.

### Window wrappers (`dot_config/nushell/autoload/zz-tmux-window-wrappers.nu`)

Spawn each TUI in its own tmux window labelled with this glyph + name:

| Command | Glyph | Codepoint | Nerd-font name |
|---|---|---|---|
| `nvim` / `vim` / `vi` | `` | U+E62B | nf-custom-vim |
| `claude` | `󰣙` | U+F08D9 (or whatever) | nf-md-robot (verify in source) |
| `lazygit` | `` | U+E725 | nf-dev-git_branch |
| `gh-dash` | `󰊤` | U+F02A4 | nf-md-github |
| `lazydocker` | `󰡨` | U+F0868 | nf-md-docker |
| `btop` | `` | U+F0E4 | nf-fa-tachometer |

(See `dot_config/nushell/autoload/zz-tmux-window-wrappers.nu` for exact `\u{xxxx}`
escapes — those survive every edit; literal glyphs in source have been silently
stripped before.)

## Codepoint lookup tips

- nerd-fonts.com → search by name (`md-clock`, `md-calendar-week`).
- `bin/glyph-test` (if it exists) — render a codepoint live in your terminal.
- Iosevka Nerd Font Mono coverage report: see `~/Library/Fonts/`.

## Adding a new glyph

1. Pick from `nf-md-*` if possible (uniform sizing).
2. Verify it renders in **Iosevka Nerd Font Mono** (the dotfiles font).
3. Add to the relevant per-surface section here.
4. Reference by **`\u{xxxxx}` escape** in source where possible
   (`zz-tmux-window-wrappers.nu` and Go code do this; tmux.conf and Lua use
   literal glyphs because they're rendered through static config files).
5. Re-shoot screenshots in `~/Code/personal/bazgroly/dotfiles/screenshots/`.
