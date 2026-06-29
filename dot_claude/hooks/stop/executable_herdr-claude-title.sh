#!/usr/bin/env bash
# Claude Code Stop hook — name the herdr tab after the live conversation topic.
#
# Claude writes {"type":"ai-title","aiTitle":"…"} into the transcript shortly
# after the first prompt and re-generates it as the session evolves. We read the
# latest aiTitle and rename the current herdr tab to "<claude-icon> <title>"
# (matches the icon work.nu uses for the claude tab). herdr port of the old
# tmux-session/tmux-window.sh NAME effect — colour mirroring dropped (herdr's
# sidebar carries agent status now).
#
# Idempotent, non-blocking. Only renames once a title exists, so the tab keeps
# its "claude" label until the first turn finishes.
set -u

# Need a herdr tab to rename + jq to read the transcript.
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_TAB_ID:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"
HERDR_BIN="${HERDR_BIN:-herdr}"
command -v "$HERDR_BIN" >/dev/null 2>&1 || HERDR_BIN=/opt/homebrew/bin/herdr
command -v "$HERDR_BIN" >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || true)
transcript=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

title=$(grep '"type":"ai-title"' "$transcript" 2>/dev/null | tail -1 \
          | jq -r '.aiTitle // empty' 2>/dev/null)
[ -n "$title" ] || exit 0

# Trim to keep the tab strip scannable. Tune via CLAUDE_HERDR_TITLE_MAX.
max="${CLAUDE_HERDR_TITLE_MAX:-22}"
if [ "${#title}" -gt "$max" ]; then title="${title:0:$((max - 1))}…"; fi

# nf-md-robot (U+F06A9) — same icon work.nu gives the claude tab.
icon=$(printf '\xf3\xb0\x9a\xa9')
"$HERDR_BIN" tab rename "$HERDR_TAB_ID" "${icon}  ${title}" >/dev/null 2>&1 || true

exit 0
