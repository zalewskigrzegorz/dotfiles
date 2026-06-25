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

**Prose, not bullets** — unless there are genuinely 3+ parallel items. Short
sentences. Vary the rhythm; don't make every line the same length.

**Match the language.** PL stays PL, EN stays EN, mixed stays mixed — never
normalize. English tech terms inside Polish are natural (deploy, build, revert,
CI, stage); keep them.

**Close on status, not flourish.** End where it stands ("should be good now",
"powinno już śmigać", "reverted, fixed", "czekam na CI"). An emoji is fine
only if Greg already used one or it genuinely fits — never bolt one on as a
signature. The style carries the message, not the emoji.

## Length

Usually 1–3 sentences. Longer only when there are several independent things to
report — then one short line each, still no padding.

## One illustration

This is a single example to show the transformation, not the mold. The same
voice applies to any short message.

**Input** (too long, too formal):

> Ok so Stage didn't crash at runtime, so there was nothing to chase on Nomad.
> It broke earlier, in CI, during the Docker build for caddy-public. The
> Deploy BH Stage run (28179414187) failed on
> `nx run caddy-public:docker:build` at the xcaddy build step with exit code 1.
> Here's why. PR #24334 bumped caddyserver/caddy/v2 from 2.11.1 to 2.11.4 in
> packages/redocly-auth/go.mod. But apps/caddy-public/Dockerfile builds on a
> CVE-pinned, SHA-locked caddy:2.11.3-builder-alpine. So the redocly-auth
> plugin asks for caddy 2.11.4 while the builder only has 2.11.3. xcaddy
> refuses to compile, no image comes out. I made revert and now should work.

**Output** (Greg's voice):

> My bad — didn't catch that PR #24334 bumped `caddyserver/caddy/v2` to 2.11.4
> in `redocly-auth`, while the `caddy-public` Dockerfile is SHA-locked to the
> 2.11.3 builder, so xcaddy blew up in CI and stage never got a fresh image.
> Reverted it, should be good now.

The point led, the red herring and trivia went, the specifics stayed, "my bad"
and "blew up" carried the casual energy, and it closed on plain status.

## Process

1. Find the point — conclusion first.
2. Cut everything that isn't the meat.
3. Run humanizer's AI-tell removal over what's left.
4. Rebuild in Greg's voice: casual, a bit expressive, specifics intact.
5. Match the language; close on status.

Deliver just the message, ready to paste — no "here's your message" preamble.
