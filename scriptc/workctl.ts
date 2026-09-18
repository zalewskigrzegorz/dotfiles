// workctl — the ONE command for "get me onto a branch and do the next thing".
//
// Two screens, same binary, no matter who opens it:
//
//   1. TARGET   one fzf over everything in this repo you could mean: worktrees,
//               open PRs, local and remote branches, plus "new branch from
//               origin/<default>" / "new branch from HEAD" rows for what you
//               typed. A number matches the PR, a word matches branches and
//               titles. Preview shows the branch or PR state.
//   2. ACTIONS  the `work pr` registry, annotated for that target and sorted
//               by relevance (→ suggested · hot · cold), TAB for several:
//               resolve threads, fix CI with an agent, labels, merge, update,
//               stack, worktree (three seed modes), diff, remove, browser…
//               After the picked actions run the state is re-read and the menu
//               comes back, until Esc or until a worktree/agent takes over.
//
// Triggers (all end here): `work` / `work new` / `work switch` / `work pr` in
// nushell (thin wrappers in work.nu + workpr.nu), herdr prefix+shift+g / +o,
// gh-dash `T` (PRs) and `w` (branches), lazygit `w`.
//
// Headless contract kept from `work pr`:
//   workctl --repo owner/name --pr N [--action ID] [--yes] [--dry-run] [--json] [--pause]
// `--repo --pr` with `--action` makes zero git calls, so gh-dash can drive a
// repo it has no local checkout for. Without `--action` a TTY is required.
//
// Why a binary and not nushell: gh-dash and lazygit cannot see nushell's
// autoload, and fzf re-runs the row generator on every keystroke — that has to
// be native to stay instant. The classifier (signals → action → rank/bucket)
// ALSO still lives in workpr.nu for bin/prs and bin/pr-watch, which `source` it;
// the two copies must agree. It is a frozen vocabulary, so drift is unlikely,
// but a change to one is a change to both.
//
// scriptc rules this file obeys (each one bit once — see CLAUDE.md "scriptc"):
//   - never `.replace()`: use split/join or slice; even a literal replace is
//     lowered to the dynamic engine this build does not ship
//   - never `JSON.parse(x) as Interface`, and never index a Record for a key it
//     may not have (it THROWS, it does not yield undefined) → Map everywhere,
//     and gh output is shaped by `--jq` into US-separated lines instead of JSON
//   - never an optional function-typed field on an interface: closures in a
//     record are fine only when the field is required, so every row carries
//     every hook and returns "" / false for "not applicable"
//   - no `/g` exec loops, no `.flat()`, no `?.` on regex groups

import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";

const HOME = process.env.HOME ?? "";
const TREE_ROOT = join(HOME, "Code", "tree");
const HERDR_TREE_ROOT = join(HOME, ".herdr", "worktrees");
const CACHE_DIR = join(HOME, ".cache");
const NU_AUTOLOAD = join(HOME, ".config", "nushell", "autoload");
const PR_LIST_TTL_S = 300;
const US = "\x1f";

// Commitlint type → emoji, mirroring WORK_PREFIX_EMOJI in work.nu. The herdr
// workspace label must come out byte-identical to what `work new` produced or
// every existing worktree is relabelled the first time it is reopened.
const TYPE_EMOJI = new Map<string, string>([
  ["feat", "✨"],
  ["fix", "🐛"],
  ["hotfix", "🚑"],
  ["docs", "📝"],
  ["tests", "🧪"],
  ["test", "🧪"],
  ["chore", "🧹"],
  ["refactor", "♻"],
  ["perf", "⚡"],
  ["build", "📦"],
  ["ci", "👷"],
  ["revert", "⏪"],
  ["style", "💄"],
]);

const CONVENTIONAL_DEFAULTS = [
  "feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert",
];

// `--action` shorthands. Anything not listed is used verbatim as a label name.
const LABEL_ALIASES = new Map<string, string>([
  ["nc", "no-changeset-needed"],
  ["e2e", "run_e2e"],
  ["skip", "skip_e2e"],
]);

// One `gh pr view --json` for the whole run. `stack` and `reviewThreads` are
// GraphQL-only and never in this list.
const VIEW_FIELDS =
  "number,title,url,isDraft,author,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,labels,reviewRequests,latestReviews,headRefName,headRefOid,baseRefName,isCrossRepository";

// ── process helpers ─────────────────────────────────────────────────────────

interface Run {
  code: number;
  out: string;
  err: string;
}

function run(cmd: string, args: string[]): Run {
  const r = spawnSync(cmd, args, { encoding: "utf8" });
  return { code: r.status === null ? 1 : r.status, out: r.stdout ?? "", err: r.stderr ?? "" };
}

// The child owns the terminal (pager, fzf sub-process, `gh pr checks --watch`).
function runTty(cmd: string, args: string[]): number {
  const r = spawnSync(cmd, args, { stdio: "inherit" });
  return r.status === null ? 1 : r.status;
}

function sh(script: string): Run {
  return run("sh", ["-c", script]);
}

function shq(s: string): string {
  return "'" + s.split("'").join("'\\''") + "'";
}

function have(bin: string): boolean {
  return sh(`command -v ${shq(bin)} >/dev/null 2>&1`).code === 0;
}

function git(root: string, args: string[]): Run {
  return run("git", ["-C", root, ...args]);
}

function lines(s: string): string[] {
  return s
    .split("\n")
    .map((l) => (l.endsWith("\r") ? l.slice(0, l.length - 1) : l))
    .filter((l) => l !== "");
}

function trimSlash(s: string): string {
  return s.endsWith("/") ? s.slice(0, s.length - 1) : s;
}

function basename(p: string): string {
  const parts = p.split("/").filter((s) => s !== "");
  return parts.length === 0 ? p : parts[parts.length - 1] ?? p;
}

function stripGitSuffix(root: string): string {
  return root.endsWith("/.git") ? root.slice(0, root.length - 5) : dirname(root);
}

function out(s: string): void {
  console.log(s);
}

function err(s: string): void {
  console.error(s);
}

// spawnSync's default stdio is a pipe, so `[ -t 0 ]` in a child would always be
// false; inherit makes the test see the real stdin.
function isTty(): boolean {
  const r = spawnSync("sh", ["-c", "[ -t 0 ]"], { stdio: "inherit" });
  return r.status === 0;
}

// Read one line from the terminal itself, not from stdin — fzf and the
// gh-dash hand-off both leave stdin in states that are not a keyboard.
function ask(prompt: string): string {
  const r = run("sh", [
    "-c",
    'printf "%s" "$1" >/dev/tty; IFS= read -r x </dev/tty || x=""; printf "%s" "$x"',
    "_",
    prompt,
  ]);
  return r.out.trim();
}

// gh-dash repaints the dashboard the moment the child exits, so an error needs
// the same hold as a success. PAUSE is set as main's FIRST act, before any
// guard, so a die reached from any helper still holds the screen.
let PAUSE = false;

function hold(): void {
  ask("\npress enter to continue");
}

function die(msg: string): never {
  err(msg);
  if (PAUSE) hold();
  process.exit(1);
}

// ── herdr JSON ──────────────────────────────────────────────────────────────
// herdr's --json payloads are flat objects inside one array with keys emitted
// in ALPHABETICAL order ("label" before "tab_id", "open_workspace_id" before
// "path"), so a regex spanning two keys only matches by luck. Split into
// per-object chunks and read one key at a time.

function jsonChunks(body: string, arrayKey: string): string[] {
  const at = body.indexOf(`"${arrayKey}":[`);
  if (at === -1) return [];
  return body.slice(at + arrayKey.length + 4).split("},{");
}

function jsonField(chunk: string, name: string): string {
  const m = new RegExp(`"${name}"\\s*:\\s*"([^"]*)"`).exec(chunk);
  return m === null ? "" : m[1] ?? "";
}

function herdrWorkspaceId(o: string): string {
  return jsonField(o, "workspace_id");
}

function herdrPaneId(o: string): string {
  return jsonField(o, "pane_id");
}

// ── fzf ─────────────────────────────────────────────────────────────────────
// Row format is a CONTRACT: field 1 is the machine key, a REAL tab separates
// fields, `--with-nth=2..` hides field 1, `--nth=1` (post-transform index!)
// matches the display column only. `--with-shell 'sh -c'`: fzf runs reload and
// preview commands through $SHELL, and Greg's $SHELL is nushell, which rejects
// `'/path/bin' arg` outright — every callback came back "Command failed".

interface FzfResult {
  code: number;
  query: string;
  expect: string;
  keys: string[];
}

function fzfBase(prompt: string, header: string): string[] {
  return [
    "--delimiter", "\t",
    "--with-nth", "2..",
    "--nth", "1",
    "--tiebreak", "begin,index",
    "--reverse",
    "--header-first",
    "--with-shell", "sh -c",
    "--prompt", prompt,
    "--header", header,
  ];
}

// stdin is the row file: spawnSync has no `input` option in scriptc, and fzf
// draws on /dev/tty, so stdout stays free for the selection.
function fzfRun(args: string[], rowFile: string): FzfResult {
  const cmd =
    "exec fzf " + args.map((a) => shq(a)).join(" ") + " < " + (rowFile === "" ? "/dev/null" : shq(rowFile));
  const r = spawnSync("sh", ["-c", cmd], { encoding: "utf8", stdio: ["inherit", "pipe", "inherit"] });
  const code = r.status === null ? 1 : r.status;
  const got = (r.stdout ?? "").split("\n");
  // With --print-query + --expect the first two lines are the query and the key.
  const query = (got[0] ?? "").trim();
  const expect = (got[1] ?? "").trim();
  const keys = got
    .slice(2)
    .filter((l) => l.trim() !== "")
    .map((l) => l.split("\t")[0] ?? "")
    .filter((k) => k !== "");
  return { code, query, expect, keys };
}

function tmpFile(tag: string): string {
  return join(process.env.TMPDIR ?? "/tmp", `workctl-${tag}-${process.pid}.tsv`);
}

// Static multi-select picker (stage 2 and the sub-pickers). Returns [] on
// Esc/Ctrl-C (130) and on "no match" (1); anything else is a broken picker and
// must not be mistaken for a cancel.
function fzfPick(rows: string[], prompt: string, header: string, multi: boolean): string[] {
  if (rows.length === 0) return [];
  if (!have("fzf")) die("fzf not found on PATH — pass --action instead");
  if (!isTty()) die("this picker needs a TTY — pass --action instead");
  const f = tmpFile("pick");
  writeFileSync(f, rows.join("\n") + "\n", { mode: 0o600 });
  const args = [...fzfBase(prompt, header), "--print-query", "--expect", "ctrl-c"];
  if (multi) args.push("--multi");
  const r = fzfRun(args, f);
  try {
    unlinkSync(f);
  } catch {
    // per-pid temp file; a leftover is harmless
  }
  if (r.code === 130 || r.code === 1) return [];
  if (r.code !== 0) die(`fzf failed (${r.code})`);
  return r.keys;
}

// ── repo (stage-1) state ────────────────────────────────────────────────────

interface Worktree {
  repo: string;
  root: string;
  branch: string;
  path: string;
}

interface Branch {
  name: string;
  remote: boolean;
  date: string;
  subject: string;
}

interface PrRow {
  num: number;
  title: string;
  head: string;
  author: string;
  draft: boolean;
}

interface RepoState {
  repo: string; // basename of the parent checkout
  root: string; // parent checkout root
  ghRepo: string; // owner/name, "" when no GitHub remote
  defaultBranch: string;
  currentBranch: string; // branch cwd is on ("" if detached / not a repo)
  bootstrap: string;
  me: string;
  types: string[];
  worktrees: Worktree[];
  foreign: Worktree[];
  branches: Branch[];
  prs: PrRow[];
}

function repoInfo(cwd: string): { repo: string; root: string; def: string; current: string } {
  const top = run("git", ["-C", cwd, "rev-parse", "--show-toplevel"]);
  if (top.code !== 0) die(`not inside a git repository (${cwd})`);
  const common = run("git", ["-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"]);
  if (common.code !== 0) die("failed to resolve the git common dir");
  const root = stripGitSuffix(common.out.trim());
  const head = git(root, ["symbolic-ref", "refs/remotes/origin/HEAD"]);
  const ORIGIN_REF = "refs/remotes/origin/";
  const headRef = head.out.trim();
  const def = head.code === 0 && headRef.startsWith(ORIGIN_REF) ? headRef.slice(ORIGIN_REF.length) : "master";
  const cur = run("git", ["-C", cwd, "branch", "--show-current"]);
  return { repo: basename(root), root, def, current: cur.code === 0 ? cur.out.trim() : "" };
}

// owner/name of every remote — `git config`, so local only, no network.
// `https://host/o/n.git`, `git@host:o/n.git` and `ssh://git@host/o/n` all
// reduce to `o/n`; --local keeps a stray global remote.*.url out.
function remoteRepoIds(root: string): string[] {
  const r = git(root, ["config", "--local", "--get-regexp", "^remote\\..+\\.url$"]);
  if (r.code !== 0) return [];
  const ids: string[] = [];
  // origin first, so it wins as "the" repo when several remotes exist
  const ordered = lines(r.out).sort((a, b) => {
    const ao = a.startsWith("remote.origin.url") ? 0 : 1;
    const bo = b.startsWith("remote.origin.url") ? 0 : 1;
    return ao - bo;
  });
  for (const l of ordered) {
    const sp = l.indexOf(" ");
    let url = sp === -1 ? "" : l.slice(sp + 1).trim();
    if (url.endsWith(".git")) url = url.slice(0, url.length - 4);
    const segs = url.split(/[/:]/).filter((s) => s !== "");
    if (segs.length >= 2) {
      const id = `${segs[segs.length - 2]}/${segs[segs.length - 1]}`;
      if (!ids.includes(id)) ids.push(id);
    }
  }
  return ids;
}

// ONE fork for every worktree of the repo (the old scan spent three per tree).
// Dirty state moved into the preview, computed for the highlighted row only.
function worktreesOf(root: string, repo: string): Worktree[] {
  const r = git(root, ["worktree", "list", "--porcelain"]);
  if (r.code !== 0) return [];
  const wts: Worktree[] = [];
  let path = "";
  for (const line of lines(r.out)) {
    if (line.startsWith("worktree ")) path = line.slice("worktree ".length);
    else if (line.startsWith("branch refs/heads/")) {
      const branch = line.slice("branch refs/heads/".length);
      if (path !== root) wts.push({ repo, root, branch, path });
    }
  }
  return wts;
}

// Other repos' worktrees for `--all`. `find`, not a glob: a branch name carries
// slashes, so `feat/lde` sits two directories deep. A linked worktree's .git is
// a FILE, which `-name .git` covers and `[ -d ]` would not.
function foreignWorktrees(skipRoot: string): Worktree[] {
  const r = sh(
    `find ${shq(TREE_ROOT)} ${shq(HERDR_TREE_ROOT)} -maxdepth 4 -name .git 2>/dev/null | ` +
      `while read -r g; do d=$(dirname "$g"); ` +
      `c=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue; ` +
      `b=$(git -C "$d" branch --show-current 2>/dev/null); ` +
      `printf '%s\\t%s\\t%s\\n' "$d" "$c" "$b"; done`,
  );
  if (r.code !== 0) return [];
  const seen = new Set<string>();
  const wts: Worktree[] = [];
  for (const line of lines(r.out)) {
    const f = line.split("\t");
    if (f.length < 3) continue;
    const path = trimSlash(f[0] ?? "");
    const root = stripGitSuffix(f[1] ?? "");
    const branch = f[2] ?? "";
    if (branch === "" || path === "" || root === skipRoot || seen.has(path)) continue;
    seen.add(path);
    wts.push({ repo: basename(root), root, branch, path });
  }
  return wts;
}

function branchesOf(root: string): Branch[] {
  // The FULL refname is in the format: the short name of refs/remotes/origin/HEAD
  // is the bare string "origin", indistinguishable from a local branch by name.
  const fmt = "%(refname)\t%(refname:short)\t%(committerdate:relative)\t%(contents:subject)";
  const r = git(root, ["for-each-ref", `--format=${fmt}`, "--sort=-committerdate", "refs/heads/", "refs/remotes/origin/"]);
  if (r.code !== 0) return [];
  const REMOTE = "refs/remotes/origin/";
  const rows: string[][] = [];
  const localSeen = new Set<string>();
  for (const line of lines(r.out)) {
    const f = line.split("\t");
    const ref = f[0] ?? "";
    if (ref === "" || ref === "refs/remotes/origin/HEAD") continue;
    rows.push(f);
    if (!ref.startsWith(REMOTE)) localSeen.add(f[1] ?? "");
  }
  const branches: Branch[] = [];
  for (const f of rows) {
    const ref = f[0] ?? "";
    const remote = ref.startsWith(REMOTE);
    const name = remote ? ref.slice(REMOTE.length) : f[1] ?? "";
    // A branch that exists locally is listed once, as local.
    if (remote && localSeen.has(name)) continue;
    branches.push({ name, remote, date: f[2] ?? "", subject: (f[3] ?? "").slice(0, 60) });
  }
  return branches;
}

function commitlintTypes(root: string): string[] {
  const names = [
    "commitlint.config.js", "commitlint.config.cjs", "commitlint.config.mjs", "commitlint.config.ts",
    ".commitlintrc.js", ".commitlintrc.json",
  ];
  for (const n of names) {
    const p = join(root, n);
    if (!existsSync(p)) continue;
    let content = "";
    try {
      content = readFileSync(p, "utf8");
    } catch {
      continue;
    }
    const m = /["']type-enum["']\s*:\s*\[[\s\S]*?\[([\s\S]*?)\]/.exec(content);
    if (m !== null) {
      const types = (m[1] ?? "")
        .split(",")
        .map((s) => s.trim())
        .map((s) =>
          (s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'")) ? s.slice(1, s.length - 1) : "",
        )
        .filter((s) => s !== "");
      if (types.length > 0) return types;
    }
    if (content.includes("config-conventional")) return CONVENTIONAL_DEFAULTS;
  }
  return [];
}

// The third seed mode: not "copy what the parent has" but "make this tree
// produce its own". Detected, never hardcoded — this repo is public.
function bootstrapCommand(root: string): string {
  const steps: string[] = [];
  if (existsSync(join(root, "utils", "secrets.sh"))) steps.push("./utils/secrets.sh");
  else if (existsSync(join(root, "utils", "secrets"))) steps.push("./utils/secrets");
  if (existsSync(join(root, "pnpm-lock.yaml"))) steps.push("pnpm install");
  else if (existsSync(join(root, "bun.lockb")) || existsSync(join(root, "bun.lock"))) steps.push("bun install");
  else if (existsSync(join(root, "yarn.lock"))) steps.push("yarn install");
  else if (existsSync(join(root, "package-lock.json"))) steps.push("npm ci");
  else if (existsSync(join(root, "package.json"))) steps.push("npm install");
  return steps.join(" && ");
}

// Viewer login — one gh call ever, cached; WORK_PR_ME overrides.
function viewerLogin(): string {
  const fromEnv = process.env.WORK_PR_ME ?? "";
  if (fromEnv !== "") return fromEnv;
  const cache = join(CACHE_DIR, "workctl-me");
  try {
    const v = readFileSync(cache, "utf8").trim();
    if (v !== "") return v;
  } catch {
    // cold cache
  }
  if (!have("gh")) return "";
  const r = run("gh", ["api", "user", "--jq", ".login"]);
  if (r.code !== 0) return "";
  const me = r.out.trim();
  try {
    mkdirSync(CACHE_DIR, { recursive: true });
    writeFileSync(cache, me + "\n", { mode: 0o600 });
  } catch {
    // best-effort
  }
  return me;
}

// Open PRs of the repo. --limit 500, not 50: a busy monorepo carries hundreds,
// and the one you want (often an agent-authored branch) fell outside the
// newest 50. Cached with a short TTL and refreshed in the background so the
// picker never blocks on the network — except on a COLD cache, where a one-off
// blocking fetch beats a first run with no PR rows at all.
function prList(ghRepo: string): PrRow[] {
  if (ghRepo === "" || !have("gh")) return [];
  const cache = join(CACHE_DIR, `workctl-prs-${ghRepo.split("/").join("-")}.tsv`);
  const jq = `.[] | [(.number|tostring), .title, .headRefName, .author.login, (if .isDraft then "1" else "0" end)] | join("${US}")`;
  const fetchCmd =
    `gh pr list --repo ${shq(ghRepo)} --state open --limit 500 --json number,title,headRefName,author,isDraft ` +
    `--jq ${shq(jq)} > ${shq(cache)}.tmp 2>/dev/null && mv ${shq(cache)}.tmp ${shq(cache)}`;
  let fresh = false;
  let present = existsSync(cache);
  try {
    fresh = (Date.now() - statSync(cache).mtimeMs) / 1000 < PR_LIST_TTL_S;
  } catch {
    fresh = false;
  }
  try {
    mkdirSync(CACHE_DIR, { recursive: true });
  } catch {
    // best-effort
  }
  if (!present) {
    sh(fetchCmd);
    present = existsSync(cache);
  } else if (!fresh) {
    // scriptc has no detached spawn; `sh -c '… &'` backgrounds and returns.
    sh(`( ${fetchCmd} ) >/dev/null 2>&1 &`);
  }
  if (!present) return [];
  let raw = "";
  try {
    raw = readFileSync(cache, "utf8");
  } catch {
    return [];
  }
  const rows: PrRow[] = [];
  for (const l of lines(raw)) {
    const f = l.split(US);
    const num = Number(f[0] ?? "");
    if (!(num > 0)) continue;
    rows.push({ num, title: f[1] ?? "", head: f[2] ?? "", author: f[3] ?? "", draft: (f[4] ?? "") === "1" });
  }
  return rows;
}

function buildRepoState(cwd: string, all: boolean): RepoState {
  const info = repoInfo(cwd);
  const ids = remoteRepoIds(info.root);
  return {
    repo: info.repo,
    root: info.root,
    ghRepo: ids[0] ?? "",
    defaultBranch: info.def,
    currentBranch: info.current,
    bootstrap: bootstrapCommand(info.root),
    me: viewerLogin(),
    types: commitlintTypes(info.root),
    worktrees: worktreesOf(info.root, info.repo),
    foreign: all ? foreignWorktrees(info.root) : [],
    branches: branchesOf(info.root),
    prs: prList(ids[0] ?? ""),
  };
}

// Serialized as line-per-record text so the fzf callbacks (`__rows`,
// `__preview`) re-read it instead of recomputing a dozen git calls per keystroke.
function serializeRepoState(st: RepoState): string {
  const o: string[] = [];
  o.push(["R", st.repo, st.root, st.ghRepo, st.defaultBranch, st.currentBranch, st.bootstrap, st.me].join(US));
  for (const t of st.types) o.push(["T", t].join(US));
  for (const w of st.worktrees) o.push(["W", w.branch, w.path].join(US));
  for (const w of st.foreign) o.push(["X", w.repo, w.branch, w.path, w.root].join(US));
  for (const b of st.branches) o.push(["B", b.name, b.remote ? "r" : "l", b.date, b.subject].join(US));
  for (const p of st.prs) o.push(["P", String(p.num), p.title, p.head, p.author, p.draft ? "1" : "0"].join(US));
  return o.join("\n") + "\n";
}

function parseRepoState(path: string): RepoState {
  const st: RepoState = {
    repo: "", root: "", ghRepo: "", defaultBranch: "master", currentBranch: "", bootstrap: "", me: "",
    types: [], worktrees: [], foreign: [], branches: [], prs: [],
  };
  let raw = "";
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    return st;
  }
  for (const line of lines(raw)) {
    const f = line.split(US);
    const k = f[0] ?? "";
    if (k === "R") {
      st.repo = f[1] ?? "";
      st.root = f[2] ?? "";
      st.ghRepo = f[3] ?? "";
      st.defaultBranch = f[4] ?? "master";
      st.currentBranch = f[5] ?? "";
      st.bootstrap = f[6] ?? "";
      st.me = f[7] ?? "";
    } else if (k === "T") st.types.push(f[1] ?? "");
    else if (k === "W") st.worktrees.push({ repo: st.repo, root: st.root, branch: f[1] ?? "", path: f[2] ?? "" });
    else if (k === "X") st.foreign.push({ repo: f[1] ?? "", branch: f[2] ?? "", path: f[3] ?? "", root: f[4] ?? "" });
    else if (k === "B") st.branches.push({ name: f[1] ?? "", remote: (f[2] ?? "") === "r", date: f[3] ?? "", subject: f[4] ?? "" });
    else if (k === "P")
      st.prs.push({ num: Number(f[1] ?? "0"), title: f[2] ?? "", head: f[3] ?? "", author: f[4] ?? "", draft: (f[5] ?? "") === "1" });
  }
  return st;
}

function prByHead(st: RepoState, branch: string): PrRow | undefined {
  return st.prs.find((p) => p.head === branch);
}

// ── stage 1: target rows ────────────────────────────────────────────────────
// Hidden key: kind US branch US path US prnum US base
//   kind ∈ wt | local | remote | pr | new | foreign

interface Target {
  kind: string;
  branch: string;
  path: string;
  prNum: number;
  base: string; // new: the ref to branch from
  root: string; // foreign: that repo's root
}

function mkKey(t: Target): string {
  return [t.kind, t.branch, t.path, String(t.prNum), t.base, t.root].join(US);
}

function parseKey(key: string): Target {
  const f = key.split(US);
  return { kind: f[0] ?? "", branch: f[1] ?? "", path: f[2] ?? "", prNum: Number(f[3] ?? "0"), base: f[4] ?? "", root: f[5] ?? "" };
}

function typeEmoji(branch: string): string {
  const cut = branch.indexOf("/");
  return cut === -1 ? "" : TYPE_EMOJI.get(branch.slice(0, cut)) ?? "";
}

// herdr workspace label — byte-identical to `work _label` / `work normalize-label`.
function label(branch: string): string {
  const cut = branch.indexOf("/");
  if (cut === -1) return branch;
  const emoji = TYPE_EMOJI.get(branch.slice(0, cut));
  const rest = branch.slice(cut + 1);
  return emoji === undefined ? branch.split("/").join("-") : `${emoji}${rest}`;
}

// `padEnd` counts UTF-16 units; the emoji here draw two columns.
function displayWidth(s: string): number {
  let w = 0;
  for (let i = 0; i < s.length; i += 1) {
    const c = s.charCodeAt(i);
    if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
      w += 2;
      i += 1;
      continue;
    }
    if (c === 0xfe0f) continue;
    if ((c >= 0x2600 && c <= 0x27bf) || (c >= 0x2b00 && c <= 0x2bff)) {
      w += 2;
      continue;
    }
    w += 1;
  }
  return w;
}

function pad(s: string, width: number): string {
  const gap = width - displayWidth(s);
  return gap > 0 ? s + " ".repeat(gap) : s;
}

function prGlyph(p: PrRow): string {
  return p.draft ? "📝" : "🔀";
}

function stage1Rows(st: RepoState, query: string): string[] {
  const rows: string[] = [];
  const add = (t: Target, glyph: string, display: string, meta: string): void => {
    rows.push(`${mkKey(t)}\t${glyph}  ${pad(display, 52)}\t${meta}`);
  };
  const wtBranches = new Set<string>();
  const prHeads = new Set<string>();

  for (const w of st.worktrees) {
    wtBranches.add(w.branch);
    const pr = prByHead(st, w.branch);
    const meta = pr === undefined ? "worktree" : `worktree · ${prGlyph(pr)}#${pr.num}`;
    add({ kind: "wt", branch: w.branch, path: w.path, prNum: pr === undefined ? 0 : pr.num, base: "", root: "" }, "🌿", w.branch, meta);
  }
  // PRs: yours first, then ones already checked out, then the rest — so the
  // ones you are likely to want surface without scrolling.
  const prs = [...st.prs].sort((a, b) => {
    const ra = a.author === st.me && st.me !== "" ? 0 : wtBranches.has(a.head) ? 1 : 2;
    const rb = b.author === st.me && st.me !== "" ? 0 : wtBranches.has(b.head) ? 1 : 2;
    return ra - rb;
  });
  for (const p of prs) {
    prHeads.add(p.head);
    const mark = wtBranches.has(p.head) ? "● " : "";
    const mine = p.author === st.me && st.me !== "" ? " · mine" : ` · @${p.author}`;
    add({ kind: "pr", branch: p.head, path: "", prNum: p.num, base: "", root: "" }, prGlyph(p), `${mark}#${p.num} ${p.title.slice(0, 44)}`, `${p.head.slice(0, 40)}${mine}`);
  }
  for (const b of st.branches) {
    if (wtBranches.has(b.name)) continue;
    const pr = prByHead(st, b.name);
    const prTxt = pr === undefined ? "" : ` · ${prGlyph(pr)}#${pr.num}`;
    const glyph = b.remote ? "🌐" : typeEmoji(b.name) !== "" ? typeEmoji(b.name) : "✳️";
    add({ kind: b.remote ? "remote" : "local", branch: b.name, path: "", prNum: pr === undefined ? 0 : pr.num, base: "", root: "" }, glyph, b.name, `${b.remote ? "remote" : "local"} · ${b.date}${prTxt}`);
  }
  for (const w of st.foreign) {
    add({ kind: "foreign", branch: w.branch, path: w.path, prNum: 0, base: "", root: w.root }, "🗂", `${w.repo}/${w.branch}`, "other repo · worktree");
  }

  // Create rows for what was typed. Worded "create <name>" so fzf ranks every
  // real branch containing the query above the offer to make a new one, and
  // in a commitlint repo only the prefixed variants are offered (a bare name is
  // a branch that repo rejects at commit time). Two bases: origin/<default>,
  // and HEAD when cwd sits on some other branch — "branch off what I'm on".
  const q = query.trim();
  if (q !== "" && !/^\d+$/.test(q)) {
    const taken = new Set([...wtBranches, ...st.branches.map((b) => b.name)]);
    const names: string[] = st.types.length === 0 || q.includes("/") ? [q] : st.types.map((t) => `${t}/${q}`);
    const bases: string[] = [`origin/${st.defaultBranch}`];
    if (st.currentBranch !== "" && st.currentBranch !== st.defaultBranch) bases.push(st.currentBranch);
    for (const base of bases) {
      for (const name of names) {
        if (taken.has(name)) continue;
        const cut = name.indexOf("/");
        const glyph = cut === -1 ? "➕" : TYPE_EMOJI.get(name.slice(0, cut)) ?? "➕";
        const from = base.startsWith("origin/") ? base : `HEAD (${base})`;
        add({ kind: "new", branch: name, path: "", prNum: 0, base, root: "" }, glyph, `create  ${name}`, `from ${from}`);
      }
    }
  }
  return rows;
}

function stage1Preview(st: RepoState, key: string): string {
  const t = parseKey(key);
  const o: string[] = [];
  const pr = t.prNum > 0 ? st.prs.find((p) => p.num === t.prNum) : undefined;

  if (t.kind === "new") {
    o.push(t.branch);
    o.push("─".repeat(Math.min(46, t.branch.length + 4)));
    o.push(`create   from ${t.base}`);
    o.push(`worktree ${join(TREE_ROOT, `wt-${st.repo}`, t.branch)}`);
    o.push(`label    ${label(t.branch)}`);
    o.push("");
    o.push("enter → pick how to seed the new tree");
    return o.join("\n");
  }

  if (pr !== undefined) {
    o.push(`#${pr.num}  ${pr.title}`);
    o.push("─".repeat(46));
    o.push(`author   @${pr.author}${pr.author === st.me ? " (me)" : ""}`);
    o.push(`state    ${pr.draft ? "draft" : "open"}`);
    o.push(`head     ${pr.head}`);
    if (st.ghRepo !== "") o.push(`url      https://github.com/${st.ghRepo}/pull/${pr.num}`);
    o.push("");
  } else {
    o.push(t.branch);
    o.push("─".repeat(Math.min(46, t.branch.length + 4)));
  }

  const wt = t.kind === "wt" || t.kind === "foreign" ? t.path : st.worktrees.find((w) => w.branch === t.branch)?.path ?? "";
  const root = t.kind === "foreign" ? t.root : st.root;
  const localBranch = st.branches.some((b) => b.name === t.branch && !b.remote) || wt !== "";
  const ref = wt !== "" ? "HEAD" : localBranch ? t.branch : `origin/${t.branch}`;
  const at = wt !== "" ? wt : root;

  if (wt !== "") {
    o.push(`worktree ${wt}`);
    const dirty = git(wt, ["status", "--porcelain"]);
    const n = dirty.code === 0 ? lines(dirty.out).length : 0;
    o.push(`state    ${n === 0 ? "clean" : `dirty · ${n} file(s)`}`);
  } else if (t.kind !== "pr") {
    o.push(`kind     ${t.kind} branch, no worktree yet`);
    o.push(`worktree ${join(TREE_ROOT, `wt-${st.repo}`, t.branch)} (would be)`);
  } else {
    o.push("worktree none yet");
  }
  const counts = git(at, ["rev-list", "--left-right", "--count", `origin/${st.defaultBranch}...${ref}`]);
  if (counts.code === 0) {
    const f = counts.out.trim().split(/\s+/);
    o.push(`vs base  ${f[1] ?? "0"} ahead · ${f[0] ?? "0"} behind`);
  }
  const log = git(at, ["log", "-5", "--format=%h %ad %s", "--date=short", ref]);
  if (log.code === 0 && log.out.trim() !== "") {
    o.push("");
    o.push("recent");
    for (const l of lines(log.out)) o.push(`  ${l}`);
  }
  return o.join("\n");
}

// ── stage 2: PR / branch state ──────────────────────────────────────────────

interface Reviewer {
  key: string;
  kind: string;
  id: string; // what the DELETE endpoint takes: login, or the BARE team slug
  display: string;
  match: string[];
}

interface Thread {
  id: string;
  path: string;
  line: string;
  author: string;
  body: string;
}

interface Check {
  name: string;
  url: string;
}

interface St {
  // target
  kind: string; // pr | branch | new
  hasPr: boolean;
  repo: string; // owner/name ("" if unknown)
  owner: string;
  name: string;
  root: string; // local parent checkout matching `repo` ("" if none)
  repoName: string; // basename of root
  defaultBranch: string;
  bootstrap: string;
  headRefName: string;
  baseRef: string; // new: what to branch from
  worktree: string; // existing checkout of headRefName ("" none)
  isLocalBranch: boolean;
  isRemoteBranch: boolean;
  // pr
  num: number;
  title: string;
  url: string;
  headRefOid: string;
  baseRefName: string;
  isCrossRepository: boolean;
  isDraft: boolean;
  author: string;
  isMine: boolean;
  mergeable: string;
  mergeStateStatus: string;
  reviewDecision: string;
  labels: string[];
  reviewRequests: Reviewer[];
  changesRequestedBy: string[];
  checksTotal: number;
  failed: number;
  failedChecks: Check[];
  pending: number;
  e2eExpected: number;
  e2eRunning: number;
  threadsFetched: boolean;
  unresolved: number;
  unresolvedThreads: Thread[];
  threadsTruncated: boolean;
  threadsTotal: number;
  stackSize: number; // 0 = not in a stack (or not read)
  stackNumber: number;
  stackPosition: number;
  action: string;
}

function emptySt(): St {
  return {
    kind: "branch", hasPr: false, repo: "", owner: "", name: "", root: "", repoName: "", defaultBranch: "master",
    bootstrap: "", headRefName: "", baseRef: "", worktree: "", isLocalBranch: false, isRemoteBranch: false,
    num: 0, title: "", url: "", headRefOid: "", baseRefName: "", isCrossRepository: false, isDraft: false,
    author: "", isMine: false, mergeable: "", mergeStateStatus: "", reviewDecision: "", labels: [],
    reviewRequests: [], changesRequestedBy: [], checksTotal: 0, failed: 0, failedChecks: [], pending: 0,
    e2eExpected: 0, e2eRunning: 0, threadsFetched: false, unresolved: 0, unresolvedThreads: [],
    threadsTruncated: false, threadsTotal: 0, stackSize: 0, stackNumber: 0, stackPosition: 0, action: "",
  };
}

// The 10-branch classifier chain (frozen vocabulary shared with bin/pr-watch
// via workpr.nu). GitHub blocks merge on ANY unresolved conversation, so never
// claim MERGE while threads are open — and "not fetched" is NOT zero, so the
// resolve verdict only fires when the threads were actually read.
function classify(st: St): string {
  let base: string;
  if (st.isDraft && st.failed > 0) base = "draft+CI";
  else if (st.isDraft) base = "draft";
  else if (st.failed > 0) base = "fix CI";
  else if (st.mergeable === "CONFLICTING") base = "conflict";
  else if (st.reviewDecision === "CHANGES_REQUESTED") base = "changes req";
  else if (st.reviewDecision === "REVIEW_REQUIRED") base = "needs review";
  else if (st.e2eExpected > 0 && st.e2eRunning === 0) base = "run e2e";
  else if (st.pending > 0) base = "CI…";
  else if (st.mergeable === "MERGEABLE") base = "MERGE";
  else base = "blocked";
  return base === "MERGE" && st.threadsFetched && st.unresolved > 0 ? "resolve" : base;
}

// One `gh pr view`, shaped by jq into US-separated lines — no JSON parsing on
// this side. statusCheckRollup is a UNION of CheckRun and StatusContext; the
// failure test is deliberately the BROAD one (conclusion OR state).
function readPrView(st: St): void {
  const jq =
    `def f($k; $v): ["F", $k, ($v // "" | tostring)] | join("${US}"); ` +
    `f("number"; .number), f("title"; .title), f("url"; .url), f("isDraft"; .isDraft), f("author"; .author.login), ` +
    `f("mergeable"; .mergeable), f("mergeStateStatus"; .mergeStateStatus), f("reviewDecision"; .reviewDecision), ` +
    `f("headRefName"; .headRefName), f("headRefOid"; .headRefOid), f("baseRefName"; .baseRefName), f("isCrossRepository"; .isCrossRepository), ` +
    `(.labels[]? | ["L", .name] | join("${US}")), ` +
    `(.statusCheckRollup[]? | ["C", (.name // .context // "check"), (.status // ""), (.conclusion // ""), (.state // ""), (.detailsUrl // .targetUrl // "")] | map(tostring) | join("${US}")), ` +
    `(.reviewRequests[]? | ["R", (.__typename // ""), (.login // .slug // ""), (.name // "")] | join("${US}")), ` +
    `(.latestReviews[]? | ["V", (.state // ""), (.author.login // "")] | join("${US}"))`;
  const r = run("gh", ["pr", "view", String(st.num), "--repo", st.repo, "--json", VIEW_FIELDS, "--jq", jq]);
  if (r.code !== 0) die(r.err.trim());
  st.labels = [];
  st.reviewRequests = [];
  st.changesRequestedBy = [];
  st.failedChecks = [];
  st.checksTotal = 0;
  st.failed = 0;
  st.pending = 0;
  st.e2eExpected = 0;
  st.e2eRunning = 0;
  for (const line of lines(r.out)) {
    const f = line.split(US);
    const k = f[0] ?? "";
    if (k === "F") {
      const key = f[1] ?? "";
      const v = f[2] ?? "";
      if (key === "number") st.num = Number(v);
      else if (key === "title") st.title = v;
      else if (key === "url") st.url = v;
      else if (key === "isDraft") st.isDraft = v === "true";
      else if (key === "author") st.author = v;
      else if (key === "mergeable") st.mergeable = v;
      else if (key === "mergeStateStatus") st.mergeStateStatus = v;
      else if (key === "reviewDecision") st.reviewDecision = v;
      else if (key === "headRefName") st.headRefName = v;
      else if (key === "headRefOid") st.headRefOid = v;
      else if (key === "baseRefName") st.baseRefName = v;
      else if (key === "isCrossRepository") st.isCrossRepository = v === "true";
    } else if (k === "L") {
      st.labels.push(f[1] ?? "");
    } else if (k === "C") {
      st.checksTotal += 1;
      const name = f[1] ?? "check";
      const status = f[2] ?? "";
      const conclusion = f[3] ?? "";
      const state = f[4] ?? "";
      const url = f[5] ?? "";
      if (conclusion === "FAILURE" || state === "FAILURE") {
        st.failed += 1;
        st.failedChecks.push({ name, url });
      }
      const running = status !== "" && status !== "COMPLETED";
      if (running || state === "PENDING" || state === "EXPECTED") st.pending += 1;
      if (state === "EXPECTED") st.e2eExpected += 1;
      if (running && /e2e/i.test(name)) st.e2eRunning += 1;
    } else if (k === "R") {
      // gh flattens requestedReviewer: a Team is {__typename, name, slug} with the
      // slug ORG-QUALIFIED (`org/team`) — what --add-reviewer wants but NOT what
      // the DELETE endpoint takes (bare slug). `id` is bare, `match` takes both.
      const typename = f[1] ?? "";
      const loginOrSlug = f[2] ?? "";
      const name = f[3] ?? "";
      if (loginOrSlug === "") continue;
      if (typename === "Team") {
        const parts = loginOrSlug.split("/");
        const bare = parts[parts.length - 1] ?? loginOrSlug;
        st.reviewRequests.push({
          key: `team:${bare}`, kind: "team", id: bare,
          match: [bare, loginOrSlug, `team:${bare}`, `team:${loginOrSlug}`],
          display: name === "" ? loginOrSlug : `${loginOrSlug} (${name})`,
        });
      } else {
        st.reviewRequests.push({ key: `user:${loginOrSlug}`, kind: "user", id: loginOrSlug, match: [loginOrSlug, `user:${loginOrSlug}`], display: loginOrSlug });
      }
    } else if (k === "V") {
      if ((f[1] ?? "") === "CHANGES_REQUESTED" && (f[2] ?? "") !== "" && !st.changesRequestedBy.includes(f[2] ?? ""))
        st.changesRequestedBy.push(f[2] ?? "");
    }
  }
}

// reviewThreads is GraphQL-only. -f (not -F) for the String! variables: -F
// type-coerces, so an all-digit owner would go out as an Int. `num` MUST be -F.
// A thread whose isResolved cannot be read counts as resolved — never mutate a
// thread we cannot see, hence `select(.isResolved == false)` and not `not`.
function readThreads(st: St): void {
  const q =
    "query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){pullRequest(number:$num){reviewThreads(first:100){totalCount pageInfo{hasNextPage} nodes{id isResolved path line originalLine comments(first:1){nodes{author{login} body}}}}}}}";
  const jq =
    `.data.repository.pullRequest.reviewThreads as $t | ` +
    `(["M", ($t.totalCount|tostring), ($t.pageInfo.hasNextPage|tostring)] | join("${US}")), ` +
    `($t.nodes[] | select(.isResolved == false) | ["T", .id, (.path // ""), ((.line // .originalLine // "") | tostring), (.comments.nodes[0].author.login // "?"), ((.comments.nodes[0].body // "") | gsub("[\\n\\r\\t]"; " ") | .[0:240])] | join("${US}"))`;
  const r = run("gh", ["api", "graphql", "-f", `query=${q}`, "-f", `owner=${st.owner}`, "-f", `name=${st.name}`, "-F", `num=${st.num}`, "--jq", jq]);
  if (r.code !== 0) die(`failed to read review threads: ${r.err.trim()}`);
  st.unresolvedThreads = [];
  for (const line of lines(r.out)) {
    const f = line.split(US);
    if ((f[0] ?? "") === "M") {
      st.threadsTotal = Number(f[1] ?? "0");
      st.threadsTruncated = (f[2] ?? "") === "true";
    } else if ((f[0] ?? "") === "T") {
      st.unresolvedThreads.push({ id: f[1] ?? "", path: f[2] ?? "", line: f[3] ?? "", author: f[4] ?? "?", body: f[5] ?? "" });
    }
  }
  st.threadsFetched = true;
  st.unresolved = st.unresolvedThreads.length;
}

// Stack membership, GraphQL-only, its OWN round trip on purpose: `stack` is a
// preview field, and an API that does not know it rejects the WHOLE document —
// folded into the threads query it would take conversation resolution down
// with it. Every failure path is "no stack known", never a die.
function readStack(st: St): void {
  const q =
    "query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){pullRequest(number:$num){stack{number size baseRefName} stackEntry{position}}}}";
  const jq = `.data.repository.pullRequest | if .stack == null then empty else [(.stack.number|tostring), (.stack.size|tostring), ((.stackEntry.position // 0)|tostring)] | join("${US}") end`;
  const r = run("gh", ["api", "graphql", "-f", `query=${q}`, "-f", `owner=${st.owner}`, "-f", `name=${st.name}`, "-F", `num=${st.num}`, "--jq", jq]);
  st.stackSize = 0;
  if (r.code !== 0) return;
  const f = r.out.trim().split(US);
  if (f.length < 3) return;
  st.stackNumber = Number(f[0] ?? "0");
  st.stackSize = Number(f[1] ?? "0");
  st.stackPosition = Number(f[2] ?? "0");
}

// cwd → this PR's checkout. `root` is EMPTY unless cwd really is a checkout of
// `repo`: with `--repo owner/name --pr N` every local action used to run in
// whatever repository the shell sat in. Compares, never falls back.
function localCheckout(st: St, cwd: string): void {
  const top = run("git", ["-C", cwd, "rev-parse", "--show-toplevel"]);
  if (top.code !== 0) return;
  const info = repoInfo(cwd);
  const ids = remoteRepoIds(info.root).map((s) => s.toLowerCase());
  if (st.repo !== "" && !ids.includes(st.repo.toLowerCase())) return;
  st.root = info.root;
  st.repoName = info.repo;
  st.defaultBranch = info.def;
  st.bootstrap = bootstrapCommand(info.root);
  if (st.headRefName !== "") {
    const wt = worktreesOf(info.root, info.repo).find((w) => w.branch === st.headRefName);
    st.worktree = wt === undefined ? "" : wt.path;
    st.isLocalBranch = git(info.root, ["rev-parse", "--verify", "--quiet", `refs/heads/${st.headRefName}`]).code === 0;
    st.isRemoteBranch = git(info.root, ["rev-parse", "--verify", "--quiet", `refs/remotes/origin/${st.headRefName}`]).code === 0;
  }
}

// Order is load-bearing: threads BEFORE classify, so the `resolve` verdict can
// fire; with --no-threads the count stays "not fetched", never 0.
function readPrState(st: St, withThreads: boolean, cwd: string): void {
  readPrView(st);
  if (withThreads) {
    readThreads(st);
    readStack(st);
  } else {
    st.threadsFetched = false;
    st.unresolved = 0;
    st.unresolvedThreads = [];
  }
  st.isMine = st.author !== "" && st.author === viewerLogin();
  st.action = classify(st);
  localCheckout(st, cwd);
}

function ownerName(repo: string): { owner: string; name: string } {
  const parts = repo.split("/");
  if (parts.length !== 2) die(`--repo must be owner/name, got '${repo}'`);
  return { owner: parts[0] ?? "", name: parts[1] ?? "" };
}

function prSt(repo: string, num: number, withThreads: boolean, cwd: string): St {
  const st = emptySt();
  st.kind = "pr";
  st.hasPr = true;
  st.repo = repo;
  const on = ownerName(repo);
  st.owner = on.owner;
  st.name = on.name;
  st.num = num;
  readPrState(st, withThreads, cwd);
  return st;
}

function branchSt(rs: RepoState, t: Target): St {
  const st = emptySt();
  st.kind = t.kind === "new" ? "new" : "branch";
  st.repo = rs.ghRepo;
  if (rs.ghRepo.includes("/")) {
    const on = ownerName(rs.ghRepo);
    st.owner = on.owner;
    st.name = on.name;
  }
  st.root = t.kind === "foreign" ? t.root : rs.root;
  st.repoName = basename(st.root);
  st.defaultBranch = rs.defaultBranch;
  st.bootstrap = t.kind === "foreign" ? bootstrapCommand(t.root) : rs.bootstrap;
  st.headRefName = t.branch;
  st.baseRef = t.base;
  st.worktree = t.kind === "wt" || t.kind === "foreign" ? t.path : "";
  st.isLocalBranch = t.kind === "local" || t.kind === "wt" || t.kind === "foreign";
  st.isRemoteBranch = t.kind === "remote";
  st.url = rs.ghRepo === "" ? "" : `https://github.com/${rs.ghRepo}/tree/${t.branch}`;
  st.title = t.branch;
  return st;
}

// ── worktree plumbing ───────────────────────────────────────────────────────

function worktreePathFor(repoName: string, branch: string): string {
  return join(TREE_ROOT, `wt-${repoName}`, branch);
}

// .env + node_modules from the parent checkout via APFS clonefile (`cp -c`):
// instant, no extra disk, keeps pnpm's symlink farm. Linux has no -c → retry.
function seedClone(parent: string, wt: string): number {
  const r = git(parent, ["ls-files", "--others", "--ignored", "--exclude-standard", "--directory"]);
  if (r.code !== 0) return 0;
  let copied = 0;
  for (const raw of lines(r.out)) {
    const rel = trimSlash(raw);
    const base = basename(rel);
    if (base !== "node_modules" && base !== ".env" && !base.startsWith(".env.")) continue;
    const src = join(parent, rel);
    const dst = join(wt, rel);
    if (!existsSync(src) || existsSync(dst)) continue;
    try {
      mkdirSync(dirname(dst), { recursive: true });
    } catch {
      continue;
    }
    if (run("cp", ["-cR", src, dst]).code !== 0 && run("cp", ["-R", src, dst]).code !== 0) continue;
    copied += 1;
  }
  return copied;
}

// Pre-layout side effects every worktree gets: work-scoped skills, seeded
// claude MCP defaults, and the bare numbered tab renamed.
function layoutPrep(ws: string, cwd: string): void {
  if (have("place-work-skills")) run("place-work-skills", [cwd]);
  if (have("claude-mcp-defaults")) run("claude-mcp-defaults", [cwd]);
  if (ws === "") return;
  const tabs = run("herdr", ["tab", "list", "--workspace", ws]);
  for (const chunk of jsonChunks(tabs.out, "tabs")) {
    const id = jsonField(chunk, "tab_id");
    const lbl = jsonField(chunk, "label");
    if (id !== "" && /^[0-9]+$/.test(lbl)) run("herdr", ["tab", "rename", id, "\uf120  nu"]);
  }
}

// Full layout = prep + one bare claude tab, idempotent on the label. The agent
// path must NOT call this: it would either drop the brief or start two sessions.
function applyLayout(ws: string, cwd: string): void {
  layoutPrep(ws, cwd);
  if (ws === "") return;
  const tabs = run("herdr", ["tab", "list", "--workspace", ws]);
  for (const chunk of jsonChunks(tabs.out, "tabs")) {
    if (jsonField(chunk, "label").includes("claude")) return;
  }
  const r = run("herdr", ["tab", "create", "--workspace", ws, "--cwd", cwd, "--label", "\u{f06a9}  claude", "--no-focus"]);
  const pane = herdrPaneId(r.out);
  if (pane !== "") run("herdr", ["pane", "run", pane, "claude"]);
}

// The bootstrap seed runs in its own tab: minutes of output Greg wants to see.
function seedBootstrap(ws: string, cwd: string, cmd: string): boolean {
  if (cmd === "" || ws === "") return false;
  const r = run("herdr", ["tab", "create", "--workspace", ws, "--cwd", cwd, "--label", "\u{f0493}  bootstrap", "--focus"]);
  const pane = herdrPaneId(r.out);
  if (pane === "") return false;
  run("herdr", ["pane", "run", pane, cmd]);
  return true;
}

function herdrWsFor(root: string, wtPath: string): string {
  const list = run("herdr", ["worktree", "list", "--cwd", root, "--json"]);
  for (const chunk of jsonChunks(list.out, "worktrees")) {
    if (jsonField(chunk, "path") === wtPath) return jsonField(chunk, "open_workspace_id");
  }
  return "";
}

// Open-or-create the worktree for st.headRefName. Returns {ws, path}. Handles:
//   existing checkout → open; fork PR → detached add + `gh pr checkout` (with
//   rollback — an orphan detached tree at the canonical path blocks the retry);
//   remote/PR branch → herdr create tracking origin/<head>; new → --base.
function ensureWorktree(st: St, focus: boolean): { ws: string; path: string; created: boolean } {
  if (!have("herdr")) die("herdr required: brew install herdr");
  if (st.root === "") die(`worktree/agent intents need a local checkout of ${st.repo === "" ? "this repo" : st.repo} — cd into it first, or pick a gh-only action`);
  if (st.headRefName === "") die(st.hasPr ? `PR #${st.num} has no head branch.` : "no branch name");
  const parent = st.root;
  const head = st.headRefName;
  const lbl = label(head);
  const focusFlag = focus ? "--focus" : "--no-focus";

  if (st.worktree !== "") {
    const r = run("herdr", ["worktree", "open", "--cwd", parent, "--path", st.worktree, "--label", lbl, focusFlag, "--json"]);
    if (r.code !== 0) die(`herdr worktree open failed: ${r.err.trim()}`);
    return { ws: herdrWorkspaceId(r.out), path: st.worktree, created: false };
  }

  const wtPath = worktreePathFor(st.repoName, head);
  if (st.hasPr && st.isCrossRepository) {
    const a = git(parent, ["worktree", "add", "--detach", wtPath]);
    if (a.code !== 0) die(`worktree add failed: ${a.err.trim()}`);
    const co = sh(`cd ${shq(wtPath)} && gh pr checkout ${st.num}`);
    if (co.code !== 0) {
      git(parent, ["worktree", "remove", wtPath, "--force"]);
      die(`gh pr checkout #${st.num} failed: ${co.err.trim()}`);
    }
    if (git(wtPath, ["branch", "--show-current"]).out.trim() === "") git(wtPath, ["checkout", "-B", head]);
    const o = run("herdr", ["worktree", "open", "--cwd", parent, "--path", wtPath, "--label", lbl, focusFlag, "--json"]);
    return { ws: herdrWorkspaceId(o.out), path: wtPath, created: true };
  }

  const isNew = st.kind === "new";
  let args: string[];
  if (isNew) {
    const base = st.baseRef === "" ? `origin/${st.defaultBranch}` : st.baseRef;
    if (base.startsWith("origin/")) git(parent, ["fetch", "origin", base.slice("origin/".length)]);
    args = ["worktree", "create", "--cwd", parent, "--branch", head, "--base", base, "--path", wtPath, "--label", lbl, focusFlag, "--json"];
  } else if (st.isLocalBranch) {
    args = ["worktree", "create", "--cwd", parent, "--branch", head, "--path", wtPath, "--label", lbl, focusFlag, "--json"];
  } else {
    git(parent, ["fetch", "origin", head]);
    args = ["worktree", "create", "--cwd", parent, "--branch", head, "--base", `origin/${head}`, "--path", wtPath, "--label", lbl, focusFlag, "--json"];
  }
  const r = run("herdr", args);
  if (r.code !== 0) die(`herdr worktree create failed: ${r.err.trim()}`);
  // `worktree add -b X origin/main` makes git track origin/main via
  // autoSetupMerge, so ahead/behind counts against main forever. Drop it; the
  // first push sets origin/<branch> through push.autoSetupRemote.
  if (isNew) git(wtPath, ["branch", "--unset-upstream", head]);
  let ws = herdrWorkspaceId(r.out);
  if (ws === "") ws = herdrWsFor(parent, wtPath);
  return { ws, path: wtPath, created: true };
}

// ── actions — every one returns a failure count ─────────────────────────────

interface Ctx {
  yes: boolean;
  dry: boolean;
  focus: boolean;
  labels: string[];
  drop: string;
  cwd: string;
}

function confirm(summary: string, yes: boolean): boolean {
  if (yes) return true;
  if (!isTty()) die(`${summary} needs --yes when stdin is not a TTY`);
  err(summary);
  return ask("proceed? [y/N]: ").toLowerCase() === "y";
}

function ghOk(args: string[], failMsg: string): number {
  const r = run("gh", args);
  if (r.code !== 0) {
    err(`${failMsg}: ${r.err.trim()}`);
    return 1;
  }
  return 0;
}

function doResolve(st: St, ctx: Ctx): number {
  if (st.threadsTruncated) err("more than 100 review threads here — only the first 100 were handled; resolve the tail in the web UI");
  if (st.unresolvedThreads.length === 0) {
    out("nothing to resolve");
    return 0;
  }
  if (ctx.dry) {
    out(`[dry-run] gh api graphql resolveReviewThread × ${st.unresolvedThreads.length}`);
    return 0;
  }
  const m = "mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}";
  let failed = 0;
  for (const t of st.unresolvedThreads) {
    // gh exits non-zero on GraphQL errors, but a 200-with-errors body would slip
    // past the exit code alone — so ask jq for the error messages too.
    const r = run("gh", ["api", "graphql", "-f", `query=${m}`, "-f", `id=${t.id}`, "--jq", '(.errors // []) | map(.message) | join("; ")']);
    const why = r.out.trim();
    if (r.code !== 0 || why !== "") {
      failed += 1;
      err(`failed ${t.id}: ${why !== "" ? why : r.err.trim()}`);
    }
  }
  out(`resolved ${st.unresolvedThreads.length - failed}/${st.unresolvedThreads.length} conversations`);
  return failed;
}

// `ctx.labels` is the ONE snapshot from the single `gh pr view`, reused for every
// toggle in a TAB batch — deliberately not refetched between toggles.
function doLabel(st: St, lbl: string, ctx: Ctx): number {
  const on = ctx.labels.includes(lbl);
  const flag = on ? "--remove-label" : "--add-label";
  if (ctx.dry) {
    out(`[dry-run] gh pr edit ${st.num} --repo ${st.repo} ${flag} ${lbl}`);
    return 0;
  }
  if (ghOk(["pr", "edit", String(st.num), "--repo", st.repo, flag, lbl], `${flag} ${lbl} failed`) !== 0) return 1;
  out(on ? `- ${lbl}` : `+ ${lbl}`);
  return 0;
}

// `gh label list --json name` is a TOP-LEVEL ARRAY. --limit 1000 is
// load-bearing: the default 30 cuts label-heavy repos and turns a real label
// into a bogus "does not exist".
function repoLabels(repo: string): string[] {
  const r = run("gh", ["label", "list", "--repo", repo, "--json", "name", "--limit", "1000", "--jq", ".[].name"]);
  if (r.code !== 0) die(r.err.trim());
  return lines(r.out);
}

// Validate every label BEFORE the first write: a bad key in a TAB multi-select
// would otherwise half-apply the batch.
function validateLabels(repo: string, wanted: string[]): void {
  if (wanted.length === 0) return;
  const known = repoLabels(repo);
  const missing = wanted.filter((n) => !known.includes(n));
  if (missing.length > 0) die(missing.map((n) => `label '${n}' does not exist in ${repo}`).join("\n"));
}

function doDiff(st: St, ctx: Ctx): number {
  if (st.hasPr) {
    if (ctx.dry) {
      out(`[dry-run] gh pr diff ${st.num} --repo ${st.repo}`);
      return 0;
    }
    runTty("gh", ["pr", "diff", String(st.num), "--repo", st.repo]);
    return 0;
  }
  if (st.kind === "new") {
    err("nothing to diff — that branch does not exist yet");
    return 0;
  }
  const at = st.worktree !== "" ? st.worktree : st.root;
  const ref = st.worktree !== "" ? "HEAD" : st.isLocalBranch ? st.headRefName : `origin/${st.headRefName}`;
  if (ctx.dry) {
    out(`[dry-run] git -C ${at} diff origin/${st.defaultBranch}...${ref}`);
    return 0;
  }
  runTty("git", ["-C", at, "diff", `origin/${st.defaultBranch}...${ref}`]);
  return 0;
}

function doWeb(st: St, ctx: Ctx): number {
  if (st.hasPr) {
    if (ctx.dry) {
      out(`[dry-run] gh pr view ${st.num} --repo ${st.repo} --web`);
      return 0;
    }
    return ghOk(["pr", "view", String(st.num), "--repo", st.repo, "--web"], "open in browser failed");
  }
  if (ctx.dry) {
    out(`[dry-run] gh browse --repo ${st.repo} --branch ${st.headRefName}`);
    return 0;
  }
  return ghOk(["browse", "--repo", st.repo, "--branch", st.headRefName], "open in browser failed");
}

function doCopy(st: St, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] copy ${st.url}`);
    return 0;
  }
  if (have("pbcopy")) sh(`printf '%s' ${shq(st.url)} | pbcopy`);
  out(st.url);
  return 0;
}

function doBlockers(st: St): number {
  out(`#${st.num} ${st.title}`);
  out(`  mergeStateStatus : ${st.mergeStateStatus}`);
  out(`  mergeable        : ${st.mergeable}`);
  out(`  reviewDecision   : ${st.reviewDecision}`);
  const cap = st.threadsTruncated ? "+ (capped at 100)" : "";
  out(`  unresolved       : ${st.threadsFetched ? `${st.unresolved}${cap}` : "not fetched"}`);
  out(`  checks           : ${st.failed} failed · ${st.pending} pending · ${st.checksTotal} total`);
  out(`  draft            : ${st.isDraft}`);
  out("");
  const b: string[] = [];
  if (st.isDraft) b.push("PR is a draft — 📤 ready for review");
  if (st.mergeable === "CONFLICTING") b.push("merge conflict — ⬆️ update branch, or rebase by hand");
  if (st.mergeStateStatus === "BEHIND") b.push("branch is behind base — ⬆️ update branch");
  if (st.failed > 0) b.push(`${st.failed} failing check(s) — 🔍 logs / ♻️ rerun / 🔧 fix-ci`);
  if (st.pending > 0) b.push(`${st.pending} check(s) still running — 👁 watch`);
  if (st.e2eExpected > 0 && st.e2eRunning === 0) b.push("e2e expected but not running — 🏷 run_e2e");
  if (st.unresolved > 0) b.push(`${st.unresolved} unresolved conversation(s) — ✅ resolve / 💬 respond`);
  if (st.reviewDecision === "CHANGES_REQUESTED") b.push("changes requested — 🔔 re-review after fixing");
  if (st.reviewDecision === "REVIEW_REQUIRED") b.push("review required — waiting on reviewers");
  if (b.length === 0) out("no blockers found — 🚀 merge should go through");
  else for (const x of b) out(`✗ ${x}`);
  return 0;
}

// `--undo` is plan-gated, so only the draft direction can fail that way.
function doReady(st: St, ctx: Ctx): number {
  if (st.isDraft) {
    if (ctx.dry) {
      out(`[dry-run] gh pr ready ${st.num} --repo ${st.repo}`);
      return 0;
    }
    if (ghOk(["pr", "ready", String(st.num), "--repo", st.repo], "ready for review failed") !== 0) return 1;
    out(`📤 #${st.num} ready for review`);
    return 0;
  }
  if (ctx.dry) {
    out(`[dry-run] gh pr ready ${st.num} --repo ${st.repo} --undo`);
    return 0;
  }
  if (ghOk(["pr", "ready", String(st.num), "--repo", st.repo, "--undo"], "back to draft failed (plan may not support draft conversion)") !== 0) return 1;
  out(`📥 #${st.num} back to draft`);
  return 0;
}

function doMerge(st: St, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] gh pr merge ${st.num} --repo ${st.repo} --squash --auto`);
    return 0;
  }
  if (!confirm(`merge #${st.num} --squash --auto into ${st.baseRefName}?`, ctx.yes)) {
    err("merge skipped");
    return 0;
  }
  if (ghOk(["pr", "merge", String(st.num), "--repo", st.repo, "--squash", "--auto"], "merge failed") !== 0) return 1;
  out(`🚀 #${st.num} squash+auto merge armed`);
  return 0;
}

// `gh pr update-branch` defaults to a MERGE COMMIT; --rebase rewrites history
// and force-pushes, so its confirm says so.
function doUpdateBranch(st: St, rebase: boolean, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] gh pr update-branch ${st.num} --repo ${st.repo}${rebase ? " --rebase" : ""}`);
    return 0;
  }
  if (rebase && !confirm(`update #${st.num} by REBASE onto ${st.baseRefName} — this force-pushes ${st.headRefName}`, ctx.yes)) {
    err("update skipped");
    return 0;
  }
  const args = ["pr", "update-branch", String(st.num), "--repo", st.repo];
  if (rebase) args.push("--rebase");
  if (ghOk(args, "update-branch failed") !== 0) return 1;
  out(`⬆️ #${st.num} updated from ${st.baseRefName}`);
  return 0;
}

// `gh pr edit --add-reviewer` re-requests an existing reviewer.
function doReReview(st: St, ctx: Ctx): number {
  if (st.changesRequestedBy.length === 0) {
    out("no changes-requested reviewers");
    return 0;
  }
  const joined = st.changesRequestedBy.join(",");
  if (ctx.dry) {
    out(`[dry-run] gh pr edit ${st.num} --repo ${st.repo} --add-reviewer ${joined}`);
    return 0;
  }
  if (ghOk(["pr", "edit", String(st.num), "--repo", st.repo, "--add-reviewer", joined], "re-review failed") !== 0) return 1;
  out(`🔔 re-requested: ${joined}`);
  return 0;
}

// --drop takes comma-separated team slugs / logins; empty --drop on a TTY opens
// a sub-picker. -X DELETE must be EXPLICIT: any -f auto-switches to POST, which
// would ADD the reviewers instead of removing them.
function doTrim(st: St, ctx: Ctx): number {
  const rows = st.reviewRequests;
  if (rows.length === 0) {
    out("no requested reviewers");
    return 0;
  }
  const endpoint = `repos/${st.owner}/${st.name}/pulls/${st.num}/requested_reviewers`;
  const displays = rows.map((r) => r.display).join(", ");
  if (ctx.dry && ctx.drop === "") {
    out(`[dry-run] pick reviewers to drop from (${displays}) → gh api -X DELETE ${endpoint}`);
    return 0;
  }
  let picked: Reviewer[];
  if (ctx.drop !== "") {
    const wanted = ctx.drop.split(",").map((d) => d.trim()).filter((d) => d !== "");
    const missing = wanted.filter((w) => !rows.some((r) => r.match.includes(w)));
    if (missing.length > 0) {
      err(`not a requested reviewer: ${missing.join(", ")} — requested: ${displays}`);
      return 1;
    }
    picked = rows.filter((r) => wanted.some((w) => r.match.includes(w)));
  } else {
    const keys = fzfPick(rows.map((r) => `${r.key}\t✂️  ${pad(r.display, 34)} [${r.kind}]`), "trim reviewer> ", `${st.repo} #${st.num} — TAB for multiple`, true);
    picked = rows.filter((r) => keys.includes(r.key));
  }
  if (picked.length === 0) {
    err("nothing to trim");
    return 0;
  }
  const args: string[] = [];
  for (const r of picked) args.push("-f", r.kind === "team" ? `team_reviewers[]=${r.id}` : `reviewers[]=${r.id}`);
  if (ctx.dry) {
    out(`[dry-run] gh api -X DELETE ${endpoint} ${args.join(" ")}`);
    return 0;
  }
  if (ghOk(["api", "-X", "DELETE", endpoint, ...args], "trim failed") !== 0) return 1;
  out(`✂️ trimmed: ${picked.map((r) => r.display).join(", ")}`);
  return 0;
}

// Actions run id for the PR head. Only `/actions/runs/(\d+)` counts — a
// non-Actions check's link is .../runs/<check-run-id>, which 404s on `gh run`.
function runId(st: St): string {
  if (st.headRefOid !== "") {
    const jq = `(map(select(.event == "pull_request")) + .) | .[0].databaseId // empty`;
    const r = run("gh", ["run", "list", "--repo", st.repo, "--commit", st.headRefOid, "--json", "databaseId,event", "-L", "20", "--jq", jq]);
    if (r.code === 0 && r.out.trim() !== "") return r.out.trim();
  }
  for (const c of st.failedChecks) {
    const m = /\/actions\/runs\/([0-9]+)/.exec(c.url);
    if (m !== null) return m[1] ?? "";
  }
  return "";
}

function doLogs(st: St, ctx: Ctx): number {
  const id = runId(st);
  if (id === "") {
    err(`no Actions run found for ${st.headRefOid} — open the check in the browser`);
    return 1;
  }
  if (ctx.dry) {
    out(`[dry-run] gh run view ${id} --repo ${st.repo} --log-failed`);
    return 0;
  }
  runTty("gh", ["run", "view", id, "--repo", st.repo, "--log-failed"]);
  return 0;
}

function doRerun(st: St, ctx: Ctx): number {
  const id = runId(st);
  if (id === "") {
    err(`no Actions run found for ${st.headRefOid} — rerun from the browser`);
    return 1;
  }
  if (ctx.dry) {
    out(`[dry-run] gh run rerun ${id} --repo ${st.repo} --failed`);
    return 0;
  }
  if (ghOk(["run", "rerun", id, "--repo", st.repo, "--failed"], "rerun failed") !== 0) return 1;
  out(`♻️ rerunning failed jobs of run ${id}`);
  return 0;
}

// --fail-fast WITHOUT --watch is a hard error. Exit 8 = "checks pending", which
// is not a failure of the watch; exit 1 covers "failed" AND "no checks".
function doWatch(st: St, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] gh pr checks ${st.num} --repo ${st.repo} --watch --fail-fast`);
    return 0;
  }
  const code = runTty("gh", ["pr", "checks", String(st.num), "--repo", st.repo, "--watch", "--fail-fast"]);
  if (code === 8) err("checks still pending");
  else if (code !== 0) err(`checks not green (exit ${code})`);
  return 0;
}

// Commits and PUSHES, so the local check comes first and runs on --dry-run too.
function doKick(st: St, ctx: Ctx): number {
  if (st.root === "" || st.worktree === "") {
    err(`kick needs ${st.headRefName} checked out somewhere in ${st.repo} — pick 🌱/👓 worktree first`);
    return 1;
  }
  if (ctx.dry) {
    out(`[dry-run] git -C ${st.worktree} commit --allow-empty -m 'chore: kick CI'; git push`);
    return 0;
  }
  if (!confirm(`kick CI on ${st.headRefName} — empty commit + push from ${st.worktree}?`, ctx.yes)) {
    err("kick skipped");
    return 0;
  }
  const c = git(st.worktree, ["commit", "--allow-empty", "-m", "chore: kick CI"]);
  if (c.code !== 0) {
    err(`empty commit failed: ${c.err.trim()}`);
    return 1;
  }
  const p = git(st.worktree, ["push"]);
  if (p.code !== 0) {
    err(`push failed: ${p.err.trim()}`);
    return 1;
  }
  out(`🦵 kicked CI on ${st.headRefName}`);
  return 0;
}

// ── stack — thin `gh stack` passthrough (no --repo on any subcommand) ───────

interface StackRow {
  id: string;
  glyph: string;
  label: string;
}

const STACK_ROWS: StackRow[] = [
  { id: "stack:view", glyph: "🧱", label: "view stack" },
  { id: "stack:add", glyph: "🥞", label: "new branch on top of this PR (starts a stack if needed)" },
  { id: "stack:submit", glyph: "📤", label: "submit stack (--auto)" },
  { id: "stack:sync", glyph: "🔄", label: "sync stack (fetch + cascade rebase + atomic push)" },
  { id: "stack:rebase", glyph: "♻️", label: "rebase stack" },
  { id: "stack:merge", glyph: "🚀", label: "merge stack up to this PR" },
];

function ghIn(cwd: string, args: string[]): Run {
  return sh(`cd ${shq(cwd)} && gh ${args.map((a) => shq(a)).join(" ")}`);
}

function doStack(st: St, id: string, ctx: Ctx): number {
  const sub = id.startsWith("stack:") ? id.slice("stack:".length) : id;
  if (st.root === "" || st.worktree === "") {
    err(`gh stack ${sub} has no --repo flag — pick a worktree first`);
    return 1;
  }
  const wt = st.worktree;
  if (ctx.dry) {
    out(`[dry-run] cd ${wt}; gh stack ${sub}`);
    return 0;
  }
  if (sub === "view") {
    const r = ghIn(wt, ["stack", "view"]);
    out(r.out);
    // exits 2 when the branch is not in a stack — gh's generic "cancelled" code
    if (r.code === 2) {
      out("not part of a stack");
      return 0;
    }
    if (r.code !== 0) {
      err(r.err.trim());
      return 1;
    }
    return 0;
  }
  if (sub === "add") {
    if (!isTty()) {
      err("stack:add needs a TTY to name the new branch");
      return 1;
    }
    const name = ask("new branch on top: ");
    if (name === "") {
      err("no branch name");
      return 0;
    }
    // `gh stack checkout <pr>` only works for a PR ALREADY in a stack; for a lone
    // PR fall back to `gh stack init <head>`, which is how a stack gets started.
    const co = ghIn(wt, ["stack", "checkout", String(st.num)]);
    if (co.code !== 0) {
      const init = ghIn(wt, ["stack", "init", st.headRefName]);
      if (init.code !== 0) {
        err(`gh stack checkout failed: ${co.err.trim()}`);
        err(`gh stack init ${st.headRefName} also failed: ${init.err.trim()}`);
        return 1;
      }
      out(`🧱 started a stack at ${st.headRefName}`);
    }
    const a = ghIn(wt, ["stack", "add", name]);
    if (a.code !== 0) {
      err(`gh stack add failed: ${a.err.trim()}`);
      return 1;
    }
    out(`🥞 ${name} added on top of #${st.num}`);
    return 0;
  }
  if (sub === "sync" && !confirm(`sync the whole stack from ${wt} — cascade rebase + force-with-lease push?`, ctx.yes)) {
    err("sync skipped");
    return 0;
  }
  if (sub === "merge" && !confirm(`merge the stack up to and including #${st.num} — all-or-nothing?`, ctx.yes)) {
    err("stack merge skipped");
    return 0;
  }
  const args =
    sub === "submit" ? ["stack", "submit", "--auto"]
    : sub === "merge" ? ["stack", "merge", String(st.num), "--yes"]
    : sub === "sync" || sub === "rebase" ? ["stack", sub]
    : [];
  if (args.length === 0) {
    err(`unknown stack action: ${id}`);
    return 1;
  }
  const r = ghIn(wt, args);
  out(r.out);
  if (r.code !== 0) {
    err(`gh stack ${sub} failed: ${r.err.trim()}`);
    return 1;
  }
  return 0;
}

function doStackPick(st: St, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] stack sub-picker for #${st.num}: ${STACK_ROWS.map((r) => r.id).join(", ")}`);
    return 0;
  }
  const keys = fzfPick(STACK_ROWS.map((r) => `${r.id}\t${r.glyph}  ${r.label}`), "stack> ", `${st.repo} #${st.num} — gh stack (preview)`, true);
  let f = 0;
  for (const k of keys) f += doStack(st, k, ctx);
  return f;
}

// ── worktree + agent rows ───────────────────────────────────────────────────

// seed: clone | none | bootstrap
function doWorktree(st: St, seed: string, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] worktree (${seed}) → ${st.headRefName}${st.hasPr ? ` (#${st.num})` : ""}`);
    return 0;
  }
  const wt = ensureWorktree(st, ctx.focus);
  if (wt.created && seed === "clone") {
    const n = seedClone(st.root, wt.path);
    if (n > 0) err(`🌱 seeded ${n} untracked path(s) (env + node_modules)`);
  }
  applyLayout(wt.ws, wt.path);
  if (seed === "bootstrap") {
    if (st.bootstrap === "") err("⚠️  no bootstrap detected (utils/secrets.sh / lockfile) — nothing run");
    else if (seedBootstrap(wt.ws, wt.path, st.bootstrap)) err(`🚀 bootstrap tab: ${st.bootstrap}`);
  }
  err(wt.created ? `✅ ${st.headRefName} → ${wt.path}` : `↪︎  opened ${label(st.headRefName)}`);
  return 0;
}

function doRemove(st: St, ctx: Ctx): number {
  if (st.worktree === "") {
    err(`no worktree for ${st.headRefName} — nothing to remove`);
    return 0;
  }
  const dirty = git(st.worktree, ["status", "--porcelain"]);
  if (dirty.code === 0 && lines(dirty.out).length > 0 && !ctx.yes) {
    if (!confirm(`⚠️  ${st.headRefName} has uncommitted changes — remove anyway?`, false)) {
      err("remove skipped");
      return 0;
    }
  }
  if (ctx.dry) {
    out(`[dry-run] remove worktree ${st.worktree} + branch ${st.headRefName}`);
    return 0;
  }
  const ws = herdrWsFor(st.root, st.worktree);
  if (ws !== "") {
    const r = run("herdr", ["worktree", "remove", "--workspace", ws, "--force"]);
    if (r.code !== 0) {
      err(`herdr worktree remove failed: ${r.err.trim()}`);
      return 1;
    }
  } else {
    const r = git(st.root, ["worktree", "remove", st.worktree, "--force"]);
    if (r.code !== 0) {
      err(`git worktree remove failed: ${r.err.trim()}`);
      return 1;
    }
  }
  if (git(st.root, ["branch", "-d", st.headRefName]).code !== 0)
    err(`⚠️  branch ${st.headRefName} not fully merged — \`git -C ${st.root} branch -D ${st.headRefName}\` to force.`);
  err(`✅ removed ${st.headRefName}`);
  return 0;
}

function doCreatePr(st: St, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] gh pr create --repo ${st.repo} --head ${st.headRefName} --web`);
    return 0;
  }
  return ghOk(["pr", "create", "--repo", st.repo, "--head", st.headRefName, "--web"], "gh pr create failed");
}

// Brief cache keyed on repo AND number: PR #5 exists in every repo.
function briefPath(st: St): string {
  return join(CACHE_DIR, `pr-brief-${st.repo.split("/").join("-")}-${st.num}.md`);
}

// pr-brief's stdout, cached so the pane only needs a path. --repo is mandatory:
// pr-brief's own default is WORK_MAIN_REPO and ignores cwd.
function writeBrief(st: St, intent: string): string {
  const p = briefPath(st);
  const r = run("pr-brief", [String(st.num), "--repo", st.repo, "--intent", intent]);
  if (r.code !== 0) {
    err(`pr-brief failed: ${r.err.trim()}`);
    return "";
  }
  try {
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, r.out, { mode: 0o600 });
  } catch {
    err(`brief not written to ${p}`);
    return "";
  }
  return p;
}

// Always a FRESH tab: `herdr pane run` TYPES the line into whatever owns the
// pane, so reusing a tab that already runs claude would paste it as prose. The
// label contains "claude" so a later applyLayout does not add a bare one.
// The command is ONE argv element of nushell syntax — `pane run` joins argv
// with spaces, so a `bash -lc '…'` wrapper would arrive split.
function agentTab(ws: string, cwd: string, intent: string, brief: string): number {
  const cmd = `claude (open --raw "${brief}")`;
  const r = run("herdr", ["tab", "create", "--workspace", ws, "--cwd", cwd, "--label", `\u{f06a9}  claude ${intent}`, "--no-focus"]);
  const pane = herdrPaneId(r.out);
  if (pane === "") {
    err(`herdr tab create returned no pane: ${r.err.trim()}`);
    return 1;
  }
  run("herdr", ["pane", "run", pane, cmd]);
  return 0;
}

// mode: clone | none (worktree seed) | nowt (no worktree — bump)
function doAgent(st: St, intent: string, mode: string, ctx: Ctx): number {
  if (ctx.dry) {
    out(`[dry-run] pr-brief ${st.num} --repo ${st.repo} --intent ${intent} → ${briefPath(st)}, then a fresh claude tab (worktree: ${mode})`);
    return 0;
  }
  if (mode === "nowt") {
    const brief = writeBrief(st, intent);
    if (brief === "") return 1;
    const ws = process.env.HERDR_WORKSPACE_ID ?? "";
    if (ws === "") {
      out(`claude (open --raw "${brief}")`);
      return 0;
    }
    return agentTab(ws, ctx.cwd, intent, brief);
  }
  const wt = ensureWorktree(st, ctx.focus);
  if (wt.created && mode === "clone") seedClone(st.root, wt.path);
  layoutPrep(wt.ws, wt.path);
  const brief = writeBrief(st, intent);
  if (brief === "") return 1;
  const rc = agentTab(wt.ws, wt.path, intent, brief);
  err(`✅ #${st.num} → ${st.headRefName} · claude ${intent}`);
  return rc;
}

// ── registry ────────────────────────────────────────────────────────────────
// id      machine key (hidden fzf field 1, and the --action value)
// group   gh | worktree | agent   (dispatch order: gh → worktree → ≤1 agent)
// kind    "label" marks a row whose id IS a repo label — the pre-write
//         validation reads this, so a new label row needs no second list
// Every hook is REQUIRED (scriptc cannot lower an optional closure field):
// state/glyphOf/labelOf return "" for "no override".

interface Row {
  id: string;
  group: string;
  kind: string;
  glyph: string;
  label: string;
  glyphOf: (st: St) => string;
  labelOf: (st: St) => string;
  state: (st: St) => string;
  relevant: (st: St) => boolean;
  run: (st: St, ctx: Ctx) => number;
}

const NONE = (_st: St): string => "";

function row(
  id: string,
  group: string,
  glyph: string,
  lbl: string,
  relevant: (st: St) => boolean,
  runFn: (st: St, ctx: Ctx) => number,
  state: (st: St) => string,
  kind: string,
  glyphOf: (st: St) => string,
  labelOf: (st: St) => string,
): Row {
  return { id, group, kind, glyph, label: lbl, glyphOf, labelOf, state, relevant, run: runFn };
}

function registry(): Row[] {
  const pr = (st: St): boolean => st.hasPr;
  const unres = (st: St): string => `${st.unresolved}${st.threadsTruncated ? "+" : ""} unresolved`;
  return [
    row("resolve", "gh", "✅", "resolve all conversations", (st) => st.hasPr && st.unresolved > 0, doResolve, unres, "", NONE, NONE),
    row("review", "agent", "👀", "review this PR", (st) => st.hasPr && !st.isMine, (st, c) => doAgent(st, "review", "none", c), NONE, "", NONE, NONE),
    row("respond", "agent", "💬", "answer reviewers", (st) => st.hasPr && st.isMine && st.unresolved > 0, (st, c) => doAgent(st, "respond", "clone", c), unres, "", NONE, NONE),
    row("fix-ci", "agent", "🔧", "fix failing CI", (st) => st.hasPr && st.isMine && st.failed > 0, (st, c) => doAgent(st, "fix-ci", "clone", c), (st) => `${st.failed} red`, "", NONE, NONE),
    row("babysit", "agent", "🤖", "autonomous pass", (st) => st.hasPr && st.isMine && (st.failed > 0 || st.mergeable === "CONFLICTING"), (st, c) => doAgent(st, "babysit", "clone", c), NONE, "", NONE, NONE),
    row("bump", "agent", "📣", "nudge reviewers on Slack", (st) => st.hasPr && st.isMine && st.reviewRequests.length > 0, (st, c) => doAgent(st, "bump", "nowt", c), (st) => `${st.reviewRequests.length} pending`, "", NONE, NONE),
    row("logs", "gh", "🔍", "tail failed check logs", (st) => st.hasPr && st.failed > 0, doLogs, (st) => `${st.failed} red`, "", NONE, NONE),
    row("rerun", "gh", "♻️", "rerun failed checks", (st) => st.hasPr && st.failed > 0, doRerun, NONE, "", NONE, NONE),
    row("re-review", "gh", "🔔", "re-request review (changes requested)", (st) => st.hasPr && st.reviewDecision === "CHANGES_REQUESTED", doReReview, NONE, "", NONE, NONE),
    row("trim", "gh", "✂️", "trim requested reviewers", (st) => st.hasPr && st.reviewRequests.length > 1, doTrim, (st) => `${st.reviewRequests.length} requested`, "", NONE, NONE),
    row("no-changeset-needed", "gh", "🏷", "toggle no-changeset-needed", pr, (st, c) => doLabel(st, "no-changeset-needed", c), (st) => (st.labels.includes("no-changeset-needed") ? "on" : "off"), "label", NONE, NONE),
    row("run_e2e", "gh", "🏷", "toggle run_e2e", pr, (st, c) => doLabel(st, "run_e2e", c), (st) => (st.labels.includes("run_e2e") ? "on" : "off"), "label", NONE, NONE),
    row("skip_e2e", "gh", "🏷", "toggle skip_e2e", pr, (st, c) => doLabel(st, "skip_e2e", c), (st) => (st.labels.includes("skip_e2e") ? "on" : "off"), "label", NONE, NONE),
    row("kick", "gh", "🦵", "kick CI (empty commit + push)", (st) => st.hasPr && st.checksTotal === 0, doKick, NONE, "", NONE, NONE),
    row("watch", "gh", "👁", "watch checks", (st) => st.hasPr && st.pending > 0, doWatch, (st) => `${st.pending} pending`, "", NONE, NONE),
    row("update-merge", "gh", "⬆️", "update branch from base (merge commit)", (st) => st.hasPr && st.mergeStateStatus === "BEHIND", (st, c) => doUpdateBranch(st, false, c), NONE, "", NONE, NONE),
    row("update-rebase", "gh", "⬆️", "update branch from base (rebase, force-push)", (st) => st.hasPr && st.mergeStateStatus === "BEHIND", (st, c) => doUpdateBranch(st, true, c), NONE, "", NONE, NONE),
    row("merge", "gh", "🚀", "merge --squash --auto", (st) => st.hasPr && st.isMine && !st.isDraft, doMerge, NONE, "", NONE, NONE),
    row("ready", "gh", "📤", "ready for review", pr, doReady, NONE, "", (st) => (st.isDraft ? "📤" : "📥"), (st) => (st.isDraft ? "ready for review" : "back to draft")),
    row("blockers", "gh", "🚧", "merge blockers report", pr, (st) => doBlockers(st), (st) => st.mergeStateStatus, "", NONE, NONE),
    row("stack", "gh", "🥞", "stack…", (st) => st.hasPr && st.stackSize > 0 && !st.isCrossRepository, doStackPick, (st) => (st.stackSize > 0 ? `${st.stackPosition}/${st.stackSize} of stack #${st.stackNumber}` : ""), "", NONE, NONE),
    row("create-pr", "gh", "🔀", "open a PR for this branch", (st) => !st.hasPr && st.kind !== "new" && st.repo !== "", doCreatePr, NONE, "", NONE, NONE),
    row("wt-full", "worktree", "🌱", "worktree + .env/node_modules from parent", (_st) => true, (st, c) => doWorktree(st, "clone", c), (st) => (st.worktree !== "" ? "exists → open" : ""), "", NONE, (st) => (st.worktree !== "" ? "open worktree" : "")),
    row("wt-light", "worktree", "👓", "worktree, no seed", (st) => st.worktree === "", (st, c) => doWorktree(st, "none", c), NONE, "", NONE, NONE),
    row("wt-bootstrap", "worktree", "🚀", "worktree + secrets + install (own tab)", (st) => st.bootstrap !== "", (st, c) => doWorktree(st, "bootstrap", c), (st) => st.bootstrap, "", NONE, NONE),
    row("diff", "gh", "📄", "diff → pager", (st) => st.kind !== "new", doDiff, NONE, "", NONE, NONE),
    row("rm", "worktree", "🗑", "remove worktree + branch", (st) => st.worktree !== "", doRemove, NONE, "", NONE, NONE),
    row("web", "gh", "🌐", "open in browser", (st) => st.kind !== "new" && st.repo !== "", doWeb, NONE, "", NONE, NONE),
    row("copy", "gh", "📋", "copy URL", (st) => st.url !== "", doCopy, NONE, "", NONE, NONE),
  ];
}

// Ordered ids the current state calls for — the menu's top section. Composite:
// every applicable next step in unblock-the-merge order. A CONFLICTING PR gets
// the update rows promoted even though they are only `relevant` on BEHIND.
function suggest(st: St): string[] {
  const o: string[] = [];
  const push = (id: string): void => {
    if (!o.includes(id)) o.push(id);
  };
  if (st.kind === "new") {
    push("wt-full");
    return o;
  }
  if (!st.hasPr) {
    push("wt-full");
    return o;
  }
  if (st.unresolved > 0) {
    push("resolve");
    if (st.isMine) push("respond");
  }
  if (st.failed > 0) {
    if (st.isMine) push("fix-ci");
    push("logs");
    push("rerun");
  }
  if (st.mergeable === "CONFLICTING") {
    push("update-merge");
    push("update-rebase");
  } else if (st.mergeStateStatus === "BEHIND") push("update-merge");
  if (st.e2eExpected > 0 && st.e2eRunning === 0) push("run_e2e");
  if (st.pending > 0) push("watch");
  if (st.reviewDecision === "CHANGES_REQUESTED") push("re-review");
  if (st.isDraft) push("ready");
  if (st.action === "MERGE" && st.isMine && !st.isDraft) push("merge");
  if (o.length === 0) push("wt-full");
  return o;
}

// Relevance PARTITION, not sort-by: suggested rows first in suggest()'s order,
// then relevant rows in registry order, then the rest. fzf's cursor starts on
// row 1, so a bare Enter does the right thing for the state.
function menuRows(st: St, reg: Row[]): string[] {
  const sug = suggest(st);
  const rel = new Map<string, boolean>();
  for (const r of reg) rel.set(r.id, r.relevant(st));
  const ordered: Row[] = [];
  for (const id of sug) {
    const r = reg.find((x) => x.id === id);
    if (r !== undefined) ordered.push(r);
  }
  for (const r of reg) if (!sug.includes(r.id) && rel.get(r.id) === true) ordered.push(r);
  for (const r of reg) if (!sug.includes(r.id) && rel.get(r.id) !== true) ordered.push(r);
  return ordered.map((r) => {
    const mark = sug.includes(r.id) ? "→ " : rel.get(r.id) === true ? "" : "· ";
    const g = r.glyphOf(st);
    const l = r.labelOf(st);
    const ann = r.state(st);
    return `${r.id}\t${mark}${g === "" ? r.glyph : g}  ${pad(l === "" ? r.label : l, 40)}${ann === "" ? "" : ` (${ann})`}`;
  });
}

function menuHeader(st: St): string {
  if (st.kind === "new") return `${st.repoName} · new ${st.headRefName} from ${st.baseRef} · TAB for multiple`;
  if (!st.hasPr) return `${st.repoName} · ${st.headRefName}${st.worktree !== "" ? " · worktree" : ""} · TAB for multiple`;
  const flags: string[] = [st.action];
  if (st.isDraft) flags.push("draft");
  if (st.isMine) flags.push("mine");
  return `${st.repo} #${st.num} — ${st.title.slice(0, 60)}\n${flags.join(" · ")} · ${st.headRefName} → ${st.baseRefName} · TAB for multiple`;
}

// ── dispatcher ──────────────────────────────────────────────────────────────

interface DispatchResult {
  failures: number;
  results: string[]; // "id:failures"
  tookOver: boolean;
}

// gh actions first (registry order), then labels, stack, worktree, then AT
// MOST ONE agent — the agent takes over the terminal. A worktree row next to
// an agent row is dropped: the agent creates the tree itself, and the worktree
// row's layout would launch a SECOND claude.
function dispatch(st: St, ids: string[], reg: Row[], ctx: Ctx): DispatchResult {
  const known = reg.map((r) => r.id);
  const stackIds = ids.filter((i) => i.startsWith("stack:"));
  const regIds = ids.filter((i) => known.includes(i));
  const labelIds = ids.filter((i) => !known.includes(i) && !i.startsWith("stack:"));
  const labelRows = reg.filter((r) => r.kind === "label").map((r) => r.id);
  if (st.hasPr) validateLabels(st.repo, [...regIds.filter((i) => labelRows.includes(i)), ...labelIds]);

  const byGroup = (g: string): string[] => reg.filter((r) => r.group === g).map((r) => r.id).filter((i) => regIds.includes(i));
  const ghIds = byGroup("gh");
  const wtIds = byGroup("worktree");
  const agAll = byGroup("agent");
  const agIds = agAll.length > 1 ? [agAll[0] ?? ""] : agAll;
  if (agAll.length > 1) err(`more than one agent intent selected — running ${agAll[0]}, skipping the rest`);
  let wtKept = wtIds;
  if (agIds.length > 0 && wtIds.length > 0) {
    err(`${agIds[0]} already creates the worktree — skipping ${wtIds.join(", ")}`);
    wtKept = [];
  }
  const plan = [...ghIds, ...labelIds, ...stackIds, ...wtKept, ...agIds];
  let failures = 0;
  const results: string[] = [];
  for (const id of plan) {
    const r = reg.find((x) => x.id === id);
    let f: number;
    if (r === undefined) f = id.startsWith("stack:") ? doStack(st, id, ctx) : doLabel(st, id, ctx);
    else f = r.run(st, ctx);
    failures += f;
    results.push(`${id}:${f}`);
  }
  return { failures, results, tookOver: agIds.length > 0 || wtKept.length > 0 };
}

// `--action`: a registry id, `stack:<sub>`, an alias, or a REAL repo label.
// The last door only opens for a label the repo actually has — a typo must not
// fall through to a label write.
function resolveAction(act: string, repo: string, known: string[]): string {
  if (known.includes(act) || act.startsWith("stack:")) return act;
  const aliased = LABEL_ALIASES.get(act) ?? act;
  if (known.includes(aliased)) return aliased;
  if (repo !== "" && repoLabels(repo).includes(aliased)) return aliased;
  die(
    [
      `unknown --action '${act}' — not a registry id, not a label in ${repo}`,
      `  actions : ${known.join(", ")}`,
      `  aliases : ${[...LABEL_ALIASES.keys()].join(", ")}`,
      `  stack   : ${STACK_ROWS.map((r) => r.id).join(", ")}`,
    ].join("\n"),
  );
}

function jstr(s: string): string {
  return '"' + s.split("\\").join("\\\\").split('"').join('\\"').split("\n").join("\\n") + '"';
}

function stateJson(st: St, results: string[]): string {
  const kv: string[] = [
    `"kind":${jstr(st.kind)}`, `"repo":${jstr(st.repo)}`, `"num":${st.num}`, `"title":${jstr(st.title)}`,
    `"headRefName":${jstr(st.headRefName)}`, `"baseRefName":${jstr(st.baseRefName)}`, `"action":${jstr(st.action)}`,
    `"isDraft":${st.isDraft}`, `"isMine":${st.isMine}`, `"mergeable":${jstr(st.mergeable)}`,
    `"mergeStateStatus":${jstr(st.mergeStateStatus)}`, `"reviewDecision":${jstr(st.reviewDecision)}`,
    `"failed":${st.failed}`, `"pending":${st.pending}`, `"checks_total":${st.checksTotal}`,
    `"threads_fetched":${st.threadsFetched}`, `"unresolved":${st.threadsFetched ? String(st.unresolved) : "null"}`,
    `"labels":[${st.labels.map(jstr).join(",")}]`, `"worktree":${jstr(st.worktree)}`, `"url":${jstr(st.url)}`,
  ];
  const res = results.map((r) => {
    const cut = r.lastIndexOf(":");
    return `{"id":${jstr(r.slice(0, cut))},"failures":${r.slice(cut + 1)}}`;
  });
  return `{"state":{${kv.join(",")}},"results":[${res.join(",")}]}`;
}

// ── stage 2 loop ────────────────────────────────────────────────────────────

interface Opts {
  yes: boolean;
  dry: boolean;
  focus: boolean;
  drop: string;
  json: boolean;
  pause: boolean;
  cwd: string;
}

function ctxFor(st: St, o: Opts): Ctx {
  return { yes: o.yes, dry: o.dry, focus: o.focus, labels: st.labels, drop: o.drop, cwd: o.cwd };
}

// Run the picked actions, re-read, offer the menu again — one target usually
// needs several. Esc leaves; so does an action that moved focus elsewhere.
function menuLoop(st: St, o: Opts, rs: RepoState | null, target: Target | null): void {
  const reg = registry();
  let failures = 0;
  const results: string[] = [];
  let cur = st;
  for (;;) {
    const ids = fzfPick(menuRows(cur, reg), cur.hasPr ? "pr> " : "branch> ", menuHeader(cur), true);
    if (ids.length === 0) break;
    const d = dispatch(cur, ids, reg, ctxFor(cur, o));
    failures += d.failures;
    for (const r of d.results) results.push(r);
    if (d.tookOver) break;
    if (cur.hasPr) cur = prSt(cur.repo, cur.num, true, o.cwd);
    else if (rs !== null && target !== null) cur = branchSt(buildRepoState(o.cwd, false), target);
  }
  if (results.length === 0) return;
  if (o.json) out(stateJson(cur, results));
  if (o.pause) hold();
  if (failures > 0) die(`workctl: ${failures} action(s) failed`);
}

function headless(repo: string, num: number, act: string, o: Opts): void {
  const reg = registry();
  const known = reg.map((r) => r.id);
  const actId = resolveAction(act, repo, known);
  const needsThreads = actId === "resolve" || actId === "respond" || actId === "blockers";
  const st = prSt(repo, num, needsThreads, o.cwd);
  const d = dispatch(st, [actId], reg, ctxFor(st, o));
  if (o.json) out(stateJson(st, d.results));
  if (o.pause) hold();
  if (d.failures > 0) die(`workctl: ${d.failures} action(s) failed`);
}

// ── stage 1 ─────────────────────────────────────────────────────────────────

function selfPath(): string {
  const a0 = process.argv[1] ?? process.argv[0] ?? "workctl";
  return a0.includes("/") ? a0 : "workctl";
}

function stage1(rs: RepoState, query: string): Target | null {
  if (!have("fzf")) die("fzf not found on PATH");
  const sf = tmpFile("state");
  writeFileSync(sf, serializeRepoState(rs), { mode: 0o600 });
  const self = shq(selfPath());
  const header = `${rs.repo}${rs.ghRepo === "" ? "" : ` · ${rs.ghRepo}`} · base origin/${rs.defaultBranch}${rs.currentBranch === "" ? "" : ` · on ${rs.currentBranch}`}\ntype a branch, a PR number or a title · enter → actions`;
  const args = [
    ...fzfBase("work> ", header),
    "--query", query,
    "--bind", `start:reload(${self} __rows ${shq(sf)} {q})`,
    "--bind", `change:reload(${self} __rows ${shq(sf)} {q})`,
    "--preview", `${self} __preview ${shq(sf)} {1}`,
    "--preview-window", "right,46%,border-left,wrap",
    "--print-query",
    "--expect", "ctrl-c",
  ];
  const r = fzfRun(args, "");
  try {
    unlinkSync(sf);
  } catch {
    // per-pid temp file
  }
  if (r.code === 130 || r.code === 1) return null;
  if (r.code !== 0) die(`fzf failed (${r.code})`);
  const key = r.keys[0] ?? "";
  return key === "" ? null : parseKey(key);
}

// A target picked in stage 1 → its stage-2 state. A branch that has an open PR
// is a PR target: that is what unlocks the rich menu.
function stFor(rs: RepoState, t: Target, o: Opts): St {
  if (t.kind === "pr" || (t.prNum > 0 && rs.ghRepo !== "")) return prSt(rs.ghRepo, t.prNum, true, o.cwd);
  return branchSt(rs, t);
}

// `--branch X` / a positional name: exact branch or worktree → straight to the
// menu; a PR number → its menu; otherwise the picker, pre-filled.
function directTarget(rs: RepoState, q: string): Target | null {
  if (/^#?\d+$/.test(q)) {
    const num = Number(q.startsWith("#") ? q.slice(1) : q);
    const p = rs.prs.find((x) => x.num === num);
    if (p !== undefined) return { kind: "pr", branch: p.head, path: "", prNum: p.num, base: "", root: "" };
    if (rs.ghRepo !== "") return { kind: "pr", branch: "", path: "", prNum: num, base: "", root: "" };
    return null;
  }
  const wt = rs.worktrees.find((w) => w.branch === q);
  if (wt !== undefined) {
    const p = prByHead(rs, q);
    return { kind: "wt", branch: q, path: wt.path, prNum: p === undefined ? 0 : p.num, base: "", root: "" };
  }
  const b = rs.branches.find((x) => x.name === q);
  if (b !== undefined) {
    const p = prByHead(rs, q);
    return { kind: b.remote ? "remote" : "local", branch: q, path: "", prNum: p === undefined ? 0 : p.num, base: "", root: "" };
  }
  return null;
}

// ── main ────────────────────────────────────────────────────────────────────

function usage(): void {
  out("workctl [target] [--repo owner/name] [--pr N] [--branch NAME] [--all]");
  out("        [--action ID [--drop a,b]] [--yes] [--dry-run] [--json] [--pause] [--no-focus]");
  out("");
  out("No target → picker over worktrees, PRs, branches and 'create …' rows; enter → actions.");
  out("target = a branch name, a worktree, or a PR number (#123 / 123).");
  out(`actions: ${registry().map((r) => r.id).join(", ")}`);
}

function main(): void {
  const argv = process.argv.slice(2);
  const a0 = argv[0] ?? "";

  if (a0 === "__rows") {
    out(stage1Rows(parseRepoState(argv[1] ?? ""), argv[2] ?? "").join("\n"));
    return;
  }
  if (a0 === "__preview") {
    out(stage1Preview(parseRepoState(argv[1] ?? ""), argv[2] ?? ""));
    return;
  }
  if (a0 === "__state") {
    process.stdout.write(serializeRepoState(buildRepoState(process.env.PWD ?? ".", argv.includes("--all"))));
    return;
  }
  if (a0 === "__menu") {
    // debug: print the stage-2 rows for a PR number without a TTY
    const rs = buildRepoState(process.env.PWD ?? ".", false);
    const st = prSt(rs.ghRepo, Number(argv[1] ?? "0"), true, process.env.PWD ?? ".");
    out(menuHeader(st));
    out(menuRows(st, registry()).join("\n"));
    return;
  }

  const o: Opts = { yes: false, dry: false, focus: true, drop: "", json: false, pause: false, cwd: process.env.PWD ?? "." };
  let repo = "";
  let pr = 0;
  let query = "";
  let all = false;
  let action = "";
  let repoPath = "";
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i] ?? "";
    const next = (): string => {
      i += 1;
      return argv[i] ?? "";
    };
    if (a === "--repo") repo = next();
    else if (a === "--pr") pr = Number(next());
    else if (a === "--branch") query = next();
    else if (a === "--repo-path") repoPath = next();
    else if (a === "--action") action = next();
    else if (a === "--drop") o.drop = next();
    else if (a === "--all") all = true;
    else if (a === "--yes") o.yes = true;
    else if (a === "--dry-run") o.dry = true;
    else if (a === "--json") o.json = true;
    else if (a === "--pause") o.pause = true;
    else if (a === "--no-focus") o.focus = false;
    else if (a === "-h" || a === "--help") {
      usage();
      return;
    } else if (a.startsWith("-")) die(`unknown flag ${a}`);
    else if (query === "") query = a;
  }
  // FIRST thing after parsing: every die from here on must honour the hold.
  PAUSE = o.pause;
  if (repoPath !== "") o.cwd = repoPath;
  if (!have("gh")) die("gh not found on PATH");

  // Headless / gh-dash `T`: --repo + --pr with zero git calls on the gh path.
  if (repo !== "" && pr > 0) {
    if (action !== "") {
      headless(repo, pr, action, o);
      return;
    }
    if (!isTty()) die("workctl needs a TTY for the menu; pass --action instead");
    menuLoop(prSt(repo, pr, true, o.cwd), o, null, null);
    return;
  }
  if (repo !== "") die(`--repo ${repo} needs an explicit --pr — branch detection only speaks for the cwd checkout`);

  const rs = buildRepoState(o.cwd, all);
  if (pr > 0) query = String(pr);

  if (action !== "") {
    // --action against the cwd branch's PR, or a named target
    const t = query === "" ? prByHead(rs, rs.currentBranch) : undefined;
    const num = t !== undefined ? t.num : query !== "" && /^#?\d+$/.test(query) ? Number(query.startsWith("#") ? query.slice(1) : query) : 0;
    if (num === 0 || rs.ghRepo === "") die("--action needs a PR: pass --pr N (or sit on a branch that has one)");
    headless(rs.ghRepo, num, action, o);
    return;
  }

  if (!isTty()) die("workctl needs a TTY for the picker; pass --repo/--pr/--action instead");

  let target: Target | null = query === "" ? null : directTarget(rs, query);
  if (target === null) target = stage1(rs, query);
  if (target === null) return;
  menuLoop(stFor(rs, target, o), o, rs, target);
}

main();
