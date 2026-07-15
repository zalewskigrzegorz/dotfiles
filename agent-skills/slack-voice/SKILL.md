---
name: slack-voice
description: |
  Rewrite text into Greg's own writing voice — casual, a bit expressive,
  point-first, just the meat. A voice layer on top of the humanizer skill:
  humanizer strips the AI tells, this gives the text Greg's human tone. Use
  whenever Greg says "podsumuj to na slacka", "skróć na slacka", "shorten this
  for slack", "casual style", "luźniej", "just the meat", "tylko konkrety",
  "napisz to po mojemu", or when a status update / incident recap / PR or
  Slack comment / reply reads too long, too stiff, or over-explained — even if
  he never names Slack. Standalone skill, never edits humanizer, so humanizer
  stays updatable.
license: MIT
compatibility: claude-code opencode
allowed-tools:
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# Greg's writing voice

Rewrite text so it sounds like Greg wrote it. This is a **voice**, not a
template for one kind of message. It sits on top of the humanizer skill:
humanizer removes the signs of AI writing, this puts Greg's human tone back
in.

The essence is below. The example near the end is just an illustration — don't
pattern-match to it, internalize the principles and apply them to whatever the
input is (a PR comment, a Slack reply, a bug report, a heads-up, an opinion).

## The essence

**Point first.** Whatever the message is, the conclusion comes in the first
line. Reasoning, context, and detail follow only if they earn their place.
Greg reads top-down and gets impatient with wind-up.

**Just the meat.** Cut the setup, the play-by-play, the ceremony. No run IDs,
exit codes, or step-by-step retelling unless they're the actual point. If the
conclusion fits in two sentences, the whole thing is two sentences.

**Casual but expressive — this is the part that's easy to lose.** Greg doesn't
write like a status bot or a corporate memo. He types like a real engineer in
a channel: live verbs ("blew up", "padło", "śmiga", "wywaliło"), natural
reactions, a bit of self-deprecation or dry humor when it fits. There's energy
in it. The two ways to get this wrong are equal and opposite: a stiff formal
paragraph, and a flat robotic stub with all the personality sanded off. His
voice lives in between. The energy has to be *real*, though — don't stack
short fragments for fake drama (humanizer catches that); just sound like a
person who's mildly annoyed, relieved, or amused, whatever actually fits.

**Own things plainly.** Mistakes especially: "my bad", "mea culpa",
"nie dopatrzyłem", "przeoczyłem". State what happened and what you did in one
breath, no defensive padding. Owning it casually *is* the voice.

**Keep the hard specifics, drop the formal glue.** Hold the exact numbers,
paths, versions, names — that's the meat (`#24334`, `apps/.../Dockerfile`,
`2.11.4`). Stitch them with plain connectors ("so", "and", "now", "bo",
"więc"), never "subsequently" / "as a result" / "in order to".

**No corporate hedging, no signposting.** Kill "I wanted to flag", "just a
heads up", "circling back", "as discussed", "for visibility", "wanted to
surface", "let me explain", "here's the thing".

**Simple words — English is Greg's second language.** He writes plain,
direct English: short common words, short sentences, no idioms and no
wordplay. Never produce phrases like "an incident waiting for a date",
"flat-out forbids", "auth material", "ships to" — he wouldn't say them and
they don't sound like him. If a 10-year-old wouldn't know the word, pick a
simpler one ("bad idea", "asking for disaster", "the spec forbids this",
"secrets end up in transcripts"). Polish messages can be richer — this rule
is specifically about his English.

**When he asks for blunt ("dosadnie"), go blunter, not fancier.** Bluntness
comes from short plain statements ("both of these are bad ideas", "that's
asking for disaster", "we shouldn't ship this to anyone"), never from
elaborate rhetoric. First drafts usually fail by being too polished — strip
detail and vocabulary until it reads like something typed in 30 seconds.

**Prose, not bullets** — unless there are genuinely 3+ parallel items. Short
sentences. Vary the rhythm; don't make every line the same length.

**Match the language.** PL stays PL, EN stays EN, mixed stays mixed — never
normalize. English tech terms inside Polish are natural (deploy, build, revert,
CI, stage); keep them.

**Close on status, not flourish.** End where it stands ("should be good now",
"powinno już śmigać", "reverted, fixed", "czekam na CI"). Greg uses emoji and
kaomoji freely and naturally — `:D`, `XD`, `:)`, `:pray:` on bumps — so keep
them when they fit the mood; just don't bolt one on as a fixed signature. The
style carries the message, the emoji rides along.

**Em dashes are fine — Greg actually uses them.** He writes "not a separate
job", "still need approvals —" himself. Don't let the humanizer pass robotically
strip every em dash to zero; keep the ones that read like his natural pause.

**Never inject typos to "sound like Greg."** His casual DMs are full of them
("THANS", "waht", "DOne") because he doesn't proofread chat — that's speed, not
voice. Outward text stays clean. Replicate the *casualness* (lowercase starts,
short bursts, live verbs), never the misspellings.

## Register range

Greg's real messages are bimodal, and the skill has to cover both ends:

- **Most are tiny** — a 2-to-6-word acknowledgment or reaction: "Coool!",
  "works for me", "yeh", "Sure no rush :)", "masz approve". When the input only
  needs an ack, give an ack. Don't inflate it into a sentence.
- **A few are structured deep-dives** — a point-first verdict, then a tight
  bullet chain carrying exact paths, line numbers, and limits. Bullets are right
  here, even at 2 parallel items ("Two fixes here: …").

Default to 1–3 sentences in between. Longer only when there are several
independent things to report — one short line each, still no padding.

## Examples across registers

Drawn from Greg's actual Slack, genericized. They show the *range*, not a mold —
don't pattern-match to any single one.

**Ack — the most common case:**

> Coool!

> works for me

> yeh Fridays are quite different :D

**Owning a slip, casually:**

> It works again after the demo XD

> my bad, didn't catch that — reverted, should be good now

**PR bump:**

> quick bump :pray: still need approvals from @team-a and @team-b

**Point-first question:**

> Still debugging why the Raycast cache access isn't working. I think I'll add a
> command to temporarily install the MCP in Claude — WDYT?

**Structured technical answer** — verdict first, then the specifics in a tight
chain:

> Confirmed — the sandbox runs inside the portal task, not a separate job.
>
> - each project deploys as its own job from the runner definition
> - the portal task runs the node server (docker driver)
> - an MCP request spins up the WASM sandbox in a worker thread *in that same
>   allocation* — no extra container
>
> So the model code runs in-process, isolated by the WASM VM and its limits
> (10s / 64 MB / call caps), not by a job-level boundary.

**Polish channel, full casual:**

> Nasz cykl też idzie fajnie, ale oczywiście milion zmian mieliśmy dzisiaj na syncu

> Zajebiście

Across all of them: the point led, specifics stayed, the register matched the
moment, and nothing got padded.

## Process

1. Find the point — conclusion first.
2. Cut everything that isn't the meat.
3. Run humanizer's AI-tell removal over what's left.
4. Rebuild in Greg's voice: casual, a bit expressive, specifics intact.
5. Match the language; close on status.

Deliver just the message, ready to paste — no "here's your message" preamble.
