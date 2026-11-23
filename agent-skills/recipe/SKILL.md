---
name: recipe
description: Use when entering an unfamiliar repo and about to build, test, lint or run it: detect the task runner it actually uses (just, make, task, cargo, npm/pnpm/bun scripts, nx/turbo) and dispatch through it instead of guessing raw commands. Also on "jak się to buduje", "how do I run this", "what tasks does this repo have".
---

# recipe — task-runner detection & dispatch

The runner target wires env vars, flags and ordering a hand-rolled `npm test` misses.

## 1. Detect (repo root, in order)

| File | Runner | List tasks |
|---|---|---|
| `justfile` / `Justfile` / `.justfile` | just | `just --list` |
| `Taskfile.yml`/`.yaml` | go-task | `task --list-all` |
| `Makefile` / `makefile` | make | `make help` if present, else `rg '^[a-zA-Z0-9_.-]+:' Makefile` |
| `nx.json` | nx | `nx show projects`, `nx show project <name>` |
| `turbo.json` | turborepo | `tasks` keys + root `package.json` scripts |
| `package.json` `scripts` | npm/pnpm/bun/yarn | the `scripts` block |
| `Cargo.toml` | cargo | standard verbs; `[alias]` in `.cargo/config.toml` |
| `pyproject.toml` | uv/poetry/hatch | `[tool.poe.tasks]`, `[tool.hatch.envs.*.scripts]`, tox/nox |

Several hits are normal: **the wrapper wins** (just/task/make over what they call).

## 2. JS package manager by lockfile, never habit

`bun.lock(b)` → bun · `pnpm-lock.yaml` → pnpm · `yarn.lock` → yarn · `package-lock.json` → npm; a `packageManager` field overrides. In monorepos run from the workspace package unless the root script fans out (turbo/nx).

## 3. Dispatch

Match intent by task name (`test`, `build`, `lint`, `dev`, `check`), then by body. Run the runner (`just test`), not the command it wraps. No matching task → say so and fall back to the ecosystem default, flagged as bypassing the runner. Never invent targets: list first.
