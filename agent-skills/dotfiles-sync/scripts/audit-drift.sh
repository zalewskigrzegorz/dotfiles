#!/usr/bin/env bash
# Compact, classified summary of chezmoi drift — saves tokens vs. having
# Claude read the full `chezmoi diff` and reason about every entry.
#
# For each drifted path, emits one line:
#   PATH | KIND | SUGGESTED_ACTION
#
# Kinds:
#   FILE_DRIFT       — real drift, plain file. Re-add or apply.
#   TEMPLATE_DRIFT   — real drift, source is .tmpl. `chezmoi re-add` may
#                      leave the template untouched if it still renders
#                      to the live content (e.g. Claude Code reformatted
#                      JSON). Manual rewrite + render-and-diff verify.
#   BINARY_DRIFT     — real drift, binary file. Re-add but watch exec bit
#                      (`chezmoi re-add` can drop it if source lacks the
#                      `executable_` prefix).
#   FAKE_SCRIPT      — chezmoi `run_*` script. Always shows in `chezmoi
#                      diff` because it runs on every apply. Not real
#                      drift; nothing to capture.
#
# Exit 0 always (informational tool).

set -euo pipefail

source_dir="$(chezmoi source-path)"
diff_output="$(chezmoi diff 2>&1 || true)"

if [[ -z "$diff_output" ]]; then
  echo "No drift."
  exit 0
fi

paths="$(echo "$diff_output" \
  | grep -E '^diff --git a/' \
  | sed -E 's|^diff --git a/||; s| b/.*$||' \
  | sort -u)"

if [[ -z "$paths" ]]; then
  echo "No drift entries parsed."
  exit 0
fi

# Build set of script-managed targets (target name minus run_* prefix).
scripts_set="$(chezmoi managed --include scripts 2>/dev/null || true)"

printf "%-58s  %-16s  %s\n" "PATH" "KIND" "SUGGESTED_ACTION"
printf "%-58s  %-16s  %s\n" "----" "----" "----------------"

while IFS= read -r p; do
  [[ -z "$p" ]] && continue

  # Script?
  if grep -qxF -- "$p" <<<"$scripts_set" 2>/dev/null; then
    printf "%-58s  %-16s  %s\n" "$p" "FAKE_SCRIPT" "ignore — runs every apply"
    continue
  fi

  target="$HOME/$p"
  src=""
  # `chezmoi source-path` wants the target path; try it.
  src="$(chezmoi source-path "$target" 2>/dev/null || true)"

  if [[ -z "$src" ]]; then
    # Couldn't map — leave classified as plain drift.
    printf "%-58s  %-16s  %s\n" "$p" "FILE_DRIFT" "chezmoi re-add $target"
    continue
  fi

  if [[ "$src" == *.tmpl ]]; then
    printf "%-58s  %-16s  %s\n" "$p" "TEMPLATE_DRIFT" "see Template-aware re-sync in dotfiles-sync SKILL.md"
    continue
  fi

  # Binary?
  if [[ -f "$target" ]] && file "$target" 2>/dev/null | grep -qE 'executable|Mach-O|ELF'; then
    printf "%-58s  %-16s  %s\n" "$p" "BINARY_DRIFT" "chezmoi re-add $target  (verify exec bit after)"
    continue
  fi

  printf "%-58s  %-16s  %s\n" "$p" "FILE_DRIFT" "chezmoi re-add $target"
done <<<"$paths"
