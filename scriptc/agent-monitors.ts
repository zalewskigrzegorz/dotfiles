// agent-monitors — which idle tuios agents are waiting on a background Monitor.
//
// tuios marks an agent `idle` while its Claude session waits on a `Monitor`
// (deploy, CI), so Greg sees "nothing happens". The only place that says
// otherwise is the TUI footer ("· 1 monitor") in the pane scrollback, so read
// that. One-shot, run by launchd every 15 s (run_onchange_after_44).
//
// Pushes the chip with `--set` every run: a hidden item (drawing=off) never
// receives custom events, so a trigger would not wake it.
//
// `agent-monitors --selftest` checks the footer and event parsing.

import { spawnSync } from "node:child_process";

const TUIOS = process.env.TUIOS_BIN ?? "/opt/homebrew/bin/tuios";
const SKETCHYBAR = "/opt/homebrew/bin/sketchybar";

function tuios(args: string[]): { code: number; out: string } {
  const r = spawnSync(TUIOS, args, { encoding: "utf8" });
  return { code: r.status === null ? 1 : r.status, out: r.stdout ?? "" };
}

// Only the footer (last line) counts: an old "✻ … 1 monitor still running"
// line stays in the scrollback after the monitor has ended. A watcher is a
// `Monitor` ("· 1 monitor") or a `run_in_background` Bash ("· 1 shell", e.g.
// `gh pr checks --watch`); count both.
function footerMonitors(text: string): number {
  const lines = text.trimEnd().split("\n");
  let n = 0;
  for (const m of (lines[lines.length - 1] ?? "").matchAll(/(\d+) (?:monitors?|shells?)\b/g)) n += Number(m[1]);
  return n;
}

// "Prod: Platform security apply: success · Deploy BH Prod attempt 3 (hotfix #1)"
// → "Prod: Platform security apply ✓ · Deploy BH Prod attempt 3"
function describe(event: string): string {
  const [head = "", rest = ""] = event.split(" · ");
  const colon = head.lastIndexOf(":");
  const step = colon === -1 ? head : head.slice(0, colon);
  const state = colon === -1 ? "" : head.slice(colon + 1).trim();
  const mark = state === "success" ? " ✓" : state === "" ? "" : ` ${state}`;
  const ctx = (rest.split(/ run \d| \(/)[0] ?? "").trim();
  return `${step}${mark}${ctx === "" ? "" : " · " + ctx}`;
}

// Monitor events seen in the scrollback: finished steps and failed ones.
function progress(text: string): string {
  let ok = 0;
  let bad = 0;
  for (const l of text.split("\n")) {
    if (!l.includes("Monitor event:")) continue;
    if (/fail|error|cancel/i.test(l)) bad++;
    else if (l.includes(": success")) ok++;
  }
  return `${ok > 0 || bad === 0 ? "✓" + ok : ""}${bad > 0 ? (ok > 0 ? " " : "") + "✗" + bad : ""}`;
}

if (process.argv[2] === "--selftest") {
  const ok = "x\n  -- INSERT -- ⏵⏵ accept edits on · 1 monitor\n";
  const stale = "✻ done · 1 monitor still running\n  -- INSERT -- ⏵⏵ accept edits on (shift+tab to cycle)\n";
  const two = "  -- INSERT -- ⏵⏵ accept edits on · 2 monitors";
  const ev = "Prod: Platform security apply: success · Deploy BH Prod attempt 3 (hotfix #1)";
  const want = "Prod: Platform security apply ✓ · Deploy BH Prod attempt 3";
  const shell = "  -- INSERT -- ⏵⏵ accept edits on · PR #31311 · 1 shell   Image in clipboard";
  const mixed = "  -- INSERT -- · 1 monitor · 2 shells";
  if (footerMonitors(ok) !== 1 || footerMonitors(stale) !== 0 || footerMonitors(two) !== 2 ||
      footerMonitors(shell) !== 1 || footerMonitors(mixed) !== 3) {
    console.log("FAIL footer");
    process.exit(1);
  }
  if (describe(ev) !== want || describe("Prod") !== "Prod") {
    console.log(`FAIL describe: ${describe(ev)}`);
    process.exit(1);
  }
  const log = "Monitor event: a: success · x\nMonitor event: b: success · x\nMonitor event: c: failure · x";
  if (progress(log) !== "✓2 ✗1" || progress("nothing") !== "✓0") {
    console.log(`FAIL progress: ${progress(log)}`);
    process.exit(1);
  }
  console.log("ok");
  process.exit(0);
}

interface Pane {
  session?: string;
  window_id?: string;
  name?: string;
  title?: string;
  agent_state?: string;
}

// `tuios ls` exits 3 without a daemon and never starts one; every other
// command would start a daemon from this launchd job every 15 s.
let panes: Pane[] = [];
if (tuios(["ls", "--json"]).code === 0) {
  try {
    panes = (JSON.parse(tuios(["list-windows", "--all", "--json"]).out) as { windows?: Pane[] }).windows ?? [];
  } catch {
    panes = [];
  }
}

const labels: string[] = [];
const rows: string[] = [];
for (const p of panes) {
  if (p.agent_state !== "idle" && p.agent_state !== "done") continue;
  if (!p.session || !p.window_id) continue;

  const text = tuios(["capture-pane", "-s", p.session, "-w", p.window_id, "--scrollback", "--lines", "300"]).out;
  const count = footerMonitors(text);
  if (count === 0) continue;

  // last "Monitor event: <what>" line is the closest thing to progress; with
  // no event yet, the row shows just the session title
  const events = text.split("\n").filter((l) => l.includes("Monitor event:"));
  const last = events.length === 0 ? "" : events[events.length - 1] ?? "";
  const ev = last.replace(/^.*Monitor event:\s*/, "");
  const title = p.name || p.title || "";
  const what = ev !== "" ? describe(ev) : "";

  const times = count > 1 ? `×${count}` : "";
  labels.push(`${p.session} ◔${times} ${progress(text)}`);
  rows.push(`${p.session} · ${title}${what === "" ? "" : " · " + what}`.slice(0, 110));
}

// chip = progress only; the popup (click) carries the detail, 4 rows max
const sb = (args: string[]) => spawnSync(SKETCHYBAR, args);
for (let i = 0; i < 4; i++) {
  const row = rows[i];
  sb(row === undefined
    ? ["--set", `agent_monitors.row${i}`, "drawing=off"]
    : ["--set", `agent_monitors.row${i}`, "drawing=on", `label=${row}`]);
}
if (labels.length === 0) sb(["--set", "agent_monitors", "drawing=off", "popup.drawing=off"]);
else sb(["--set", "agent_monitors", "drawing=on", `label=${labels.join("  ")}`]);
