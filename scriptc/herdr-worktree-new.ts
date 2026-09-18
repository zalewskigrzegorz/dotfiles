// herdr-worktree-new — open the `workctl` picker in the FOCUSED repo.
//
// Bound to prefix+shift+g (new) and prefix+shift+o (switch, `--all`) in
// dot_config/herdr/config.toml.tmpl. Both used to be separate herdr features
// with separate popups; they are the same picker now, differing only in whether
// other repos' worktrees are folded in.
//
// Why a script at all: a herdr keybinding command runs on the SERVER, not in a
// pane, so it has no cwd and no terminal. It has to ask which workspace is
// focused, open a tab in that repo, and run the picker there.
//
// (herdr 0.7.1's own new-worktree popup always targeted ws_idx=1 instead of the
// focused workspace, so checkouts landed under the wrong repo. That is why the
// native binding was disabled in the first place; the picker also has to live
// in a pane to draw at all.)
//
// Ported from bash: the old version shelled out to python3 twice just to pluck
// two fields out of herdr's JSON, so a machine without python3 got a keybinding
// that silently did nothing.

import { spawnSync } from "node:child_process";

const HERDR = process.env.HERDR_BIN ?? "herdr";

interface Run {
  code: number;
  out: string;
}

function run(cmd: string, args: string[]): Run {
  const r = spawnSync(cmd, args, { encoding: "utf8" });
  return { code: r.status === null ? 1 : r.status, out: r.stdout ?? "" };
}

function herdr(args: string[]): Run {
  return run(HERDR, args);
}

// herdr emits flat objects in one array with keys in alphabetical order, so a
// regex spanning two keys only matches by luck. Split into per-object chunks
// and read one key at a time — same approach as workctl.ts.
function jsonChunks(body: string, arrayKey: string): string[] {
  const at = body.indexOf(`"${arrayKey}":[`);
  if (at === -1) return [];
  return body.slice(at + arrayKey.length + 4).split("},{");
}

function jsonField(chunk: string, name: string): string {
  const m = new RegExp(`"${name}"\\s*:\\s*"([^"]*)"`).exec(chunk);
  return m === null ? "" : m[1] ?? "";
}

function main(): void {
  const all = process.argv.slice(2).includes("--all");

  const ws = herdr(["workspace", "list"]);
  if (ws.code !== 0) return;

  let wsId = "";
  let repoRoot = "";
  for (const chunk of jsonChunks(ws.out, "workspaces")) {
    if (!chunk.includes('"focused":true')) continue;
    wsId = jsonField(chunk, "workspace_id");
    repoRoot = jsonField(chunk, "repo_root");
    break;
  }

  // The focused workspace is not a git repo (gh-dash, a scratch shell) — there
  // is no repo to pick a branch in, so do nothing rather than guess.
  if (wsId === "" || repoRoot === "") return;

  const tab = herdr([
    "tab",
    "create",
    "--workspace",
    wsId,
    "--cwd",
    repoRoot,
    "--focus",
    "--label",
    "\u{f0665}  branch",
  ]);
  const pane = jsonField(tab.out, "pane_id");
  if (pane === "") return;

  // The nu shell needs a beat to bring its line editor up; keystrokes fed
  // during reedline's init are dropped.
  spawnSync("sleep", ["0.5"]);
  herdr(["pane", "run", pane, all ? "workctl --all" : "workctl"]);
}

main();
