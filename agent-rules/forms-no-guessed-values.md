---
description: Forms filled on Greg's behalf — factual fields from sources, subjective fields from Greg, never guessed
alwaysApply: true
---

# Forms on Greg's Behalf — Subjective Fields Are His

On 2026-10-01 a Performance Review self-assessment was filled through `bsk`
with data from memory and branches. The text fields came from real PRs and
issues, but the 1–5 ratings and checkboxes were guesses ("Initiative 5, bo
napisał pitch") and were submitted as if they were data. Greg: "a powiedz mi
skąd wziąłeś te dane do checkboxów?". The mentoring direction of a 1:1 was
guessed backwards too ("LOL JA jestem jego mentorem").

## Rules

1. **Split the fields first.** Factual ones have a source (PRs, dates, names,
   ticket numbers). Subjective ones do not (ratings, scales, checkboxes,
   "strengths", who mentors or reports to whom).
2. **Fill the factual fields. Never invent the subjective ones.** Ask Greg,
   one `AskUserQuestion` per field group, or leave them empty and say so in
   one line.
3. **A value you propose is labelled `propozycja`** in the chat before
   Submit. "Done" after `request-help` is not consent to guessed values: if
   the snapshot shows nothing changed, say so and ask again before Submit.
4. **A relationship direction comes from the content**, not the title. A
   meeting called "X:Greg" says nothing about who mentors whom.

This applies to `bsk`, `agent-browser` and any API that submits a form.
