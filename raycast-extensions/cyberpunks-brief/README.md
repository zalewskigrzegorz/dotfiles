# Cyberpunks Brief

Raycast extension that generates a JARVIS-style Polish briefing before Team Cyberpunks syncs.

## How it works

`brief` command spawns `claude -p` (headless Claude Code) on Mac, pipes the v9 prompt via stdin, and renders the result in a Detail view. Claude has Greg's full MCP stack available (GitHub, Slack, Hindsight, gh CLI via Bash), which is what makes the briefing possible without bespoke per-source code.

```
Cmd+Space → "Cyberpunks Sync Brief"
            ↓ spawn claude -p --model claude-sonnet-4-6
            ↓ stdin = v9 prompt (PL JARVIS, audio tags, anti-hallucination)
            ↓ claude calls gh / Slack MCP / Hindsight tools internally
            ↓ stdout = ~120-word paragraph with [thoughtful] [sighs] tags
            ↓ cleanBriefOutput() strips any planning preamble
            ▶ Detail view, Copy / Regenerate actions
```

## Preferences

- **Claude Code binary** — default `/opt/homebrew/bin/claude`
- **Claude model** — default `claude-sonnet-4-6` (Opus is overkill)
- **ElevenLabs API key / voice id / model id** — currently **unused**; the TTS action is commented out in `brief.tsx` until the pipeline is wired

## Dev

```sh
npm install
npm run dev    # ray develop — hot reload while Raycast is running
npm run build  # ray build  — verify TypeScript + bundle
```

## Files

- `src/brief.tsx` — Detail view + claude subprocess driver
- `src/prompt.ts` — v9 prompt + `cleanBriefOutput()` heuristic
- `assets/icon.png`, `assets/brief.png` — placeholder icons (replace later)

## Roadmap

- v1: this command, claude-driven, no TTS.
- v2: wire ElevenLabs TTS through Joniu voice (`QgQMRjD48AWrvWghFC3J`, `eleven_v3` model with `[thoughtful]` / `[sighs]` / `[calm]` audio tags).
- v3: add `daily` command — personal triage (Spark email, GitHub PRs awaiting *Greg's* review, Slack DMs / mentions, today's calendar, Hindsight leftovers) — same engine, different prompt.
