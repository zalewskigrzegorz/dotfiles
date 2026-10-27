// tuios-worktree-new — open the `workctl` picker in the FOCUSED pane's repo.
//
// Bound to prefix+shift+g (new) and prefix+shift+o (switch, `--all`) as tuios
// command keys (`[[keybindings.command]]`, type "popup"). Both used to be
// separate herdr features with separate popups; they are the same picker now,
// differing only in whether other repos' worktrees are folded in.
//
// A tuios command key already starts in the focused pane's folder with a
// terminal, so all this adds over a bare `workctl` is the repo root and a
// silent no-op outside a git repo (gh-dash, a scratch shell): there is no repo
// to pick a branch in, and workctl's error would flash in a closing popup.

import { spawnSync } from "node:child_process";

function main(): number {
  const all = process.argv.slice(2).includes("--all");
  const top = spawnSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" });
  const root = top.status === 0 ? (top.stdout ?? "").trim() : "";
  if (root === "") return 0;
  const args = all ? ["--all", "--repo-path", root] : ["--repo-path", root];
  const r = spawnSync("workctl", args, { stdio: "inherit" });
  return r.status === null ? 1 : r.status;
}

process.exit(main());
