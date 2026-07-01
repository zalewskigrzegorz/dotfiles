#!/usr/bin/env bash
# Claude Code Stop + UserPromptSubmit hook — name the herdr tab after the live
# conversation topic.
#
# Claude writes {"type":"ai-title","aiTitle":"…"} into the transcript shortly
# after the first prompt and re-generates it as the session evolves. We read the
# latest aiTitle and rename the current herdr tab to "<claude-icon> <title>"
# (matches the icon work.nu uses for the claude tab). herdr port of the old
# tmux-session/tmux-window.sh NAME effect — colour mirroring dropped (herdr
# 0.7.x has no tab/pane colour CLI; its sidebar carries agent status instead).
#
# Wired to BOTH events so a fresh agent's tab updates immediately:
#   * UserPromptSubmit fires before the turn → renames on the first prompt,
#     falling back to the prompt text until an aiTitle exists (otherwise a new
#     agent shows the *previous* session's stale tab label until its first Stop).
#   * Stop keeps the tab in sync with the regenerated aiTitle as the topic drifts.
#
# Idempotent, non-blocking.
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

# No aiTitle yet (brand-new agent, first prompt) — fall back to the submitted
# prompt so the tab reflects the current agent instead of the stale prior label.
# UserPromptSubmit input carries `.prompt`; Stop input doesn't, so this is a
# no-op there. Strip leading slash-command / control markup and whitespace.
if [ -z "$title" ]; then
  title=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null \
            | sed -e 's/^<command-name>[^<]*<\/command-name>[[:space:]]*//' \
                  -e 's/<[^>]*>//g' -e 's/^[[:space:]>›]*//' \
            | tr '\n' ' ' | sed -e 's/[[:space:]]\{2,\}/ /g' -e 's/[[:space:]]*$//')
fi
[ -n "$title" ] || exit 0

# Trim to keep the tab strip scannable. Tune via CLAUDE_HERDR_TITLE_MAX.
max="${CLAUDE_HERDR_TITLE_MAX:-22}"
if [ "${#title}" -gt "$max" ]; then title="${title:0:$((max - 1))}…"; fi

# nf-md-robot (U+F06A9) — same icon work.nu gives the claude tab.
icon=$(printf '\xf3\xb0\x9a\xa9')
"$HERDR_BIN" tab rename "$HERDR_TAB_ID" "${icon}  ${title}" >/dev/null 2>&1 || true

exit 0
