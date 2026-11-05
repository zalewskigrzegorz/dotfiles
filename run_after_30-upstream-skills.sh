#!/usr/bin/env bash
# Third-party skills that track upstream main, refreshed on every apply.
# Runs after 30-agent-skills-sync (same stage, name sorts later), whose
# rsync --delete would otherwise wipe them from ~/.claude/skills.
# Offline or a failed fetch keeps the copy already in place; never fails the apply.

set -u

# <owner/repo> <path of the skill dir inside the repo>
UPSTREAM=(
  "cloudflare/security-audit-skill skills/security-audit"
)

TARGET="${HOME}/.claude/skills"
mkdir -p "$TARGET"

for entry in "${UPSTREAM[@]}"; do
  read -r repo path <<<"$entry"
  name="${path##*/}"
  tmp="$(mktemp -d)"
  if curl -fsSL --max-time 30 "https://codeload.github.com/${repo}/tar.gz/refs/heads/main" \
      | tar -xz -C "$tmp" --strip-components=1 2>/dev/null \
      && [[ -f "$tmp/$path/SKILL.md" ]]; then
    rm -rf "${TARGET:?}/${name:?}"
    mv "$tmp/$path" "$TARGET/$name"
    echo "upstream skills: ${repo} → ${name} (main)"
  elif [[ -d "$TARGET/$name" ]]; then
    echo "upstream skills: fetch of ${repo} failed, keeping the old ${name}" >&2
  else
    echo "upstream skills: fetch of ${repo} failed, ${name} not installed" >&2
  fi
  rm -rf "${tmp:?}"
done
exit 0
