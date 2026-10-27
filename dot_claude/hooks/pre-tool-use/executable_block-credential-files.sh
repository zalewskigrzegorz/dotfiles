#!/bin/bash
# block-credential-files — deny Bash commands that would print a credential
# store into the transcript (and, via the session hook, into MemPalace).
#
# 2026-09-27: `cat ~/.npmrc | grep -i registry` printed `_authToken=…` while
# looking for the registry URL. The token had to be rotated. This guard fires
# on any read of a known credential file and points at the safe form.
#
# Deliberately NOT bypassed by the YOLO marker: YOLO removes review gates on
# Greg's own actions, this one protects a secret from leaving the machine in a
# log, which he never asked for. Deny wins over the yolo-allow catch-all.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# One-off secrets Greg typed through `secret-in` live in <scratchpad>/secrets/
# (ops-traps.md, "A secret goes in through Greg"). The agent hands them on, never reads them.
SECRETS='/scratchpad/secrets/'
SECRET_WHY="Files under ${SECRETS} hold a secret Greg typed for a consumer, not for you. Hand it on without printing it: \`VAR=\"\$(< <path>)\" <cmd>\` or \`<cmd> < <path>\` (ops-traps.md)."
PATH_ARG=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)
case "$PATH_ARG" in *"$SECRETS"*) deny "$SECRET_WHY" ;; esac

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -n "$COMMAND" ] || exit 0

# shortcut: catches accidental reads (cat, Read, echo "$(< f)"), not an agent set on leaking; that needs a sandbox.
if printf '%s' "$COMMAND" | grep -qF "$SECRETS"; then
  P="[\"']?[^[:space:]\"']*${SECRETS}[^[:space:]\"';|&)]*"
  READ_CMD='(^|[;&|(][[:space:]]*)(cat|bat|less|more|head|tail|rg|grep|ugrep|sed|awk|strings|xxd|od|jq|base64|tee)[[:space:]]'
  printf '%s' "$COMMAND" | grep -qE "${READ_CMD}[^;&|]*<[[:space:]]*${P}" && deny "$SECRET_WHY"
  rest=$(printf '%s' "$COMMAND" | sed -E \
    -e "s#[A-Za-z_][A-Za-z0-9_]*=\"?\\\$\\(<[[:space:]]*${P}##g" \
    -e "s#(^|[^(])<[[:space:]]*${P}#\\1#g" \
    -e "s#(secret-in|test -[esf]|rm( -f)?|-o|--out-file)[[:space:]=]+${P}##g")
  printf '%s' "$rest" | grep -qF "$SECRETS" && deny "$SECRET_WHY"
fi

# macOS `ps -e` / `-E` / BSD `ps e…` print every same-user process's environment.
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|(][[:space:]]*)ps[[:space:]]+(-[A-Za-z]*[eE]|[A-Za-z]*[eE])'; then
  deny "\`ps\` with e/E prints other processes' environment, secrets included. Use \`ps -axo pid,etime,command\`."
fi

# `op read` whose stdout reaches the transcript. Allowed: `x=\$(op read …)`, `op read … | consumer`, `-o file`, `> file`.
seg=$(printf '%s' "$COMMAND" | grep -oE '(^|[;&][[:space:]]*)((timeout[[:space:]]+[0-9]+|env([[:space:]]+-u[[:space:]]+[A-Za-z_]+)*)[[:space:]]+)*op[[:space:]]+read[[:space:]][^|;&>]*($|[;&])' || true)
if [ -n "$seg" ] && ! printf '%s' "$seg" | grep -qE '[[:space:]](-o|--out-file)([[:space:]=]|$)'; then
  deny "\`op read\` would print the secret into the transcript. Hand it on: \`VAR=\"\$(op read …)\" <cmd>\`, \`op read … | <cmd>\`, \`op run --env-file <refs> -- <cmd>\`, or check it with \`op read … | wc -c\`."
fi

# Files whose whole point is a secret. Path fragments, matched anywhere in the command.
FILES='(~|\$HOME|/Users/[^/ ]+)/(\.npmrc|\.netrc|\.pypirc|\.git-credentials|\.config/gh/hosts\.yml|\.docker/config\.json|\.aws/credentials|\.kube/config|\.ssh/id_[a-z0-9]+)([^a-zA-Z0-9_./-]|$)|(^|[[:space:]/])\.npmrc([^a-zA-Z0-9_./-]|$)'
READERS='(^|[;&|(][[:space:]]*|[[:space:]])(cat|bat|less|more|head|tail|rg|grep|ugrep|ag|ack|sed|awk|strings|xxd|od|python3?|node|jq|yq|source|\.)[[:space:]]'

# A command that redacts on the way out (contains the `***` marker) is the sanctioned form.
if printf '%s' "$COMMAND" | grep -qE "$FILES" && printf '%s' "$COMMAND" | grep -qE "$READERS" && ! printf '%s' "$COMMAND" | grep -qF '***'; then
  deny "Reading a credential file would print its token into the transcript. Use the value-free form: \`npm config get registry\`, \`gh auth status\`, \`docker system info\`, or redact: \`sed -E 's/(_authToken=|password[=:]\s*).*/\\1***/' <file>\`."
fi
exit 0
