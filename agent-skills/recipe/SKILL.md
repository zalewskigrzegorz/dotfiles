---
name: recipe
description: Use when entering an unfamiliar repo and about to build, test, lint, or run it — detect which task runner the project actually uses (just, make, task, cargo, npm/pnpm/bun scripts, nx/turbo) and dispatch through it instead of guessing raw commands. Also on "jak się to buduje", "how do I run this", "what tasks does this repo have".
---

# recipe — task-runner detection & dispatch

Projects encode their build/test/run commands in a task runner. Use the project's
own entrypoints instead of hand-rolling `npm test` / `cargo build` guesses — the
runner target usually wires env vars, flags, and ordering you'd otherwise miss.

## 1. Detect (check repo root, in this order)

| File | Runner | List tasks with |
|---|---|---|
| `justfile` / `Justfile` / `.justfile` | just | `just --list` |
| `Taskfile.yml` / `Taskfile.yaml` | go-task | `task --list-all` |
| `Makefile` / `makefile` | make | `make help` if a help target exists, else read targets: `rg '^[a-zA-Z0-9_.-]+:' Makefile` |
| `nx.json` | nx (monorepo) | `nx show projects`; per-project: `nx show project <name>` |
| `turbo.json` | turborepo | read `tasks` keys in `turbo.json` + root `package.json` scripts |
| `package.json` with `scripts` | npm / pnpm / bun / yarn | read the `scripts` block |
| `Cargo.toml` | cargo | standard verbs (`build`/`test`/`run`/`clippy`); check `[alias]` in `.cargo/config.toml` |
| `pyproject.toml` | uv / poetry / hatch | look for `[tool.poe.tasks]`, `[tool.hatch.envs.*.scripts]`, tox/nox files |

Multiple hits are normal (e.g. justfile wrapping cargo) — **the wrapper wins**:
prefer just/task/make over the underlying tool they delegate to.

## 2. Pick the JS package manager by lockfile, never by habit

`bun.lock`/`bun.lockb` → bun · `pnpm-lock.yaml` → pnpm · `yarn.lock` → yarn ·
`package-lock.json` → npm. A `packageManager` field in package.json overrides
the lockfile guess. In monorepos run scripts from the workspace package, not
the root, unless the root script fans out (turbo/nx).

## 3. Dispatch

- Match intent to task by name first (`test`, `build`, `lint`, `dev`, `check`),
  then by reading the task body when names are ambiguous.
- If the task exists in the runner, run the runner (`just test`), NOT the
  expanded command it wraps.
- No matching task → say so and fall back to the ecosystem default, flagging
  that it bypasses the repo's runner.
- Never invent targets; list first, then run.
