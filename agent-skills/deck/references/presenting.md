# Hosting, remote, publishing

## deck.mrglaszki.com — the normal path

Service lives in `~/Code/home-lab/services/deck/` and runs on the lab. Push from the Mac:

```bash
deck push <deck.html> <notes.md> [slug]   # slug defaults to the filename
deck ls
deck open <slug>      # deck in the browser here
deck remote <slug>    # remote in the browser here, as well as on the phone
deck rm <slug>
deck next|prev|first|last|calm <slug>
deck goto <slug> <n>
```

| URL | Purpose |
|---|---|
| `https://deck.mrglaszki.com/` | list of decks, drag-and-drop upload |
| `https://deck.mrglaszki.com/d/<slug>` | the deck — the window he shares or projects |
| `https://deck.mrglaszki.com/r/<slug>` | the remote — prev/next plus the current slide's notes |

`DECK_HOST=http://localhost:8899 deck push …` retargets everything at a local container.

### How the remote reaches the deck

The uploaded HTML is served verbatim with a controller injected before `</body>`. It
subscribes to `/api/decks/<slug>/events` (SSE) and calls the deck's own `nextSlide()`,
`prevSlide()`, `showSlide(n)`; a `MutationObserver` on every `.slide` POSTs the current
slide back to `/state`. So the remote stays in sync however the slide changed — phone,
keyboard, or a click on the deck itself.

Any deck built from `templates/deck-template.html` works. A deck without those globals is
still hosted and displayed, it just can't be driven.

### The prompter

`notes.md` is split on `## Slajd N` / `## Slide N` headings; slide *n* in the file maps to
slide *n* in the deck. **Renumber the narration whenever you insert a slide** — nothing
validates this, and a drift means he reads the wrong block on stage.

The remote styles the markdown to match how the narration is written: Polish prose dimmed
(stage direction, for him), blockquotes highlighted (the English he says). The Obsidian
teleprompter can therefore be pushed as-is.

### Endpoints

`/api/decks` · `POST /api/decks/<slug>` (multipart `html`, `notes`, `title`) ·
`DELETE /api/decks/<slug>` · `/api/decks/<slug>/state` · `/api/decks/<slug>/notes` ·
`/api/decks/<slug>/cmd/<next|prev|first|last|calm|goto?n=|reload>` ·
`/api/decks/<slug>/events` · `/healthz`

Every command answers to GET as well as POST, so anything that can make an HTTP request is
a remote. Stream Deck "Open URL" buttons on `/cmd/goto?n=13` are the tidy way to jump to a
section when a question knocks him off script.

### Deploying a change to the service

```bash
git -C ~/Code/home-lab push
ssh lab 'cd /opt/homelab && git pull && docker compose -f services/deck/compose.yaml up -d --build --force-recreate'
```

`*.mrglaszki.com` is a DNS wildcard onto 192.168.50.10, so no record needs adding. Two things not to
break: traefik carries an `X-Accel-Buffering: no` middleware (without it SSE is buffered
and the remote goes deaf), and uvicorn runs a single worker (slide state and the listener
list are in-process).

LAN-only, no auth, like the rest of the lab. Decks carry internal work material — don't put
this behind a public tunnel without adding auth.

## Offline fallback

`~/Code/dotfiles/bin/deck-serve` is the original single-deck server, kept for when the lab
is unreachable:

```bash
nohup deck-serve <deck.html> 8777 >/tmp/deck-serve.log 2>&1 & disown
```

`nohup … & disown` is not optional — with a bare `&` from an agent shell it dies with the
shell. Give him the LAN IP, never `localhost`. It has no prompter; the notes stay in
Obsidian in that mode.

## Remotes that don't work

**AeroSpace hotkeys.** Bindings like `ctrl-alt-right = 'exec-and-forget curl …'` were added
on 2026-07-30, applied, reloaded — and never fired. They were removed rather than left as
dead config. Before retrying, establish which half is broken: whether macOS eats the combo
(`ctrl-→` is Mission Control's desktop switcher) and whether `exec-and-forget` reaches the
binary at all. **Dygma** can only send a key combo, so it inherits the same problem.

**AppleScript.** All three doors are shut: `osascript` has no Accessibility grant
(*"not allowed to send keystrokes" (1002)*); Safari's preferences are sandboxed so the
Apple-Events toggle can't be set from the CLI (*"Could not write domain"*); Comet answers
AppleScript for tab titles but refuses `execute javascript` (*"Access not allowed" (-1723)*).
A server sidesteps all of it.

**Which browser he's actually using** — don't assume. His default handler is OpenIn
(Setapp), which routes wherever he's configured; on 2026-07-30 it was Comet. Find the real
window with `aerospace list-windows --all | grep -i "<deck title>"`.

## Publishing afterwards

**In the room:** `deck.mrglaszki.com`. **Afterwards:** an Artifact, for people to keep.

Make a separate `deck-artifact.html` so the hosted copy is untouched:

1. Strip `<!DOCTYPE>`, `<html>`, `<head>`, `<body>`; keep `<title>`. The Artifact host
   supplies the skeleton.
2. Delete any SSE remote block the deck carries of its own. (Decks pushed to `deck.mrglaszki.com`
   don't have one — the controller is injected server-side and never lands in the file.)
3. Confirm zero external references.

Say out loud that internal material — PR numbers, reviewer counts, meeting quotes, branch
names — is leaving the machine. Artifacts start private, but it is still an upload, and it
contradicts a deck that recommends local-only tooling.

## Hosted plans and recaps in a demo

Greg doesn't want a third-party service on screen. Export first:

```
mcp__plan__export-visual-plan(planId) → the `html` field is a standalone page
```

The result blows the token cap, so it lands in a file — pull the field with jq/python and
push it as its own deck, or drop it next to the deck when using the offline fallback. A
small card-grid `index.html` over several exports reads as a local dashboard.

Caveat worth saying on stage: a static export can't be commented on. It shows the structure
of a recap, not the live review workflow.
