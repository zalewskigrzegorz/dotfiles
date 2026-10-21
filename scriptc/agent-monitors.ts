// agent-monitors — which idle herdr agents are waiting on a background Monitor.
//
// herdr marks an agent `idle` while its Claude session waits on a `Monitor`
// (deploy, CI), so Greg sees "nothing happens". The only place that says
// otherwise is the TUI footer ("· 1 monitor") in the pane scrollback, so read
// that. One-shot, run by launchd every 15 s (run_onchange_after_44).
//
// Writes ~/.cache/agent-monitors.json and pushes the chip with `--set` every
// run: a hidden item (drawing=off) never receives custom events, so a trigger
// would not wake it.

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";

const HERDR = process.env.HERDR_BIN ?? "/opt/homebrew/bin/herdr";
const SKETCHYBAR = "/opt/homebrew/bin/sketchybar";
const OUT = `${process.env.HOME ?? ""}/.cache/agent-monitors.json`;

function herdr(args: string[]): string {
  const r = spawnSync(HERDR, args, { encoding: "utf8" });
  return r.status === 0 ? (r.stdout ?? "") : "";
}

// herdr emits flat objects with keys in alphabetical order; read one key at a
// time from per-object chunks (same approach as herdr-worktree-new.ts).
function jsonChunks(body: string, arrayKey: string): string[] {
  const at = body.indexOf(`"${arrayKey}":[`);
  if (at === -1) return [];
  return body.slice(at + arrayKey.length + 4).split("},{");
}

function jsonField(chunk: string, name: string): string {
  const m = new RegExp(`"${name}"\\s*:\\s*"([^"]*)"`).exec(chunk);
  return m === null ? "" : m[1] ?? "";
}

function esc(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

const numbers: Record<string, string> = {};
for (const c of jsonChunks(herdr(["workspace", "list"]), "workspaces")) {
  const id = jsonField(c, "workspace_id");
  const n = /"number"\s*:\s*(\d+)/.exec(c);
  if (id !== "" && n !== null) numbers[id] = n[1] ?? "";
}

const rows: string[] = [];
for (const c of jsonChunks(herdr(["agent", "list"]), "agents")) {
  const status = jsonField(c, "agent_status");
  if (status !== "idle" && status !== "done") continue;
  const pane = jsonField(c, "pane_id");
  if (pane === "") continue;

  const text = herdr(["pane", "read", pane, "--source", "recent", "--lines", "60"]);
  const count = /(\d+) monitors?\b/.exec(text.split("\n").slice(-6).join("\n"));
  if (count === null) continue;

  // last "Monitor event: <what>" line is the closest thing to progress
  const events = text.split("\n").filter((l) => l.includes("Monitor event:"));
  const last = events.length === 0 ? "" : events[events.length - 1] ?? "";
  const ev = last.replace(/^.*Monitor event:\s*/, "").slice(0, 80);

  const ws = jsonField(c, "workspace_id");
  const title = jsonField(c, "name") || jsonField(c, "terminal_title_stripped");
  rows.push(
    `{"ws":"${esc(numbers[ws] ?? "?")}","pane":"${esc(pane)}","title":"${esc(title)}","monitors":${count[1]},"event":"${esc(ev)}"}`,
  );
}

const body = `[${rows.join(",")}]\n`;
const prev = existsSync(OUT) ? readFileSync(OUT, "utf8") : "";
if (body !== prev) {
  writeFileSync(`${OUT}.tmp`, body);
  renameSync(`${OUT}.tmp`, OUT);
}

const labels: string[] = [];
for (const r of rows) {
  const ws = /"ws":"([^"]*)"/.exec(r);
  const ev = /"event":"([^"]*)"/.exec(r);
  const what = ev === null ? "" : (ev[1] ?? "").split(":")[0] ?? "";
  const n = /"monitors":(\d+)/.exec(r);
  const times = n === null || n[1] === "1" ? "" : `×${n[1]}`;
  labels.push(`${ws === null ? "?" : ws[1]} ◔${times}${what === "" ? "" : " " + what.slice(0, 28)}`);
}
spawnSync(
  SKETCHYBAR,
  labels.length === 0
    ? ["--set", "agent_monitors", "drawing=off"]
    : ["--set", "agent_monitors", "drawing=on", `label=${labels.join("  ")}`],
);
