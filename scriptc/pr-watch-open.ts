// pr-watch-open — click handler for the SketchyBar pr_watch chip.
//
// LEFT click  → toggle a popup under the chip listing every open PR from the
//               pr-watch cache (~/.cache/pr-watch-last.json): action glyph +
//               "#num  title  <comment count>". Clicking a row opens that PR
//               in the browser; right-clicking it focuses the herdr workspace
//               on that branch, falling back to the browser when none exists.
// RIGHT click → gh-dash flow: open/focus a herdr workspace running `gh dash`
//               (my work PRs). Reuses an existing workspace if one is open.
//               No-ops cleanly if the herdr server isn't running.
//
// Ported from bash: killed the two `jq` subprocesses (cache parse + sketchybar
// --query) in favor of native JSON.parse. sketchybar itself is still shelled
// out to once per popup row — there is no way around that, it's the target.
//
// A popup row deliberately does NOT right-click into `work pr`: with no
// --action that command opens an fzf picker and bails on the `is-terminal
// --stdin` guard, and a sketchybar click_script has no TTY.
//
// scriptc's spawnSync has no `detached`/`env` option and no async spawn, so
// the background re-poll (bash's `( ... ) &`) is done by handing a one-liner
// to `sh -c '... &'`, which backgrounds and returns immediately. The
// backgrounded command re-invokes this same binary with a hidden
// `__bg-refresh` arg so the poll-then-maybe-rebuild logic stays in TS, not in
// the shell string.

import { spawnSync } from "node:child_process";
import { accessSync, constants, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const FONT = "JetBrainsMono Nerd Font";

// Mocha Neon — mirror bin/pr-watch + dot_config/sketchybar/colors.lua
const C_FIX = "0xffff8c42"; // orange — needs my fix (CI / changes requested)
const C_CONF = "0xffff6b9d"; // red — merge conflict with base
const C_NEW = "0xff8be9fd"; // sky — unresolved threads to resolve
const C_MERGE = "0xff50fa7b"; // green — ready to merge
const C_REVIEW = "0xff9580ff"; // lavender — waiting on someone's review
const C_CI = "0xffffd700"; // gold — CI in progress
const C_DRAFT = "0xffb347ff"; // mauve — draft WIP
const C_DRAFTCI = "0xffff80bf"; // pink — draft with red CI
const C_MUTED = "0xff7f849c"; // overlay — fallback/unknown
const C_TEXT = "0xfff0f0ff"; // label text

// The bash original's G_COMMENT is an empty string (`G_COMMENT=""` in
// bin/pr-watch-open) despite its "comment glyph f075" comment — the glyph
// never made it into the source. Kept empty here to match current behavior
// byte-for-byte; fixing it is a separate decision for Greg to make.
const G_COMMENT = "";

interface AlertEvent {
  ts?: string;
  num?: number;
  kind?: string;
  text?: string;
  url?: string;
}

// bin/pr-watch queues unseen events here; opening the popup moves them to the
// "shown" file (so a background rebuild still draws them) and empties the queue.
const ALERTS = join(process.env.HOME ?? "", ".cache", "pr-watch-alerts.json");
const SHOWN = join(process.env.HOME ?? "", ".cache", "pr-watch-alerts-shown.json");
const KIND_ORDER = ["ci_fail", "approval", "ci_success", "comment", "ci_start"];
// the row's icon says what happened; the label keeps only the job name / login
const KIND_GLYPH: Record<string, string> = {
  ci_fail: "\u{f00d}", // xmark
  approval: "\u{f164}", // thumbs up
  ci_success: "\u{f00c}", // check
  comment: "\u{f075}", // comment
  ci_start: "\u{f04b}", // play
};
const KIND_COLOR: Record<string, string> = {
  ci_fail: C_CONF,
  approval: C_MERGE,
  ci_success: C_MERGE,
  comment: C_NEW,
  ci_start: C_CI,
};

function readEvents(path: string): AlertEvent[] {
  if (!existsSync(path)) return [];
  try {
    const data = JSON.parse(readFileSync(path, "utf8")) as Record<string, AlertEvent>;
    const list = Object.values(data);
    list.sort((a, b) => KIND_ORDER.indexOf(a.kind ?? "") - KIND_ORDER.indexOf(b.kind ?? ""));
    return list;
  } catch {
    return [];
  }
}

interface CacheEntry {
  action?: string;
  outstanding?: number;
  actionable?: boolean;
  title?: string;
  url?: string;
  branch?: string;
}

function home(): string {
  return process.env.HOME ?? "";
}

function sourceEnvVar(file: string, name: string): string {
  const r = spawnSync(
    "bash",
    ["-c", `source "$1" 2>/dev/null; printf '%s' "$${name}"`, "bash", file],
    { encoding: "utf8" },
  );
  if (r.status !== 0) return "";
  return (r.stdout ?? "").trim();
}

function isExecutable(path: string): boolean {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function popupDrawing(): string {
  const r = spawnSync("sketchybar", ["--query", "pr_watch"], { encoding: "utf8" });
  if (r.status !== 0 || !r.stdout) return "off";
  try {
    const data = JSON.parse(r.stdout) as { popup?: { drawing?: string } };
    return data?.popup?.drawing ?? "off";
  } catch {
    return "off";
  }
}

function tagFor(action: string): { tag: string; color: string } {
  switch (action) {
    case "fix CI":
      return { tag: "fix CI", color: C_FIX };
    case "changes req":
      return { tag: "changes!", color: C_FIX };
    case "run e2e":
      return { tag: "run e2e!", color: C_FIX };
    case "conflict":
      return { tag: "conflict", color: C_CONF };
    case "resolve":
      return { tag: "resolve ", color: C_NEW };
    case "CI…":
      return { tag: "CI runs…", color: C_CI };
    case "MERGE":
      return { tag: "merge ✓", color: C_MERGE };
    case "draft+CI":
      return { tag: "draft+CI", color: C_DRAFTCI };
    case "draft":
      return { tag: "draft", color: C_DRAFT };
    case "needs review":
      return { tag: "review?", color: C_REVIEW };
    case "blocked":
      return { tag: "blocked", color: C_REVIEW };
    default:
      return { tag: action, color: C_MUTED };
  }
}

function truncate(title: string): string {
  const chars = [...title];
  if (chars.length > 48) {
    return chars.slice(0, 47).join("") + "…";
  }
  return title;
}

function ghDash(): void {
  const herdrBin = process.env.HERDR_BIN || "/opt/homebrew/bin/herdr";
  let repoDir = process.env.PR_WATCH_REPO_DIR || "";
  if (repoDir === "") {
    // Work monorepo path lives in the private work.env (restored by sync).
    // Bash's `repo_dir="${WORK_MONOREPO_DIR:-}"` runs regardless of whether
    // the file exists, so it also picks up an already-exported
    // WORK_MONOREPO_DIR (e.g. nushell's work-env.nu autoload) even when
    // work.env is missing — replicate that fallback here too.
    const workEnv = join(home(), ".local/state/dotfiles/secrets/work.env");
    if (existsSync(workEnv)) {
      repoDir = sourceEnvVar(workEnv, "WORK_MONOREPO_DIR");
    } else {
      repoDir = process.env.WORK_MONOREPO_DIR || "";
    }
  }
  if (repoDir === "") {
    console.error("pr-watch-open: set PR_WATCH_REPO_DIR or restore work.env (run sync)");
    return;
  }
  const label = process.env.PR_WATCH_DASH_LABEL || "📋 gh-dash";
  if (!isExecutable(herdrBin)) return;

  let ws = "";
  const listRes = spawnSync(herdrBin, ["workspace", "list"], { encoding: "utf8" });
  if (listRes.status === 0 && listRes.stdout) {
    try {
      const data = JSON.parse(listRes.stdout) as {
        result?: { workspaces?: { label?: string; workspace_id?: string }[] };
      };
      const workspaces = data?.result?.workspaces ?? [];
      for (const w of workspaces) {
        if (w?.label === label && w?.workspace_id) {
          ws = w.workspace_id;
          break;
        }
      }
    } catch {
      // leave ws empty — same fallback as `jq` failing silently
    }
  }

  if (ws !== "") {
    spawnSync(herdrBin, ["workspace", "focus", ws], { stdio: "ignore" });
  } else {
    const out = spawnSync(
      herdrBin,
      ["workspace", "create", "--cwd", repoDir, "--label", label, "--focus"],
      { encoding: "utf8" },
    );
    let pane = "";
    if (out.stdout) {
      try {
        const data = JSON.parse(out.stdout) as {
          result?: { root_pane?: { pane_id?: string } };
        };
        pane = data?.result?.root_pane?.pane_id ?? "";
      } catch {
        // leave pane empty
      }
    }
    if (pane !== "") {
      spawnSync(herdrBin, ["pane", "run", pane, "gh dash"], { stdio: "ignore" });
    }
  }
  // bring the terminal forward so the focus jump is actually visible
  spawnSync("open", ["-a", "Ghostty"], { stdio: "ignore" });
}

// Focus the herdr workspace whose worktree has `branch` checked out. Exit 1 when
// none does, so the row's click_script falls back to the browser.
function focusBranch(branch: string): number {
  const herdrBin = process.env.HERDR_BIN || "/opt/homebrew/bin/herdr";
  if (branch === "" || !isExecutable(herdrBin)) return 1;
  const listRes = spawnSync(herdrBin, ["workspace", "list"], { encoding: "utf8" });
  if (listRes.status !== 0 || !listRes.stdout) return 1;
  let workspaces: { workspace_id?: string; worktree?: { checkout_path?: string } }[] = [];
  try {
    const data = JSON.parse(listRes.stdout) as {
      result?: { workspaces?: { workspace_id?: string; worktree?: { checkout_path?: string } }[] };
    };
    workspaces = data?.result?.workspaces ?? [];
  } catch {
    return 1;
  }
  for (const w of workspaces) {
    const path = w?.worktree?.checkout_path ?? "";
    if (path === "" || !w?.workspace_id) continue;
    const head = spawnSync("git", ["-C", path, "branch", "--show-current"], { encoding: "utf8" });
    if (head.status === 0 && (head.stdout ?? "").trim() === branch) {
      spawnSync(herdrBin, ["workspace", "focus", w.workspace_id], { stdio: "ignore" });
      spawnSync("open", ["-a", "Ghostty"], { stdio: "ignore" });
      return 0;
    }
  }
  return 1;
}

function loadCache(cachePath: string): [string, CacheEntry][] {
  if (!existsSync(cachePath)) return [];
  let raw: string;
  try {
    raw = readFileSync(cachePath, "utf8");
  } catch {
    return [];
  }
  if (raw.trim() === "") return [];
  let data: Record<string, CacheEntry>;
  try {
    data = JSON.parse(raw) as Record<string, CacheEntry>;
  } catch {
    return [];
  }
  const entries = Object.entries(data);
  // actionable first, then newest PR number on top within each group
  entries.sort((a, b) => {
    const aRank = a[1]?.actionable ? 0 : 1;
    const bRank = b[1]?.actionable ? 0 : 1;
    if (aRank !== bRank) return aRank - bRank;
    return Number(b[0]) - Number(a[0]);
  });
  return entries;
}

function rebuildRows(cachePath: string): void {
  // sketchybar's item regex is basic POSIX: no `(a|b)`, so one remove per prefix
  spawnSync("sketchybar", ["--remove", "/pr_watch\\.pr\\..*/", "--remove", "/pr_watch\\.ev\\..*/"], { stdio: "ignore" });

  const events = readEvents(SHOWN);
  for (const ev of events) {
    const num = Number(ev.num ?? 0);
    const time = (ev.ts ?? "").slice(11, 16);
    spawnSync(
      "sketchybar",
      [
        "--add", "item", `pr_watch.ev.${num}`, "popup.pr_watch",
        "--set", `pr_watch.ev.${num}`,
        `icon=${KIND_GLYPH[ev.kind ?? ""] ?? "\u{f111}"}`,
        `icon.color=${KIND_COLOR[ev.kind ?? ""] ?? C_MUTED}`,
        `icon.font=${FONT}:Bold:12.0`,
        "icon.padding_left=10",
        `label=#${num}  ${ev.text ? truncate(ev.text) + "  " : ""}${time}`,
        `label.color=${C_TEXT}`,
        `label.font=${FONT}:Bold:12.0`,
        "label.padding_right=10",
        `click_script='${process.argv[1]}' __ev ${num}`,
      ],
      { stdio: "ignore" },
    );
  }
  if (events.length > 0) {
    spawnSync(
      "sketchybar",
      [
        "--add", "item", "pr_watch.ev.sep", "popup.pr_watch",
        "--set", "pr_watch.ev.sep",
        "icon.drawing=off",
        "label=────────────────",
        `label.color=${C_MUTED}`,
        "label.padding_left=10",
      ],
      { stdio: "ignore" },
    );
  }

  const entries = loadCache(cachePath);
  let added = 0;

  for (const [num, entry] of entries) {
    const action = entry.action ?? "";
    const { tag, color } = tagFor(action);
    const title = entry.title ?? "";
    const short = truncate(title);
    const outstanding = entry.outstanding ?? 0;
    const suffix = outstanding > 0 ? `   ${G_COMMENT} ${outstanding}` : "";
    const url = entry.url ?? "";
    // only the numeric PR key reaches the shell; branch and url are read back from the cache
    const click = `'${process.argv[1]}' __row ${Number(num)}`;

    spawnSync(
      "sketchybar",
      [
        "--add",
        "item",
        `pr_watch.pr.${num}`,
        "popup.pr_watch",
        "--set",
        `pr_watch.pr.${num}`,
        `icon=${tag}`,
        `icon.color=${color}`,
        `icon.font=${FONT}:SemiBold:11.0`,
        "icon.width=82",
        "icon.align=left",
        "icon.padding_left=10",
        `label=#${num}  ${short}${suffix}`,
        `label.color=${C_TEXT}`,
        `label.font=${FONT}:Regular:12.0`,
        "label.padding_right=10",
        `click_script=${click}`,
      ],
      { stdio: "ignore" },
    );
    added += 1;
  }

  if (added === 0) {
    spawnSync(
      "sketchybar",
      [
        "--add",
        "item",
        "pr_watch.pr.none",
        "popup.pr_watch",
        "--set",
        "pr_watch.pr.none",
        "icon.drawing=off",
        "label=brak danych — poczekaj na następny poll pr-watch",
        `label.color=${C_MUTED}`,
        `label.font=${FONT}:Regular:12.0`,
        "label.padding_left=8",
        "label.padding_right=8",
      ],
      { stdio: "ignore" },
    );
  }

  spawnSync("sketchybar", ["--set", "pr_watch", "popup.drawing=on"], { stdio: "ignore" });
}

function backgroundRefresh(cachePath: string): void {
  const prWatch = join(home(), "Code/dotfiles/bin/pr-watch");
  spawnSync(prWatch, [], { stdio: "ignore" });
  if (popupDrawing() === "on") {
    const self = process.argv[1];
    process.env.PR_WATCH_REBUILD = "1";
    process.env.BUTTON = "left";
    spawnSync(self, [], { stdio: "ignore" });
  }
}

function popup(): void {
  const cachePath = join(home(), ".cache", "pr-watch-last.json");

  if (process.env.PR_WATCH_REBUILD !== "1") {
    // already open → close and be done (toggle semantics)
    if (popupDrawing() === "on") {
      spawnSync("sketchybar", ["--set", "pr_watch", "popup.drawing=off"], { stdio: "ignore" });
      return;
    }

    // rows render instantly from cache (may be up to 3 min stale) — kick a
    // fresh poll in the background and rebuild in place when it lands, if the
    // popup is still open. The `__bg-refresh` re-invocation guards recursion.
    const self = process.argv[1];
    spawnSync("sh", ["-c", `"${self}" __bg-refresh >/dev/null 2>&1 &`], { stdio: "ignore" });

    // seen now: show this batch, empty the queue, stop the blink
    writeFileSync(SHOWN, existsSync(ALERTS) ? readFileSync(ALERTS, "utf8") : "{}");
    writeFileSync(ALERTS, "{}");
    spawnSync("sketchybar", ["--trigger", "pr_watch_alert"], { stdio: "ignore" });
  }

  // rebuild rows from scratch each open — cache may have changed since
  rebuildRows(cachePath);
}

function main(): void {
  process.env.PATH = `/opt/homebrew/bin:${process.env.PATH ?? ""}`;

  const args = process.argv.slice(2);
  if (args[0] === "__bg-refresh") {
    backgroundRefresh(join(home(), ".cache", "pr-watch-last.json"));
    return;
  }
  if (args[0] === "__ev") {
    // a failed check opens its job log, everything else the PR
    const ev = readEvents(SHOWN).find((e) => String(Number(e.num ?? 0)) === args[1]);
    const pr = loadCache(join(home(), ".cache", "pr-watch-last.json")).find(([n]) => n === args[1]);
    const url = ev?.url || pr?.[1]?.url || "";
    if (url.startsWith("https://github.com/")) spawnSync("open", [url], { stdio: "ignore" });
    spawnSync("sketchybar", ["--set", "pr_watch", "popup.drawing=off"], { stdio: "ignore" });
    return;
  }
  if (args[0] === "__row") {
    // right click → that branch's herdr workspace when one exists, else the browser
    const entry = loadCache(join(home(), ".cache", "pr-watch-last.json")).find(([n]) => n === args[1]);
    const url = entry?.[1]?.url ?? "";
    if (process.env.BUTTON !== "right" || focusBranch(entry?.[1]?.branch ?? "") !== 0) {
      if (url.startsWith("https://github.com/")) spawnSync("open", [url], { stdio: "ignore" });
    }
    spawnSync("sketchybar", ["--set", "pr_watch", "popup.drawing=off"], { stdio: "ignore" });
    return;
  }

  const button = process.env.BUTTON || "left";
  if (button === "right") {
    ghDash();
  } else {
    popup();
  }
}

main();
