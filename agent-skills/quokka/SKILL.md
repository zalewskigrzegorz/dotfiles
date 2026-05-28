---
name: quokka
description: Use when the user wants to validate a small JS/TS snippet in isolation before integrating it — "will this regex match", "what does Array.from return here", "is this date math right", "how does dayjs handle X" — and explicitly said "don't write a real test yet" or "I just want to check". The user has a Quokka.js Pro license and the VS Code extension; this skill defines the round-trip workflow (no MCP — agent generates the snippet, user runs it in Quokka, user reports values back). Also covers when NOT to use Quokka (real tests → wallaby; live app debugging → console-ninja).
---

# quokka

## Core principle

Quokka.js is a scratchpad that runs JS/TS and prints the value of every top-level expression inline in the editor (or in the Pro Live Sandbox in browser). It's the right tool for "let me confirm this works" before committing to a real test or shipping the code. **It has no MCP and no CLI agent integration** — the agent cannot read Quokka's runtime values directly. The workflow is always a round-trip with the user.

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
2. **Do NOT invent a sandbox URL.** The Quokka Pro Live Sandbox URL format may change and is not in your training data. If the user prefers the browser sandbox, ask them once for the current URL (or to open it themselves and paste code in), then reuse that for the session. Never `Bash("open 'https://quokkajs.com/sandbox/'")` from guess.
3. **Be honest about the round-trip.** Tell the user "I'll write the snippet at `<path>`, you run Quokka on it, paste the inline values back." Don't pretend to read Quokka's output.
4. **Bare expressions on their own line.** Quokka prints inline value for every top-level expression. Structure snippets so the "interesting" values are bare expressions, not `console.log(x)` (which works but pollutes).

## Two delivery modes

### Mode A — VS Code scratch file (default)

Best when the user is already in VS Code (which on Greg's setup is the default for prototyping). Works offline. Persists for re-runs.

Steps:
1. `mkdir -p ~/Code/personal/bazgroly/<repo>/scratch/` if needed.
2. `Write` the snippet to `~/Code/personal/bazgroly/<repo>/scratch/<YYYY-MM-DD>-<topic>.quokka.ts`.
3. Tell the user (verbatim short form): "Wrote `<path>`. Open it in VS Code → `Cmd+Shift+P` → **Quokka.js: Start on Current File** (or `Cmd+K Q`). Paste back the inline values you see."
4. Wait for user. Integrate values into the answer.

### Mode B — Quokka Pro Live Sandbox (browser)

Best for fully self-contained snippets where the user doesn't want to open VS Code (e.g. they're on mobile, or they want to share the link). Requires Greg's Pro account.

Steps:
1. Ask the user for the current Live Sandbox URL ("paste me the current sandbox URL or open it and paste the code yourself"). **Do not guess the URL.**
2. Provide the snippet inline in your reply, ready to paste.
3. User runs it in browser, pastes values back.

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
| "I'll guess the sandbox URL" | Don't. Ask the user. |
| "I'll just describe what the regex does without running it" | If you can derive it statically with high confidence, say so plainly and skip the round-trip. Otherwise route through Quokka — your static reasoning lies sometimes. |

## Statically obvious cases — skip the round-trip honestly

If the snippet is statically trivial (e.g. a regex you can reason about character-by-character), it's OK to answer directly with a one-line note: "this is statically obvious — `<answer>`. If you still want a Quokka check let me know." Don't force a round-trip just for ceremony.

## Out of scope

- Failing project tests → `wallaby` skill.
- Live app logs / runtime errors → `console-ninja` skill.
- Anything requiring the full project module graph or running services.
