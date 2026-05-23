# Aerospace per-monitor gaps

`outer.top` must be ≥ sketchybar `bar.height + small margin`. If it's smaller, focused windows mount under the bar and the top line of any TUI (Claude Code banner, nvim status, lazygit header) gets clipped.

## Formula

```
outer.top = bar.height + 4
```

Current `bar.height` is `36` (see `dot_config/sketchybar/settings.lua`). Therefore: `outer.top = 40`.

If `bar.height` ever changes, update `outer.top` for every monitor in lockstep.

## Per-monitor tuning

Each monitor renders slightly differently because of physical pixel density and macOS HiDPI scaling. Some displays need 1–2 extra px. Tune at desk:

1. With a TUI running fullscreen on the target display, increment `outer.top` by 2 until the first line is no longer clipped AND there's no visible empty strip between the bar and the window.
2. Note the value per monitor in `aerospace.toml`.
3. If multiple monitors share a model (e.g. dual DELL U3225QE), use the same value.

## Current values (2026-05-23)

| Monitor | outer.top | Notes |
|---|---|---|
| Built-in (MacBook display) | 40 | tune-at-desk |
| DELL U3225QE (external) | 40 | tune-at-desk |
| C34H89x (Samsung ultrawide) | 40 | tune-at-desk |
| fallback | 40 | new monitors inherit |

Update this table when retuning. Re-apply via `chezmoi apply` to propagate.
