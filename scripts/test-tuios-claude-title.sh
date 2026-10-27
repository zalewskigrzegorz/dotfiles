#!/usr/bin/env bash
# Self-check for dot_claude/hooks/stop/executable_tuios-claude-title.sh: when it
# asks Haiku, and that it never overwrites a title the agent set. A fake
# `claude` stands in for Haiku; nothing leaves the machine, no tuios calls.
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
hook="$repo/dot_claude/hooks/stop/executable_tuios-claude-title.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/os-title-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/state"
cat > "$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo x >> "$FAKE_CALLS"
printf '%s\n' "$FAKE_OUT"
EOF
chmod +x "$tmp/bin/claude"
ln -s "$repo/bin/os-title" "$tmp/bin/os-title"

export PATH="$tmp/bin:$PATH" XDG_STATE_HOME="$tmp/state" FAKE_CALLS="$tmp/calls" TUIOS_ENV=0
sid=test-session
t="$tmp/transcript.jsonl"
store="$tmp/state/dotfiles/claude-session-title/$sid"
fail=0

prompts() { for _ in $(seq "$1"); do
  printf '{"type":"user","message":{"content":"prośba"}}\n{"type":"assistant","message":{"content":[{"type":"text","text":"ok"}]}}\n' >> "$t"
done; }
stop() {
  FAKE_OUT="$1" bash "$hook" <<< "{\"session_id\":\"$sid\",\"hook_event_name\":\"Stop\",\"transcript_path\":\"$t\"}"
  # The hook backgrounds its work and a throttled run leaves no trace to poll,
  # so give it a fixed window; the fake answers at once.
  perl -e 'select(undef,undef,undef,1.5)'
}
check() {
  local calls; calls=$( [ -f "$FAKE_CALLS" ] && wc -l < "$FAKE_CALLS" | tr -d ' ' || echo 0)
  if [ "$calls" = "$2" ] && [ "$(cat "$store" 2>/dev/null)" = "$3" ]; then echo "ok   $1"
  else echo "FAIL $1: calls=$calls (want $2), title='$(cat "$store" 2>/dev/null)' (want '$3')"; fail=1; fi
}

prompts 1; stop "Test tytuł";             check "first answer gets a title"        1 "Test tytuł"
prompts 1; stop "Inny";                   check "1 new prompt: no call"            1 "Test tytuł"
prompts 2; stop "Nowy tytuł";             check "3 new prompts: retitled"          2 "Nowy tytuł"
prompts 3; stop "Zostaw, pasuje";         check "keep answer in any case"          3 "Nowy tytuł"
printf 'Tytuł agenta' > "$store"
prompts 3; stop "Nadpisany";              check "agent's own title is kept"        3 "Tytuł agenta"

exit "$fail"
