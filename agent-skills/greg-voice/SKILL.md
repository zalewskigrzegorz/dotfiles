---
name: greg-voice
description: |
  Rewrite outward-facing text into Greg's own writing voice — casual,
  point-first, just the meat — and strip the AI tells in the SAME pass. This is
  the single voice gate for everything that leaves his machine: PR titles and
  bodies, PR review summaries and inline comments, replies to reviewers, GitHub
  issue bodies and comments, release notes, and Slack messages, replies, status
  updates and recaps. Trigger it whenever you are about to post, create, send,
  or hand over prose that another human will read — Greg should never have to
  ask, and the text almost never says "Slack". Also triggers on "napisz to po
  mojemu", "podsumuj to na slacka", "skróć to", "luźniej", "dosadnie", "tylko
  konkrety", "just the meat", "casual style", "shorten this", or when a draft
  reads too long, too stiff, or over-explained. Do NOT run the `humanizer` skill
  before or after this one — AI-tell removal is built in here, and a second
  rewrite pass flattens the voice back out.
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
template for one kind of message.

**One pass, not two.** Removing the AI tells and putting Greg's tone in are the
same edit, done together. Running `humanizer` first and this second is the old
flow and it actively hurts: humanizer flattens the live verbs, the em dashes and
the uneven rhythm that this skill then has to rebuild, so the text needs a
second trip to come out right. Do the whole thing here, in one rewrite.

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
job", "still need approvals —" himself. The AI-tell rule about em dashes says to
cut them; that rule is overridden here. Keep the ones that read like his natural
pause, cut only the ones stacked for rhythm.

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

## One register, everywhere — including code review

There is no "technical mode". PR review comments, inline comments on a diff,
replies to reviewers and verdict rationales all get the **full voice** — that is
the entire point. A review comment should read like Greg typed it in the PR:
point first, casual, a bit expressive, owning things plainly.

Being casual does not mean being vague. The exact path, line number, version and
limit stay in — that is the meat. What goes is the stiff register around them:
"It appears that this implementation may not correctly handle…" becomes "this
breaks when the list is empty — line 42".

Never flatten review text into a neutral senior-engineer note "because it is
technical writing". That reads like a bot and is the thing this skill exists to
prevent.

## AI tells — same pass, with carve-outs

The pattern catalogue lives in the `humanizer` skill; read it as reference, do
not invoke it as a separate step:

- `~/.claude/skills/humanizer/SKILL.md` — the twelve that fire on most text
  (AI vocabulary, negative parallelism, rule of three, em dashes, boldface,
  sycophancy, filler, hedging, generic conclusions, signposting, aphorisms,
  rhetorical openers). This is usually all you need.
- `~/.claude/skills/humanizer/references/patterns-longtail.md` — 21 more, worth
  a look on long-form text or when a draft still reads synthetic.

Three of those rules are **overridden** by the voice and must not be applied
literally, because they strip exactly what makes the text sound like Greg:

| Rule | Override |
|---|---|
| Em dashes: cut them | Keep his natural pauses; cut only stacked-for-rhythm ones |
| Vary sentence length / no fragments | Short bursts and one-word reactions are his register |
| Emojis: remove | He uses `:D`, `XD`, `:)`, `:pray:` naturally — keep them where they fit |

Everything else in the catalogue applies as written.

## Process

1. Find the point — conclusion first.
2. Cut everything that isn't the meat.
3. Rewrite in Greg's voice **and** clear the AI tells in that same edit: casual,
   a bit expressive, specifics intact, carve-outs above respected.
4. Match the language; close on status.
5. Reread once against the twelve core tells. If something still reads
   synthetic, fix that line — don't rerun the whole rewrite, that is what
   flattens it.

Deliver just the message, ready to paste — no "here's your message" preamble.
