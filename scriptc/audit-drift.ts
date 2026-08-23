// Compact, classified summary of chezmoi drift — saves tokens vs. having
// Claude read the full `chezmoi diff` and reason about every entry.
//
// For each drifted path, emits one line:
//   PATH | KIND | SUGGESTED_ACTION
//
// Kinds:
//   FILE_DRIFT       — real drift, plain file. Re-add or apply.
//   TEMPLATE_DRIFT   — real drift, source is .tmpl. `chezmoi re-add` may
//                      leave the template untouched if it still renders
//                      to the live content. Manual rewrite + render-and-diff.
//   BINARY_DRIFT     — real drift, binary file. Re-add but watch exec bit
//                      (`chezmoi re-add` can drop it if source lacks the
//                      `executable_` prefix).
//   FAKE_SCRIPT      — chezmoi `run_*` script. Always shows in `chezmoi
//                      diff` because it runs on every apply. Not real drift.
//
// Exit 0 always (informational tool).

import { spawnSync } from "node:child_process";
import { closeSync, openSync, readSync } from "node:fs";

type Kind = "FILE_DRIFT" | "TEMPLATE_DRIFT" | "BINARY_DRIFT" | "FAKE_SCRIPT";

interface ManagedEntry {
  absolute: string;
  sourceAbsolute: string;
  sourceRelative: string;
}

function chezmoi(args: string[]): string {
  const r = spawnSync("chezmoi", args, { encoding: "utf8" });
  return r.stdout ?? "";
}

function driftedPaths(diff: string): string[] {
  const seen = new Set<string>();
  for (const line of diff.split("\n")) {
    if (!line.startsWith("diff --git a/")) continue;
    const rest = line.slice("diff --git a/".length);
    const cut = rest.indexOf(" b/");
    seen.add(cut === -1 ? rest : rest.slice(0, cut));
  }
  return [...seen].sort();
}

// Real magic-byte sniff. The bash version shelled out to `file` and grepped
// for /executable|Mach-O|ELF/, which also matched "shell script text
// executable" — every bash script came back BINARY_DRIFT.
function isBinary(path: string): boolean {
  let fd: number;
  try {
    fd = openSync(path, "r");
  } catch {
    return false;
  }
  const head = Buffer.alloc(4);
  let n = 0;
  try {
    n = readSync(fd, head, 0, 4, 0);
  } catch {
    return false;
  } finally {
    closeSync(fd);
  }
  if (n < 4) return false;
  const be =
    (head[0] << 24) | (head[1] << 16) | (head[2] << 8) | head[3];
  const magic = be >>> 0;
  return (
    magic === 0x7f454c46 || // ELF
    magic === 0xfeedface || // Mach-O 32 BE
    magic === 0xfeedfacf || // Mach-O 64 BE
    magic === 0xcefaedfe || // Mach-O 32 LE
    magic === 0xcffaedfe || // Mach-O 64 LE
    magic === 0xcafebabe || // Mach-O fat
    magic === 0xbebafeca || // Mach-O fat swapped
    (head[0] === 0x4d && head[1] === 0x5a) // PE
  );
}

function row(path: string, kind: Kind | string, action: string): void {
  console.log(`${path.padEnd(58)}  ${kind.padEnd(16)}  ${action}`);
}

function main(): void {
  const diff = chezmoi(["diff"]);
  if (diff.trim() === "") {
    console.log("No drift.");
    return;
  }

  const paths = driftedPaths(diff);
  if (paths.length === 0) {
    console.log("No drift entries parsed.");
    return;
  }

  const scripts = new Set(
    chezmoi(["managed", "--include", "scripts"])
      .split("\n")
      .filter((l) => l !== ""),
  );

  let managed: Record<string, ManagedEntry> = {};
  try {
    managed = JSON.parse(chezmoi(["managed", "--path-style=all"]));
  } catch {
    managed = {};
  }

  const home = process.env.HOME ?? "";

  row("PATH", "KIND", "SUGGESTED_ACTION");
  row("----", "----", "----------------");

  for (const p of paths) {
    if (scripts.has(p)) {
      row(p, "FAKE_SCRIPT", "ignore — runs every apply");
      continue;
    }

    const entry = managed[p];
    const target = entry?.absolute ?? `${home}/${p}`;
    const src = entry?.sourceAbsolute ?? "";

    if (src === "") {
      row(p, "FILE_DRIFT", `chezmoi re-add ${target}`);
    } else if (src.endsWith(".tmpl")) {
      row(p, "TEMPLATE_DRIFT", "see Template-aware re-sync in CLAUDE.md");
    } else if (isBinary(target)) {
      row(p, "BINARY_DRIFT", `chezmoi re-add ${target}  (verify exec bit after)`);
    } else {
      row(p, "FILE_DRIFT", `chezmoi re-add ${target}`);
    }
  }
}

main();
