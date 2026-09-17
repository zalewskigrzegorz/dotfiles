// Seed `disabledMcpServers` for a project path in ~/.claude.json.
//
// Claude Code reads that key ONLY from projects[<cwd>] — there is no user/
// global scope (verified in the CLI bundle: `Rd()` returns
// `t.projects[fbe()] ?? {}`). So every fresh worktree starts with nothing
// disabled and the claude.ai connector catalog reappears. This script writes
// the defaults for a given path.
//
// The names below are catalog entries Greg never authenticates. They cannot
// be removed at claude.ai — the UI offers only "Connect" — so suppressing
// them per-path is the only lever.
//
// Usage:
//   claude-mcp-defaults [PATH...]   # default: $PWD
//   claude-mcp-defaults --all       # backfill every existing project entry
//   claude-mcp-defaults --list      # print the default list and exit
//
// Ported from bash: the bash version shelled out to a python3 heredoc to do
// the actual JSON read-modify-write. This does the same JSON logic natively.
//
// Two scriptc gotchas this file works around, both found by testing against
// real ~/.claude.json-shaped fixtures before trusting this near the real
// file:
//
// 1. `JSON.parse(raw) as SomeNamedInterface` is NOT a plain type assertion —
//    scriptc actually reconstructs the value to match the interface, and
//    SILENTLY DROPS every field not declared on it. Casting the whole config
//    to a `ClaudeConfig`-shaped interface would have thrown away history,
//    oauthAccount, allowedTools and everything else this script doesn't
//    touch. The fix is casting only ever to the fully generic
//    `Record<string, unknown>` (no fixed key set to reconstruct against),
//    never to a named interface, for any value that must round-trip whole.
//
// 2. A nested cast (`data["projects"] as Record<string, unknown>`) hands
//    back a DETACHED COPY, not a reference into `data` — mutating it does
//    nothing to `data`. Every level has to be written back explicitly after
//    mutating it (`projects[path] = entry; data["projects"] = projects;`)
//    or the change is silently lost even though the script would still
//    report success and rewrite the file. Caught by round-tripping a
//    fixture with sibling keys and asserting they changed; without that
//    check this would have shipped a script that reports "+13 disabled"
//    while writing back the file completely unchanged.
//
// `flock` is already a brew dependency for exactly this kind of lock (see
// bin/mempalace-hook). scriptc's spawnSync has no `env`/`cwd`/fd options, so
// instead of bash's `exec 9>lock; flock -w 10 9`, this wraps a locked
// re-invocation of this same binary: `flock -w 10 -E 2 <lock> <self>
// __do-work ...`. `-E 2` gives the lock-timeout path its own exit code so it
// can't be confused with a real failure inside the locked work (which always
// exits 0).
//
// ~/.claude.json is also written by every running Claude Code session, so
// the read-modify-write is guarded by that lock and swapped in atomically.
// Clobbering this file loses history, allowlists and onboarding state for
// every project.

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const CONFIG = join(process.env.HOME ?? "", ".claude.json");

const WANTED = [
  "claude.ai Asana",
  "claude.ai Atlassian",
  "claude.ai Box",
  "claude.ai Canva",
  "claude.ai Context7",
  "claude.ai Front MCP",
  "claude.ai Google Calendar",
  "claude.ai HubSpot",
  "claude.ai Intercom",
  "claude.ai Linear",
  "claude.ai Notion",
  "claude.ai Sentry",
  "claude.ai monday.com",
];

function cmpStr(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

const HEX_DIGITS = "0123456789abcdef";

function toHex4(code: number): string {
  let out = "";
  let n = code;
  for (let i = 0; i < 4; i++) {
    out = HEX_DIGITS[n % 16] + out;
    n = Math.floor(n / 16);
  }
  return out;
}

// Match Python's json.dump(..., indent=2) byte-for-byte: ensure_ascii=True
// escapes every non-ASCII UTF-16 code unit as \uXXXX (surrogate pairs
// included, same granularity Python's encoder uses), which JSON.stringify
// alone does not do — it leaves UTF-8 literal characters in place.
function pyJsonDump(data: unknown): string {
  const json = JSON.stringify(data, null, 2);
  let out = "";
  for (let i = 0; i < json.length; i++) {
    const code = json.charCodeAt(i);
    if (code > 0x7f) {
      out += `\\u${toHex4(code)}`;
    } else {
      out += json[i];
    }
  }
  return out;
}

function printList(): void {
  console.log(WANTED.join("\n"));
}

function isPlainObject(v: unknown): boolean {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function doWork(rest: string[]): void {
  let mode: "paths" | "all" = "paths";
  let targets: string[];
  if (rest[0] === "--all") {
    mode = "all";
    targets = [];
  } else {
    // Bash's default target is literally `$PWD` — the shell's logical cwd,
    // which preserves symlinks (e.g. `/tmp/x`, not `/private/tmp/x` on
    // macOS). process.cwd() resolves them (physical path via getcwd()), so
    // prefer the inherited PWD env var to match bash exactly; it's set by
    // every real invocation.
    targets = rest.length > 0 ? rest : [process.env.PWD || process.cwd()];
  }

  const raw = readFileSync(CONFIG, "utf8");
  // Generic cast only — see file header note 1. Never cast this to a named
  // interface, or every untouched top-level key gets silently dropped.
  const data = JSON.parse(raw) as Record<string, unknown>;

  if (!isPlainObject(data["projects"])) {
    data["projects"] = {};
  }
  const projects = data["projects"] as Record<string, unknown>;

  if (mode === "all") {
    targets = Object.keys(projects);
  }

  const changed: [string, number][] = [];
  for (const path of targets) {
    if (!isPlainObject(projects[path])) {
      projects[path] = {};
    }
    const entry = projects[path] as Record<string, unknown>;

    const rawCurrent = entry["disabledMcpServers"];
    const current: string[] = Array.isArray(rawCurrent) ? (rawCurrent as string[]) : [];
    const mergedSet = new Set<string>([...current, ...WANTED]);
    const merged = [...mergedSet].sort(cmpStr);
    const sortedCurrent = [...current].sort(cmpStr);

    if (JSON.stringify(merged) !== JSON.stringify(sortedCurrent)) {
      entry["disabledMcpServers"] = merged;
      changed.push([path, merged.length - new Set(current).size]);
    }

    // Write back — see file header note 2. Without this the mutation above
    // never reaches `projects`/`data`, and the file gets rewritten unchanged.
    projects[path] = entry;
  }
  data["projects"] = projects;

  if (changed.length === 0) {
    console.log("claude-mcp-defaults: already current, no write needed.");
    return;
  }

  // Atomic swap on the same filesystem so a crash mid-write cannot truncate it.
  const dir = dirname(CONFIG);
  const tmpPath = join(dir, `.claude-mcp-defaults.${process.pid}.tmp`);
  writeFileSync(tmpPath, `${pyJsonDump(data)}\n`);
  renameSync(tmpPath, CONFIG);

  for (const [path, added] of changed) {
    console.log(`claude-mcp-defaults: +${added} disabled → ${path}`);
  }
}

function main(): void {
  const args = process.argv.slice(2);

  if (args[0] === "--list") {
    printList();
    return;
  }

  if (args[0] === "__do-work") {
    doWork(args.slice(1));
    return;
  }

  if (!existsSync(CONFIG)) {
    console.error(`claude-mcp-defaults: ${CONFIG} missing — nothing to do.`);
    return;
  }

  const self = process.argv[1];
  const lockFile = `${CONFIG}.lock`;
  const r = spawnSync(
    "flock",
    ["-w", "10", "-E", "2", lockFile, self, "__do-work", ...args],
    { stdio: "inherit" },
  );
  if (r.status === 2) {
    console.error(`claude-mcp-defaults: could not lock ${CONFIG} after 10s — skipping.`);
  }
}

main();
