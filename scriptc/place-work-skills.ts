// Place Greg's WORK-SCOPED skills (g-pr*, PR/issue helpers, …) into a
// work-monorepo worktree's .claude/skills/ — the per-worktree half of the
// agent-skills sync.
//
// WHY THIS EXISTS: run_onchange_after_30-agent-skills-sync.sh only fires on
// `chezmoi apply` and only knows about worktrees that exist AT apply time. A
// worktree created later (via `work new`) starts with ZERO work skills until
// the next apply — that's the recurring "g-review missing in a fresh
// worktree" bug. `work new`/`work pr`/`work switch` (work.nu) call this so
// every worktree gets g-pr-review & friends immediately.
//
// SINGLE SOURCE OF TRUTH for the work-skill NAME LIST lives here (WORK_SKILLS
// + the private work-scope file). run_onchange_after_30 reads it via
// `--list` so the apply-time sync and the on-demand placement can never
// drift apart. THIS BINARY'S `--list` STDOUT CONTRACT MUST NOT CHANGE — it
// is consumed by that stage script and by `work new`.
//
// Usage:
//   place-work-skills [<repo-or-worktree-path>]   # default: git repo of CWD
//   place-work-skills --list                      # print skill names, one per line
//
// No-ops unless the target's parent repo is $WORK_MONOREPO_DIR, so it is
// safe to call from `work new` in ANY repo (dotfiles, home-lab, …) or on the
// lab.
//
// Ported from bash. child_process is still doing real subprocess work here
// (git ×3, chezmoi, rsync per skill) — that's inherent to the task, not
// something native TS can remove. The port's value is the typed name-list
// parsing, path resolution and exclude-file bookkeeping, not fewer
// processes.

import { spawnSync } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

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

// `(cd "$path" && pwd -P) || echo "$path"` — physical (symlink-resolved)
// path, falling back to the literal input if cd fails.
function norm(path: string): string {
  const r = spawnSync("bash", ["-c", 'cd "$1" 2>/dev/null && pwd -P', "bash", path], {
    encoding: "utf8",
  });
  const out = (r.stdout ?? "").trim();
  return out !== "" ? out : path;
}

function git(args: string[]): { status: number; stdout: string } {
  const r = spawnSync("git", args, { encoding: "utf8" });
  return { status: r.status ?? 1, stdout: (r.stdout ?? "").trim() };
}

function commandExists(name: string): boolean {
  const r = spawnSync("bash", ["-c", `command -v "$1" >/dev/null 2>&1`, "bash", name]);
  return r.status === 0;
}

function loadWorkSkills(): string[] {
  const skills = [
    "babysit-prs",
    "g-pr",
    "g-pr-bump",
    "g-pr-fix-checks",
    "g-pr-respond",
    "g-pr-review",
    "g-github-issue",
    "g-pr-common",
  ];

  const secretDir = process.env.DOTFILES_SECRET_DIR || join(home(), ".local/state/dotfiles/secrets");
  const scopeFile = join(secretDir, "work-scope-skills.txt");
  if (existsSync(scopeFile)) {
    const raw = readFileSync(scopeFile, "utf8");
    for (const rawLine of raw.split("\n")) {
      // `${line%%#*}` then `${line// /}` — strip from the first '#' on, then
      // strip every space anywhere in what's left.
      const stripped = rawLine.split("#")[0].replace(/ /g, "");
      if (stripped !== "") skills.push(stripped);
    }
  }
  return skills;
}

function main(): void {
  const args = process.argv.slice(2);
  const workSkills = loadWorkSkills();

  if (args[0] === "--list") {
    console.log(workSkills.join("\n"));
    return;
  }

  const secretDir = process.env.DOTFILES_SECRET_DIR || join(home(), ".local/state/dotfiles/secrets");
  const raw = args[0] ?? ".";
  const toplevel = git(["-C", raw, "rev-parse", "--show-toplevel"]);
  const target = toplevel.status === 0 ? toplevel.stdout : "";
  if (target === "") {
    console.error(`place-work-skills: not a git repo: ${raw}`);
    return;
  }

  const workEnvFile = join(secretDir, "work.env");
  let workMonorepoDir = "";
  if (existsSync(workEnvFile)) {
    workMonorepoDir = sourceEnvVar(workEnvFile, "WORK_MONOREPO_DIR");
  } else {
    workMonorepoDir = process.env.WORK_MONOREPO_DIR || "";
  }
  if (workMonorepoDir === "") return; // no work monorepo configured (e.g. lab)

  const commonDirRes = git(["-C", target, "rev-parse", "--path-format=absolute", "--git-common-dir"]);
  const commonDir = commonDirRes.status === 0 ? commonDirRes.stdout : "";
  if (commonDir === "") return;

  const parentRoot = commonDir.endsWith("/.git")
    ? commonDir.slice(0, -"/.git".length)
    : dirname(commonDir);

  if (norm(parentRoot) !== norm(workMonorepoDir)) return;

  // --- Sources: public agent-skills + private overlay. ---
  let dotfilesSrc = "";
  const sourcePathRes = spawnSync("chezmoi", ["source-path"], { encoding: "utf8" });
  if (sourcePathRes.status === 0) {
    dotfilesSrc = (sourcePathRes.stdout ?? "").trim();
  }
  if (dotfilesSrc === "" || !existsSync(join(dotfilesSrc, "agent-skills"))) {
    dotfilesSrc = join(home(), "Code/dotfiles");
  }
  const source = join(dotfilesSrc, "agent-skills");
  const privateSource = join(secretDir, "agent-skills");

  if (!commandExists("rsync")) {
    console.error("place-work-skills: rsync missing");
    return;
  }

  const skDir = join(target, ".claude/skills");
  const gitDirRes = git(["-C", target, "rev-parse", "--absolute-git-dir"]);
  const gitDir = gitDirRes.status === 0 ? gitDirRes.stdout : "";
  const exf = join(gitDir, "info/exclude");
  mkdirSync(skDir, { recursive: true });
  mkdirSync(join(gitDir, "info"), { recursive: true });

  let existingExcludeLines: string[] = [];
  if (existsSync(exf)) {
    existingExcludeLines = readFileSync(exf, "utf8").split("\n");
  }

  let placed = 0;
  for (const s of workSkills) {
    let src = join(source, s);
    if (!existsSync(src)) {
      src = join(privateSource, s);
      if (!existsSync(src)) continue;
    }
    const dest = join(skDir, s);
    // Bash never checks rsync's exit code here either — `placed` and the
    // exclude line are unconditional. Matched as-is, not "fixed".
    spawnSync(
      "rsync",
      ["-a", "--delete", "--exclude", ".DS_Store", `${src}/`, `${dest}/`],
      { stdio: "inherit" },
    );

    const line = `/.claude/skills/${s}/`;
    if (!existingExcludeLines.includes(line)) {
      appendFileSync(exf, `${line}\n`);
      existingExcludeLines.push(line);
    }
    placed += 1;
  }

  console.log(`place-work-skills: ${placed} work skill(s) → ${skDir}`);
}

main();
