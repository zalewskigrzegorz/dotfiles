#!/usr/bin/env bash
# render.sh <markdown file> <outdir> — GitHub-rendered HEAD and working-tree
# versions side by side in <outdir>/index.html. Relative images resolve through
# the <outdir>/repo symlink to the file's directory (working-tree images for both
# columns: shortcut, a changed image shows only its new version).
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: render.sh <file.md> <outdir>" >&2; exit 2; }
file=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
out=$2
[ -f "$file" ] || { echo "no such file: $1" >&2; exit 1; }
top=$(git -C "$(dirname "$file")" rev-parse --show-toplevel)
rel=${file#"$top"/}
ctx=$(cd "$top" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
mkdir -p "$out"
ln -sfn "$(dirname "$file")" "$out/repo"

render() {  # markdown on stdin → GitHub HTML on stdout
  jq -Rs --arg c "$ctx" 'if $c == "" then {text: ., mode: "markdown"} else {text: ., mode: "gfm", context: $c} end' \
    | gh api markdown --input -
}
head_html=$(git -C "$top" show "HEAD:$rel" 2>/dev/null | render) || head_html="<p><em>not in HEAD (new file)</em></p>"
wt_html=$(render < "$file")
[ -n "$wt_html" ] || { echo "gh api markdown returned nothing" >&2; exit 1; }

cat > "$out/index.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><title>README preview: $rel</title>
<base href="repo/">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/github-markdown-css@5.8.1/github-markdown.min.css">
<style>body{margin:0;display:grid;grid-template-columns:1fr 1fr;gap:16px;padding:16px}
h6.col{font:600 13px system-ui;margin:0 0 8px;color:#888}.markdown-body{padding:16px;border:1px solid #8884;border-radius:6px}</style>
</head><body>
<section><h6 class="col">HEAD</h6><article class="markdown-body">$head_html</article></section>
<section><h6 class="col">working tree</h6><article class="markdown-body" id="wt">$wt_html</article></section>
</body></html>
HTML
echo "$out/index.html"
