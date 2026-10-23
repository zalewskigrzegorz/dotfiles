// why-review — which teams CODEOWNERS pulls into a PR's review, and which
// files and pattern pull each one in.
//
//   why-review            PR of the current branch
//   why-review 31204      PR number (a branch name or URL works too)
//
// Also the 👥 row in workctl's PR menu, which passes the PR URL.
//
// Ported from `check-team-review-files` in nushell's git.nu, which read
// CODEOWNERS from the local checkout. GitHub requests reviewers from the
// CODEOWNERS on the PR's base branch, so that is the one read here.

import { spawnSync } from "node:child_process";

interface Run {
  code: number;
  out: string;
  err: string;
}

interface Rule {
  pattern: string;
  regex: RegExp;
  teams: string[];
}

function run(cmd: string, args: string[]): Run {
  const r = spawnSync(cmd, args, { encoding: "utf8" });
  return {
    code: r.status === null ? 1 : r.status,
    out: r.stdout ?? "",
    err: r.stderr ?? "",
  };
}

function die(msg: string): never {
  console.error(`why-review: ${msg}`);
  process.exit(1);
}

function trimSlashes(s: string, left: boolean, right: boolean): string {
  let a = 0;
  let b = s.length;
  while (left && a < b && s[a] === "/") a++;
  while (right && b > a && s[b - 1] === "/") b--;
  return s.slice(a, b);
}

// Gitignore-style CODEOWNERS pattern as a regex: a pattern with a slash is
// anchored at the repo root, `*` stays inside one path segment, `**` crosses
// them, a trailing `/` means a directory.
export function codeownersRegex(pattern: string): RegExp {
  const anchored = pattern.startsWith("/") || trimSlashes(pattern, false, true).includes("/");
  const trimmed = trimSlashes(pattern, true, false);
  const dirOnly = trimmed.endsWith("/");
  const body = trimSlashes(trimmed, false, true)
    .replace(/[.+^$(){}[\]|\\]/g, "\\$&")
    .split("**/").join("\u0001")
    .split("**").join("\u0002")
    .split("*").join("[^/]*")
    .split("?").join("[^/]")
    .split("\u0001").join("(?:.*/)?")
    .split("\u0002").join(".*");
  const prefix = anchored ? "^" : "^(?:.*/)?";
  const suffix = dirOnly ? "/.*$" : "(?:/.*)?$";
  return new RegExp(prefix + body + suffix);
}

export function parseCodeowners(text: string): Rule[] {
  const rules: Rule[] = [];
  for (const raw of text.split("\n")) {
    const line = (raw.split("#")[0] ?? "").trim();
    if (line === "") continue;
    const parts = line.split(/\s+/);
    const pattern = parts[0] ?? "";
    rules.push({ pattern, regex: codeownersRegex(pattern), teams: parts.slice(1) });
  }
  return rules;
}

// The last matching line in CODEOWNERS wins, as on GitHub.
export function owningRule(rules: Rule[], file: string): Rule | null {
  for (let i = rules.length - 1; i >= 0; i--) {
    const rule = rules[i];
    if (rule !== undefined && rule.regex.test(file)) return rule;
  }
  return null;
}

function selfCheck(): void {
  const rules = parseCodeowners(
    "* @org/all\n/apps/api/ @org/api # api\ndocs/*.md @org/docs\n**/package.json @org/deps\n",
  );
  const cases: [string, string][] = [
    ["apps/api/src/x.ts", "/apps/api/"],
    ["apps/ui/src/x.ts", "*"],
    ["docs/a.md", "docs/*.md"],
    ["docs/sub/a.md", "*"],
    ["apps/api/package.json", "**/package.json"],
    ["package.json", "**/package.json"],
  ];
  for (const [file, want] of cases) {
    const got = owningRule(rules, file)?.pattern ?? "none";
    if (got !== want) die(`self-check: ${file} matched ${got}, want ${want}`);
  }
  console.log("self-check ok");
}

function main(): void {
  const args = process.argv.slice(2);
  if (args[0] === "--self-check") return selfCheck();

  // The repo of the current checkout first, then the work monorepo, so
  // `why-review 31204` works from any directory like the nushell original did.
  const here = run("gh", ["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]).out.trim();
  const company = process.env.WORK_COMPANY ?? "";
  const project = process.env.WORK_MAIN_PROJECT ?? "";
  const work = company !== "" && project !== "" ? `${company}/${project}` : "";
  const prArg = args[0] !== undefined ? [args[0]] : [];

  let repo = "";
  let num = "";
  let base = "";
  let lastErr = "not in a GitHub repo and WORK_COMPANY / WORK_MAIN_PROJECT unset";
  for (const candidate of [here, work]) {
    if (candidate === "" || repo !== "") continue;
    // Without an argument gh picks the current branch, which only means something here.
    if (prArg.length === 0 && candidate !== here) continue;
    const view = run("gh", [
      // gh refuses -R without an argument; the checkout is the repo then anyway.
      "pr", "view", ...prArg, ...(candidate === here ? [] : ["-R", candidate]),
      "--json", "number,baseRefName,url", "--jq", '"\\(.number) \\(.baseRefName) \\(.url)"',
    ]);
    const parts = view.out.trim().split(" ");
    if (view.code === 0 && parts.length === 3) {
      // From the URL, not `candidate`: a PR URL argument may name another repo.
      repo = (parts[2] ?? "").split("/").slice(3, 5).join("/");
      num = parts[0] ?? "";
      base = parts[1] ?? "";
    } else {
      lastErr = view.err.trim() || "no PR found";
    }
  }
  if (repo === "") die(lastErr);

  const owners = run("gh", [
    "api", "-H", "Accept: application/vnd.github.raw",
    `repos/${repo}/contents/.github/CODEOWNERS?ref=${base}`,
  ]);
  if (owners.code !== 0) die(`cannot read .github/CODEOWNERS on ${base}: ${owners.err.trim()}`);
  const rules = parseCodeowners(owners.out);

  const listed = run("gh", ["api", "--paginate", `repos/${repo}/pulls/${num}/files`, "--jq", ".[].filename"]);
  if (listed.code !== 0) die(listed.err.trim());
  const files = listed.out.split("\n").filter((f) => f !== "");

  // team -> pattern -> files
  const byTeam = new Map<string, Map<string, string[]>>();
  let unowned = 0;
  for (const file of files) {
    const rule = owningRule(rules, file);
    if (rule === null || rule.teams.length === 0) {
      unowned++;
      continue;
    }
    for (const team of rule.teams) {
      const patterns = byTeam.get(team) ?? new Map<string, string[]>();
      const list = patterns.get(rule.pattern) ?? [];
      list.push(file);
      patterns.set(rule.pattern, list);
      byTeam.set(team, patterns);
    }
  }

  console.log(`PR #${num} · ${files.length} file${files.length === 1 ? "" : "s"} · CODEOWNERS on ${base}`);
  for (const [team, patterns] of byTeam) {
    let count = 0;
    for (const list of patterns.values()) count += list.length;
    console.log(`\n${team} — ${count} file${count === 1 ? "" : "s"}`);
    for (const [pattern, list] of patterns) {
      console.log(`  ${pattern}`);
      for (const file of list) console.log(`    ${file}`);
    }
  }
  if (unowned > 0) console.log(`\nno owner — ${unowned} file${unowned === 1 ? "" : "s"}`);
}

main();
