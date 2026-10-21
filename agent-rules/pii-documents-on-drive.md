---
description: Filled documents with personal data (contracts, applications, forms) go to the matching Dom/<topic> folder on Drive, never to bazgroly
alwaysApply: true
---

# Filled Documents With Personal Data Go to Drive, Not bazgroly

bazgroly is pushed to GitHub, so an agent that fills a car sale contract left
the seller's PESEL and ID number blank on purpose and Greg had to ask where
the contract was (2026-10-21). A contract, an application, a form, a letter
to a kancelaria is a document for people, not an AI artifact: the bazgroly
rule does not cover it.

## Where

`/Users/greg/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Dom/`
already has the hierarchy; list it (`ls -1 "$D"`, `find "$D" -maxdepth 2
-type d`) and put the file in the folder that matches the topic, never in a
new top-level folder:

| Document | Folder |
|---|---|
| car sale, insurance, service papers | `Samochody/<car>` (`Fiesta`, `Elroq`) |
| inheritance, court, kancelaria | `Dziedziczenia/<person>` |
| contracts with people and vendors | `umowy/<party>` |
| anything Greg will print | a copy in `Do wydrukowania` as well |
| scans in | `Skaner` (read-only for agents, see `screenshots-location`) |

A topic with no folder yet → one line asking Greg which existing folder, not a
new one.

## Rules

1. **Fill the personal fields there.** PESEL, ID number, address, account
   number go into the file on Drive; the agent reads them from the scans in
   `Skaner` or from Spark, it never asks Greg to retype what a scan holds.
2. **bazgroly keeps the draft only**, as `.md`, with the personal fields as
   placeholders, so the reasoning and the template source stay searchable
   without the data.
3. **Say both paths in the report**, each as one complete absolute path, and
   the list of placeholders still open (buyer, price, date are usually Greg's).
4. **Printing:** `lpstat -p -d`; no printer configured on this Mac
   (2026-10-21) → say so and give the `lp <path>` line for after Greg adds
   one. Never print on your own.
5. Drive sync lags: after writing, `ls` the target once; don't re-write on a
   first miss.
