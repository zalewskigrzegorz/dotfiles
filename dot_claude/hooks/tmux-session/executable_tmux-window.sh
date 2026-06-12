#!/usr/bin/env bash
# Claude Code SessionStart + Stop hook — mirror the Claude session onto its
# tmux window so the window list stays readable across many parallel sessions.
#
# Two effects, both idempotent and non-blocking:
#   1) COLOR  — deterministic per-session accent (hash of session_id → fixed
#               Mocha Neon palette). Same repo+session ⇒ same colour, every
#               time. Applied on SessionStart so the window is coloured from
#               second one, re-applied on every Stop (cheap, stable).
#   2) NAME   — the live Claude session title. Claude writes
#               {"type":"ai-title","aiTitle":"…"} into the transcript shortly
#               after the first prompt and re-generates it as the session
#               evolves; we read the latest and rename the window to
#               "<robot-icon> <title>". Only runs once a title exists, so
#               SessionStart leaves the wrapper's "claude" name untouched
#               until the first turn finishes.
#
# Why a hook and not the statusline: the statusline is pure rendering; baking
# tmux side-effects into it is brittle. Stop fires exactly when aiTitle changes.
#
# Claude's own session COLOUR is intentionally NOT mirrored — it is not exposed
# anywhere (not in ~/.claude.json, not in the transcript, not as an OSC seq),
# so we derive our own instead.
set -u

# Outside tmux there is nothing to do. Claude inherits TMUX_PANE from the pane
# it was launched in, so the hook child sees it directly — no PID walking.
[ -n "${TMUX_PANE:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

TMUX_BIN="${TMUX_BIN:-/opt/homebrew/bin/tmux}"
command -v "$TMUX_BIN" >/dev/null 2>&1 || TMUX_BIN=tmux

INPUT=$(cat 2>/dev/null || true)
sid=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
transcript=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# ── 1) Colour ───────────────────────────────────────────────────────────────
# Mocha Neon accents (same hexes as the statusline). 8 distinct hues.
palette=(B347FF FF80BF 50FA7B FFD700 FF8C42 8BE9FD 9580FF FF6B9D)
if [ -n "$sid" ]; then
  h=$(printf '%s' "$sid" | cksum | cut -d' ' -f1)
  hex=${palette[$(( h % ${#palette[@]} ))]}
  "$TMUX_BIN" set-window-option -t "$TMUX_PANE" window-status-style "fg=#${hex}" 2>/dev/null || true
  "$TMUX_BIN" set-window-option -t "$TMUX_PANE" window-status-current-style "fg=#${hex},bold" 2>/dev/null || true
fi

# ── 2) Name ─────────────────────────────────────────────────────────────────
# nf-md-robot (U+F06A9) — kept in sync with zz-tmux-window-wrappers.nu.
icon=$(printf '\xf3\xb0\x9a\xa9')
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  title=$(grep '"type":"ai-title"' "$transcript" 2>/dev/null | tail -1 \
            | jq -r '.aiTitle // empty' 2>/dev/null)
  if [ -n "$title" ]; then
    # Trim to keep the window list scannable — long aiTitles otherwise eat
    # half the tmux status bar. Tune via CLAUDE_TMUX_TITLE_MAX.
    max="${CLAUDE_TMUX_TITLE_MAX:-16}"
    if [ "${#title}" -gt "$max" ]; then title="${title:0:$((max - 1))}…"; fi
    # Safety: if this window was started outside the wrapper, automatic-rename
    # could be on and would clobber us with pane_title on the next refresh.
    "$TMUX_BIN" set-window-option -t "$TMUX_PANE" automatic-rename off 2>/dev/null || true
    "$TMUX_BIN" rename-window -t "$TMUX_PANE" "${icon}  ${title}" 2>/dev/null || true
  fi
fi

exit 0
