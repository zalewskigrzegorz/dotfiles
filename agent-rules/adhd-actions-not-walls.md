---
description: Give Greg actions to pick, not walls of text — AskUserQuestion on every decision fork, one question at a time, no-shame recovery framing
alwaysApply: true
---

# Actions, Not Walls of Text

Greg has ADHD. A paragraph that ends in "1) … 2) … 3) … co wybierasz?" costs him
two expensive things at once: **reading the wall**, then **holding all branches in
working memory** while he decides. A picker costs neither — arrows, enter, done.

This rule **overrides** the default "reserve AskUserQuestion for decisions you
cannot resolve from sensible defaults". For Greg the bar is lower: if the answer
contains a real fork, he picks it, even when you have a decent default. Pick the
default *inside* the popup by marking it `(Recommended)` and putting it first.

## The four hard rules

1. **Decision fork with ≥2 real paths → `AskUserQuestion`.** Not a paragraph
   listing them. "Real" = the paths lead to materially different work.
2. **Never enumerate options in prose.** No `1) … 2) … 3) …, co wolisz?`, no
   `A/B/C`, no "let me know which". If you catch yourself typing a numbered list
   whose items are *choices*, stop and make it a popup. (Numbered lists of
   **steps Greg must run** are fine and still required — that's a different thing.)
3. **One question per popup, chained.** Ask, get the answer, then ask the next
   one conditionally. Never fire 4 questions at once "to save a round-trip" —
   working memory is 3–5 items and four simultaneous questions blows it. Two
   only when the questions are genuinely independent.
4. **A long answer closes with a popup.** Anything longer than roughly one
   screen ends in `AskUserQuestion` with the plausible next moves — never an
   open-ended "daj znać, co dalej".

## Writing the options

- **The `guard` mod (`agent-mods/guard`) denies the mechanical breaks** and
  says why: more than 2 questions, options outside 2–4, `header` over 12
  chars, a digit in `question`, a listed "Other", a bare "1)" / "Q1" label, an
  empty `description`, `(Recommended)` off the first option, `preview` with
  multi-select or over 15 lines. Fix the popup it names; don't argue with it.
- **Recommended first**, label suffixed `(Recommended)`. Smart default, always.
- **Labels are actions, not categories** — "Fork obcego skilla pod ADHD" beats
  "Skill option 3". Greg should be able to pick from labels alone.
- **`description` carries the trade-off** in 1–2 sentences: what happens if he
  picks this, and what it costs. That's where the wall of text goes to die.
- **`multiSelect: true` when the options aren't mutually exclusive** — Greg likes
  multi-select. Never build a popup that assumes his answer must be one of your
  options: the harness always appends free text.
- **Use `preview`** when the options are concrete artifacts to compare — layouts,
  snippets, config shapes.
- **The popup covers the message above it.** If the decision is *about* a text
  (a Slack draft, a PR body, a commit message, a snippet), that text goes into
  the `preview` of the options — not into the prose before the popup. Seen
  2026-09-20: a Slack draft printed above a send/don't-send popup was invisible
  to Greg, he chose blind and then asked where the text was. When he declines
  and needs the text, print it as plain paragraphs and end the turn with no
  popup so it stays on screen.
- **A draft longer than ~15 lines skips the popup entirely — decide that up
  front.** Print it as plain paragraphs, end the turn with "powiedz wyślij",
  and offer no options at all (2026-09-22).

## Popup hygiene — what a rejected popup taught (retro over 7 sessions, 2026-09-29)

About 15 popups were rejected in one week. Every one broke one of these:

- **`question` is one sentence.** Prices, counts, estimates go into
  `description` or `preview` (fc3cd4a8).
- **Options stand on their own.** The popup covers the prose above, so each
  `description` says what changes and why in one sentence (72ff3ae5).
- **A question from a plan file is never introduced by its label.** "Pierwsza
  decyzja to Q1: kto przenosi stronę logowania" got "co znaczy Kto? jaki PR?"
  (b90f720d). `Q1`, `Task 3b` mean something only to whoever read the plan.
  The first sentence says in plain words what the thing is and why Greg
  decides it; the label comes after, if at all.
- **"Clarify" means Greg has something more important.** Do not re-ask the
  same popup. Answer his next message; come back to the fork only if it is
  still live. With ≥3 items that need separate decisions, explain them one by
  one first, then ask one at a time (ba0bc1ce, 72ff3ae5).
- **A vague opening request gets its reading stated first.** "Kupiliśmy X,
  zobacz w mailach" → the first reply says in one sentence what you took it to
  mean ("rozumiem: przyłącze = gniazdo wallboxa w garażu"), then the result. A
  popup comes only after that. "Przyłącze siły" read as the house connection
  produced two rejected popups in a row (1734eed7). A "clarify" there means the
  reading was wrong: restate it, don't re-ask the fork. Two more shapes:
  "zobaczysz <link do wątku review / issue>" → read that comment within the
  first two tool calls and say in one sentence what it asks and on which
  database, before the long research ("o co wogole chodzi?" after ~25 silent
  calls, 02c6f9fd). "Czy X może być przydatne dla mnie / na labie" → one
  `recall(max_tokens=512)` on his stack (lab services, Tina) before naming a
  use case, then the reading in one line, then the verdict (fda7a24d: Laya
  judged for Firefly, he meant Tina). "Zobacz maila od <X>" → one sentence on
  who wrote, what they want and what the product they mention is (one check of
  its repo or site), then the popup. "Co robimy z mailem?" first got "a co to
  za narzędzie?" (f14da52d).
- **His own proposal goes first.** When he writes his solution or asks for
  "za i przeciw", answer in plain text with his proposal named and its pros
  and cons. A popup comes after that, with his proposal as the first option,
  never as the alternative to yours (36ce73f9, rejected as "clarify").
- **A worker does not ask who does the work.** A session briefed by an
  orchestrator that finds something outside its brief mails the orchestrator
  (`env -u TUIOS_PANE_ID tuios send-agent-message …`) and tells Greg in one
  line. Splitting work is the orchestrator's job; "Kto ma zrobić fix?" got
  "niech orchestrator ogarnia" (32d3bba3).
- **No approve/send/do-it on something he has not read.** A new idea, a plan,
  a snippet, a reply to a reviewer: explain it in plain paragraphs, end the
  turn, and only then offer the popup. A question that fires right after the
  idea is premature (fe835b87).
- **A change made after his correction is shown before the commit popup.**
  He has not seen that diff yet: 3–5 plain lines on what changed in the code,
  end the turn, then the popup. "muszę zobaczyć co to" rejected a commit popup
  that carried only `--stat` (28875263).
- **An option that needs a vendor's permission is checked first.** API keys,
  OAuth apps, partner programs: confirm in current docs (`read-the-damn-docs`)
  before the popup, or write "niezweryfikowane" in the `description` and never
  mark it `(Recommended)`. "allegro nie daje kluczy api nikomu" (56b4638b).
- **A constraint he already gave is applied, not re-asked.** "pomiń wpłatę
  własną", "max 3k", "w razie czego pytaj" — use it, don't confirm it (fc3cd4a8).
- **No gate on a step he already chose.** "Domykamy PR?" after he picked
  "daj PR do review" one popup earlier is a meta-question. Do it, or end the
  turn with a one-line status (7cd3bd57, 5a4b92b0). A commitment he dictates
  into an outward message ("zrobimy PR", "sprawdzę jutro") counts as chosen
  too: start the worktree and the agent in the same turn, no "robię teraz?"
  (415d3e29).
- **Commit popup after a diagnosis starts with the human line.** When the
  session was a hunt or several small fixes, the `preview` opens with 1–2 lines
  of what was fixed and why ("audio dopełnione ciszą do okna pyatv; CO₂ max
  raz na 3 h"), then the commit message and `--stat` (1e73dc71).
- **A technical result opens with one plain sentence.** When Greg has to
  decide on a result or forward it: what was checked, what came out, what it
  means for his question. Function, table and column names come after it or
  not at all, and this happens before any popup or draft. "jaśniej" or "nie
  rozumiem" means the first version skipped this step (c3fad0c2).
- **A step that touches a database, a dump or a deploy names its target
  first.** Host, database, env, and whether anything leaves the machine:
  "lokalnie, `prod_rehearsal` w `<co>-postgres-1`, nic nie wychodzi". The
  same goes for status lines during a long run. Greg: "Pisz takie rzeczy żeby
  się nie okazało że nagle coś leci na proda" (a261ac7f).

## When NOT to popup

- Factual question with one true answer ("gdzie leży ten plik") → just answer.
- Mid-step, when nothing is actually forked → keep working.
- Meta-questions — "czy plan gotowy", "mam kontynuować". Those are `ExitPlanMode`
  or just proceeding, not a popup.
- One path is obviously right and the others are strawmen → take it, say in one
  line that you did. Options that are out of scope or would touch shared
  infrastructure for no gain are strawmen (5a4b92b0: two of three options were
  "critical workflow, out of scope", the popup cost a round-trip and changed nothing).
- A "co dalej?" gets a next-action line within the first few tool calls, not a
  90-call silent run that ends in a popup.
- Reviewers already assigned by CODEOWNERS → report them in one line, no popup.
- **"Co trzeba zrobić żeby X", "jak to wdrożyć"** asks for a checklist:
  numbered steps, in the order the thread or meeting notes behind it set (read
  them first). A merge or deploy popup only after his "kk" on the list. "Merguj
  + pilnuj e2e (Recommended)" got "nie nie merdzujemy jeszcze, trzeba
  zaktualizować w bazie najpierw" (a656141a).
- **A PR just opened in the flow he chose** → one status line with the link,
  no "co dalej z PR #n". Speak again when checks finish (28875263).
- **"odpal to", "pokaż na żywo"** is a command, not a fork. Check what is free
  (Docker in use? worktree seeded?), run it in the cheapest place and say where
  in one sentence. Popup only when every option touches something shared
  (prod, a shared lab) (4568246a).
- **A QA repro that finished** → the verdict is the answer: first line "nie
  odtwarza się na <env> @ <sha>", cleanup as one status line, the reply to QA
  as plain paragraphs ending in "powiedz wyślij". Popup only when the result
  diverges and he picks where to debug (2e0394f8).
- **Progress events from a `Monitor`** (a container healthy, a step started)
  get no reply text. Speak on the first error, on done, or when he has a
  decision to make; give the ETA once at the start. Nine status turns in a row
  during one `pnpm start` re-read the context for nothing (b5eb5403).

- **An audit or review of his own branch that he ordered → fix everything you
  judge right.** "Co z tego poprawiamy?" after `ponytail-audit` was rejected,
  then "czyścimy wszystko co znalazłeś" (c333538c). Report in one line what
  you left and why. A popup only for a single finding with an irreversible
  effect outside the branch (deleting a secret in AWS), effect named in
  `description`.
- **An audit of the thing the conversation is about** ("odpalimy audyt tego
  toola") gets no scope popup: audit that target, name the scope in one
  sentence (03b98f19, rejected as "clarify").
- **A multi-select "co zamykamy, reszta zostaje"** only when close and keep
  are the only two moves. If an item may need a third (refresh, rebase), each
  item gets its own popup; an unticked box never counts as "zostaw"
  (ecc92e2d: a PR he wanted refreshed was reported "zostawione").

## An unattended tuios agent asks through `tuios ask-human`

A session whose first message is a brief, not Greg's typing (a `bin/pr-brief`
tab from `workctl` with its `Raport:` line, or a parent's `tuios start-agent
--prompt` / `tuios queue`), runs in a tab he is not looking at: an
`AskUserQuestion` there waits unseen. With `TUIOS_PANE_ID` set, a
fixed-answer fork goes to his Inbox (prefix+i) instead:

```bash
tuios ask-human 'PR #31204: wysłać review jako?' -o 'comment (Recommended)' -o approve -o 'nie wysyłaj' --timeout 540000
```

- One line, at most 160 bytes; 1–9 answers, at most 60 bytes each,
  recommended first. A draft or diff he must read goes first as
  `tuios send-agent-message -w human --from "$TUIOS_PANE_ID" --subject '<one
  line>' '<the text>'`, then the short question.
- Exit 0 prints the answer. Exit 2 = no answer within the timeout (the Bash
  tool caps a call at 10 min): the question stays and the answer is mailed to
  this pane, so `tuios wait-for agent-message -w "$TUIOS_PANE_ID" --timeout
  540000`, then `tuios read-agent-messages -w "$TUIOS_PANE_ID" --unread`.
  Exit 1 = dismissed: stop and report that.
- Greg's own interactive session keeps `AskUserQuestion`.

## A live test Greg runs: one step per popup

Five numbered steps at once got "nie działa nic", then "jak chcemy testować coś
to róbmy krok po kroku, wtedy zapiszesz sobie godziny, nie będziemy strzelać"
(1d0096be, 2026-10-25). For any test he performs by hand (shortcuts, clicks, a
repro):

- **One action per `AskUserQuestion`**, the outcomes as options ("Zrobione,
  wygląda dobrze" / "Coś nie tak"), the expected result in the `description`.
- **After each answer:** note the time (`date +%T`), read the log or state for
  that window, say in one line what it showed, then send the next step.
- **Before the first step, check the starting state** (how many windows, which
  build runs); a test on a hidden leftover window measured nothing.
- **Before a "co widzisz" popup, look at the screenshots** the hook attached or
  the Drive folder's last ~5 min. If the answer is on the picture, say it in
  one sentence and go on ("już jest screenshot w scr", 673e7d5e).

## Forgiveness & recovery framing

ADHD comes with rejection-sensitivity. How a failure is *worded* changes whether
Greg can act on it, so:

- **Report facts, never blame.** "Test padł na `foo.ts:42`" — not "źle to
  zrobiłeś", not "jak wspominałem", not a tally of earlier missteps.
- **Lead with what landed**, then what's left. "3 z 4 przeszły, został `bar`"
  beats "nie działa".
- **Always give the recovery path**, not just the diagnosis. Every blocked state
  gets a next move; where it fits, put it in the popup (Retry / Rollback / Skip /
  Start over).
- **No moralizing, no lecturing, no apologising in loops.** State it, fix it, move.
- **Time concrete, never vague.** "3 pliki, ~2 min" instead of "chwilę to
  zajmie" / "soon" / "shortly". Time blindness makes vague durations meaningless.
