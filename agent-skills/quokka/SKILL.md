---
name: quokka
description: Use when the user wants to validate a small JS/TS snippet in isolation before integrating it — "will this regex match", "what does Array.from return here", "is this date math right", "how does dayjs handle X" — and explicitly said "don't write a real test yet" or "I just want to check". The user has a Quokka.js Pro license + VS Code extension; this skill defines the round-trip workflow (no MCP, no web sandbox — agent generates the snippet, user runs it in VS Code Quokka, user reports values back). Also covers when NOT to use Quokka (real tests → wallaby; live app debugging → console-ninja).
---

# quokka

## Core principle

Quokka.js is an editor-only scratchpad that runs JS/TS and prints the value of every top-level expression inline in the editor. It's the right tool for "let me confirm this works" before committing to a real test or shipping the code.

**Critical constraints:**
- **No MCP, no CLI for agents** — the agent cannot read Quokka's runtime values directly. The workflow is always a round-trip with the user.
- **No browser-based standalone / sandbox** — Quokka runs only in VS Code, WebStorm, or Sublime. There is no "Pro Live Sandbox," no public web playground, no hosted URL. The closest web-adjacent thing is [codeclip.io](https://codeclip.io) which **shares already-run output** (Quokka Pro Share feature) — it does NOT execute code. Do not propose codeclip as a runner.
- **Unlike Wallaby**, Quokka does **not** have a standalone CLI/browser mode. If the user wants no-VS-Code prototyping, the answer is "use TS Playground or `node -e`," not "use Quokka somewhere else."

## When to reach for Quokka (vs alternatives)

Use Quokka when:
- The user explicitly said "don't write a real test yet" / "just want to check" / "let me prototype".
- The check is small (one screen of code).
- A real test would be premature (you don't yet know the right assertions).

Don't use Quokka when:
- It's a failing test in the project → `wallaby` skill.
- It's a runtime bug in a running app → `console-ninja` skill.
- The snippet needs the project's full module graph or real DB / network → write a real integration test (and use `wallaby` for fast feedback on it).
- `Bash("node -e '…'")` would actually be cleaner (single-line eval where you don't need inline value display per line).

## Hard rules

1. **Scratch files do NOT go into the working repo.** They go to `~/Code/personal/bazgroly/<repo-basename>/scratch/<YYYY-MM-DD>-<topic>.quokka.ts`. (Greg's AI-artifacts rule. The `bazgroly` autopush hook handles commit/push.) Resolve `<repo-basename>` with `git rev-parse --show-toplevel` (or `basename $PWD` if not in a repo).
2. **Quokka is VS Code-only.** Don't propose "open it in browser at `https://…`," don't suggest a Pro sandbox URL (it doesn't exist), don't reference codeclip as a runner. If the user explicitly refuses to use VS Code, switch tool (see "Web alternative" below) — don't invent a Quokka web mode.
3. **Be honest about the round-trip.** Tell the user "I'll write the snippet at `<path>`, you run Quokka in VS Code, paste the inline values back." Don't pretend to read Quokka's output.
4. **Bare expressions on their own line.** Quokka prints inline value for every top-level expression. Structure snippets so the "interesting" values are bare expressions, not `console.log(x)` (which works but pollutes).

## The workflow — VS Code scratch file

Greg uses VS Code as a secondary editor specifically for tools like Quokka. This is the only Quokka workflow.

Steps:
1. `mkdir -p ~/Code/personal/bazgroly/<repo>/scratch/` if needed.
2. `Write` the snippet to `~/Code/personal/bazgroly/<repo>/scratch/<YYYY-MM-DD>-<topic>.quokka.ts`.
3. Tell the user (short form): "Wrote `<path>`. Open it in VS Code → `Cmd+Shift+P` → **Quokka.js: Start on Current File** (or `Cmd+K Q`). Paste back the inline values you see."
4. Wait. Integrate values into the answer.

## Web alternative (when the user refuses VS Code)

If the user explicitly says "I don't want to open VS Code" / "give me a web option," **switch tools** — do not pretend Quokka has a web mode.

- **Pure TS/JS snippet, no Node-only APIs:** [TypeScript Playground](https://www.typescriptlang.org/play). Paste, hit Run, output in the right panel.
- **Node-flavored snippet (needs `process`, npm deps, fs, etc.):** [RunKit](https://runkit.com). Notebook-style, each cell prints its value.
- **One-liner where inline values per line don't matter:** `Bash("node -e '…'")` from the agent side.

State the swap plainly: "Quokka is VS Code-only — for a web run I'll prep this for TS Playground / RunKit instead. Paste the URL once you've opened it, or paste back the output."

## Snippet style — bare expressions for inline values

Quokka prints the value of every top-level expression. Structure snippets so the values you care about are bare:

```ts
// regex-foo-2026-05-28.quokka.ts

const re = /^foo\d{2,}$/;

const should_match = ['foo12', 'foo123', 'foo999'];
const should_reject = ['foo1', 'foobar', 'bar12', 'Foo12'];

should_match.map(s => [s, re.test(s)]);    // bare → Quokka prints array inline
should_reject.map(s => [s, re.test(s)]);   // bare → Quokka prints array inline
```

For async code, end with `await promise` (top-level await works in `.ts`) so Quokka resolves before reporting:

```ts
const result = await fetchSomething();
result;  // bare → inline value
```

## Red flags

| Thought | Reality |
|---|---|
| "Quick — let me just `node -e '…'`" | Fine for one-liners; for multi-case checks Quokka's per-line inline values are much faster to read. |
| "I'll write a Vitest test for this" | The user said "don't write a real test yet." Quokka is the answer. |
| "Drop the scratch in `src/__scratch__/`" | Violates the AI-artifacts rule. Bazgroly only. |
| "I'll guess the Quokka sandbox URL" | Quokka has no web sandbox. Don't invent one. Switch to TS Playground / RunKit if the user refuses VS Code. |
| "Codeclip is the web runner" | No — codeclip.io only **shares** already-run output. It does not execute code. |
| "I'll just describe what the regex does without running it" | If you can derive it statically with high confidence, say so plainly and skip the round-trip. Otherwise route through Quokka — your static reasoning lies sometimes. |

## Statically obvious cases — skip the round-trip honestly

If the snippet is statically trivial (e.g. a regex you can reason about character-by-character), it's OK to answer directly with a one-line note: "this is statically obvious — `<answer>`. If you still want a Quokka check let me know." Don't force a round-trip just for ceremony.

## Out of scope

- Failing project tests → `wallaby` skill.
- Live app logs / runtime errors → `console-ninja` skill.
- Anything requiring the full project module graph or running services.
