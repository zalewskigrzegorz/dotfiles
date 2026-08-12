---
name: deck
description: Build a presentation deck for Greg to actually stand up and deliver — a self-contained animated HTML deck in the Mocha Neon palette, a PL/EN teleprompter in Obsidian, and a phone remote so he can flip slides while reading notes. Use when Greg says he's presenting, giving a talk, doing an academy/brown-bag/demo session, "zrób prezentację", "deck na akademię", "muszę o tym opowiedzieć", "slajdy", "prezentacja na jutro", or asks to turn work he did into something he can show a team. Also use when he wants to update or re-run a previous talk. NOT for one-off diagrams (draw those on draw.mrglaszki.com) and NOT for written documents that are merely shared (those are just markdown).
---

# Deck

Greg presents to his team roughly every cycle. The setup below came out of the 2026-07-30 academy talk, which landed well, so reproduce it rather than reinventing.

Three deliverables, in this order:

1. **`deck.html`** — one self-contained file, animated, Mocha Neon, 16:9. Goes in bazgroly.
2. **Teleprompter** — a note in Obsidian, Polish instructions + English speech.
3. **Push to `deck.mrglaszki.com`** — `deck push`, which hosts the deck and gives him a phone remote with the notes on it.

## The rule that makes the talk good

**Research before you write a single slide.** The talk that worked was built entirely out of things that actually happened to Greg — with numbers pulled from APIs and a verbatim quote from his own meeting transcript. The first draft of that same talk was generic pros-and-cons and he rejected it.

So: never write a deck from general knowledge about the topic. Go find what happened.

| Source | What it gives you | How |
|---|---|---|
| Hindsight | Decisions, blockers, workarounds, dated context | `mcp__hindsight__recall`; results have a `text` field (not `content`), and `context` names the episode. Output usually blows the token cap → jq the saved file. |
| Meeting transcripts | **Verbatim quotes — the single most persuasive slide material** | `spark meetings` for IDs, then `spark meeting --transcript <id>` piped through `grep -inE` for your keywords. Do not read whole transcripts. |
| bazgroly | Design docs and plans he already wrote on the topic | `grep -ril --include="*.md"` over `~/Code/personal/bazgroly/` |
| GitHub API | Hard numbers nobody can argue with | timeline events (`head_ref_force_pushed`, `review_requested`, `review_request_removed`, `base_ref_changed`), `gh search issues` for volume, GraphQL `subIssuesSummary` / `closedByPullRequestsReferences` |
| Web | Whether the third-party thing is actually in preview/GA, and its real name | Verify before claiming; product state changes fast |

Then keep a source table in the bazgroly `plan.md` — one row per claim, so any number on a slide can be traced. Greg gets asked "where's that from" on stage.

## Tone

Field report, never a pitch. The talk works because it says what something **cost**, in his own numbers, and gives an honest verdict — including "the idea is right, the tooling isn't". Anything that reads as advocacy gets cut.

Concretely:
- Lead with what happened to us, not what the tool claims.
- Put one slide early that is fair to the thing you're about to criticise, or the rest reads as a hit piece.
- A verbatim quote beats any bullet list. Give it its own slide and let it sit.
- Name the cost in units people feel: force-pushes, reviewers pulled in, an afternoon lost.
- End with a verdict per item, plainly.
- No reviewer names. Numbers make the point; names make enemies.

## Building the deck

Copy `templates/deck-template.html` and replace the nine example slides. It ships with the full Mocha Neon system, the aurora background, the nav, the overflow-safe layout and the remote client already wired.

Structural pieces available — see `references/design-system.md` for the full catalogue: `.metrics` + `.metric`, `.card` (`.good`/`.bad`/`.warn`/`.pri`), `blockquote`, `.embed` + `.diagram-wrap` (before/after panels), `.loop` (horizontal causal chain), `.stack` (vertical layers), `.split` + `.list`, `.bars`, `.diff`, `.tree`, `.gh-row` + `.cmd`.

**Every slide's content must sit inside `.slide-content`** — that is what the overflow check measures.

### Verify layout by measurement, not by eye

Screenshots are unreliable here: `agent-browser screenshot` returns black frames whenever the browser window isn't visible on screen. Measure instead:

```bash
agent-browser open "file:///path/deck.html"; sleep 2
agent-browser eval "
(()=>{const out=[];
[[1280,720],[1600,900],[1920,1080]].forEach(([w,h])=>{
  const d=document.querySelector('.slide-deck');
  d.style.cssText='position:absolute;top:0;left:0;width:'+w+'px;height:'+h+'px;max-width:none;max-height:none;overflow:hidden;isolation:isolate';
  const bad=[];
  document.querySelectorAll('.slide').forEach((s,i)=>{
    s.style.opacity=1;s.style.visibility='visible';
    const cs=getComputedStyle(s);
    const avail=s.clientHeight-parseFloat(cs.paddingTop)-parseFloat(cs.paddingBottom);
    const c=s.querySelector('.slide-content');
    const need=[...c.children].reduce((a,el)=>a+el.getBoundingClientRect().height+parseFloat(getComputedStyle(el).marginTop),0)
              +parseFloat(getComputedStyle(c).rowGap)*(c.children.length-1);
    if(need>avail+1) bad.push((i+1)+':'+s.dataset.tag+' need='+Math.round(need)+' avail='+Math.round(avail));
    s.style.opacity='';s.style.visibility='';
  });
  out.push(w+'x'+h+' -> '+(bad.length?bad.join(' | '):'clean'));
  d.style.cssText='';
});
return JSON.stringify(out)})()"
```

Do **not** compare `scrollHeight` to `clientHeight` — on a short slide the flex container reports a phantom trailing gap and you'll chase overflow that isn't there. Wrap the eval in an IIFE, or a second run fails with "identifier already declared".

## Teleprompter

Write it to `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Knowlage/<work-vault-folder>/Narration script — <topic>.md`, where `<work-vault-folder>` is the employer folder named in **work-context** (`~/.local/state/dotfiles/secrets/work-context.md`, §Org) — read it first. Format follows his existing `Narration script — PR 22649 asdf to mise presentation.md`.

The split he asked for, and it matters:

- **Polish = for him.** Stage directions, timing, what to emphasise, what not to say, cut order. He sees Polish → he reads it.
- **English inside a `>` blockquote = what he says.** He sees English in a quote → he speaks it.

Because he is not a native speaker:
- **Spell every number out as words.** `783` → "seven hundred eighty-three". `2790` → "two thousand seven hundred and ninety".
- **Put pronunciation inline, in parentheses, at the point of use** — never in a lookup table at the top, he won't scroll back to it. `four-oh-one` for 401, `gee-aitch stack (gh stack)`, `graph-cue-ell (GraphQL)`, `tee-ess build info (tsbuildinfo)`, `fixes-hash (Fixes #)`.

Also include, all in Polish: per-slide timing, a cut order for when he's running long (with an explicit "never cut these" list), prepared Q&A answers, and a "don't say" list. Anticipate the question the slide itself provokes — the deck said "not Graphite" and the whole Graphite explainer had to be ready.

Start from `templates/narration-template.md`.

**The same file gets pushed to `deck.mrglaszki.com` as `notes.md`**, which is what puts the notes on
his phone during the talk. Write it once, use it twice — no separate speaker-notes format.

## Push it to deck.mrglaszki.com

The deck and its notes live on the lab, at `deck.mrglaszki.com` (service in `home-lab/services/deck/`).
From the Mac:

```bash
deck push <deck.html> <notes.md> [slug]
```

That prints two URLs:

| URL | Who looks at it |
|---|---|
| `https://deck.mrglaszki.com/d/<slug>` | **the deck** — the window he shares or projects |
| `https://deck.mrglaszki.com/r/<slug>` | **the remote** — his phone: prev/next, plus the notes for the slide that is currently up |

This is the whole reason the notes file matters. He stands there holding the phone: the
current slide's block is on screen, Polish stage directions dimmed, the English he says
highlighted. He taps → and both the projected deck and his own notes advance together.

**So `## Slajd N` headings are a contract, not a convention.** The server maps heading
number → slide number. Get them out of step and he reads slide 9's notes over slide 8.
Renumber the narration whenever you insert a slide.

The uploaded HTML needs no cooperation — `deck.mrglaszki.com` injects its own controller on the way
out, which calls the deck's `nextSlide()` / `prevSlide()` / `showSlide(n)` and reports the
current slide back. Any deck from `templates/deck-template.html` satisfies that.

Other `deck` verbs: `ls`, `open <slug>`, `remote <slug>`, `rm <slug>`, `next|prev|goto <slug> [n]`.
`DECK_HOST` retargets it, which is how you test against a local container.

**Don't rebuild a local server for this.** `~/Code/dotfiles/bin/deck-serve` still exists as
an offline fallback (`nohup deck-serve <deck.html> 8777 … & disown`) for when the lab is
unreachable, but `deck.mrglaszki.com` is the path — it survives reboots, needs no terminal, and the
phone reaches it from anywhere on the LAN.

**AeroSpace hotkeys don't work** and the bindings were removed on 2026-07-30. Don't re-add
them; the phone remote is the proven control. Full detail, including the AppleScript dead
ends, is in `references/presenting.md`.

## Publishing afterwards

For the room, serve locally — no wifi dependency, no login, and the remote works. For sending round afterwards, publish an Artifact. Two edits are needed first:

1. Strip `<!DOCTYPE>`, `<html>`, `<head>`, `<body>` — the Artifact host wraps the file itself. Keep `<title>`.
2. Delete the SSE remote block. On `https` it will try to reach `/events`, fail, and retry forever.

Write it as a separate `deck-artifact.html` so the served copy keeps its remote. **Flag before publishing** that internal material (PR numbers, reviewer counts, meeting quotes, branch names) is leaving the machine — especially when the deck itself recommends local-only tooling.

If the talk shows off hosted plans or recaps, export them to static HTML first (`mcp__plan__export-visual-plan` → the `html` field) and serve them from the deck's own directory. Greg asked for this so the demo showed no third-party service. A small `recaps/index.html` of cards makes a credible local dashboard.

## Gotchas that already cost time

- **Never add a `prefers-reduced-motion` blanket rule.** Greg has macOS Reduce Motion **on**, so `*{animation:none !important}` silently kills every animation and the deck looks static. The template has no such rule; `body.calm` on the `C` key is the opt-out instead.
- **Aurora vs legibility is a real tension.** He wants visible movement *and* readable diagrams. The balance in the template: bright blobs (opacity .42/.38/.30, 13–20 s cycles, big amplitude) plus a scrim behind the content plus a dark drop shadow on every panel. If he says diagrams are washing out, strengthen the scrim before dimming the aurora; if he says the background looks static, raise amplitude and opacity, not just opacity.
- Don't put `animation` on a direct child of `.slide-content` — the entry `fadeUp` rule wins and your animation vanishes. Animate a descendant instead.
- Don't pulse `opacity` on anything containing text. Pulse the arrows and rails.
- **Zero external requests.** No font CDN, no Chart.js, no remote images. It must work with the projector's wifi down, and the Artifact CSP blocks them anyway.
- Check `git remote`/`npm view` before claiming where something lives. The visual-recap skill looks like a GitHub repo but ships in the npm package `@agent-native/core`; repo is `BuilderIO/agent-native`, package is MIT, repo has no detectable LICENSE.

## Where things go

| What | Where |
|---|---|
| `deck.html`, `plan.md` (sources), `recaps/` | `~/Code/personal/bazgroly/<repo>/notes/YYYY-MM-DD-<topic>/` |
| Teleprompter | Obsidian, `Knowlage/<work-vault-folder>/Narration script — <topic>.md` (folder per work-context §Org) |
| Hosting service | `~/Code/home-lab/services/deck/` (deployed to the lab) |
| `deck` CLI, `deck-serve` fallback | `~/Code/dotfiles/bin/` (tracked) |

Never put the deck in a work repo. Never commit for him.
