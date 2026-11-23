---
description: Filled documents with personal data (contracts, applications, forms) go to the matching Dom/<topic> folder on Drive, never to bazgroly
alwaysApply: true
---

# Filled Documents With Personal Data Go to Drive, Not bazgroly

bazgroly is pushed to GitHub, so a contract, application, form or letter with personal data is a document for people, not an AI artifact. Its home is `D=/Users/greg/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Dom/`; list it (`find "$D" -maxdepth 2 -type d`) and use the matching folder, never a new top-level one:

| Document | Folder |
|---|---|
| car sale, insurance, service papers | `Samochody/<car>` (`Fiesta`, `Elroq`) |
| inheritance, court, kancelaria | `Dziedziczenia/<person>` |
| contracts with people and vendors | `umowy/<party>` |
| anything Greg will print | a copy in `Do wydrukowania` too |
| scans in | `Skaner` (read-only for agents) |

A topic with no folder → one line asking which existing folder.

1. **Every field filled, nothing blank for Greg** ("nie uzupełniamy ręcznie, wszystko wpisujemy, ja będę podawał, tylko pytaj", 5666f824). PESEL, ID number, address, account number go into the Drive file. Collect first from `Skaner` scans, Spark, SMS (`chat.db`, ops-traps), never asking him to retype a scan; ask the rest in groups (buyer, terms, the car's legal state), one popup each, write each answer in at once and regenerate the PDF in both folders. A field nobody can know gets a question, never an empty line.
2. **bazgroly keeps the draft only**, as `.md` with personal fields as placeholders.
3. **Report both paths**, each one complete absolute path, plus any placeholder still open.
4. **Printing**: `lpstat -p -d`; no printer configured on this Mac → say so and give the `lp <path>` line. Never print on your own.
5. Drive sync lags: `ls` the target once after writing, don't re-write on a first miss.
6. **Scans and attachments of a family, court or notary case** (death certificate, court papers, rulings) go to `Dom/<folder>` or the session scratchpad, never bazgroly (5b71991d); its note holds no address, PESEL or third-party names. Before ending: `git -C ~/Code/personal/bazgroly ls-files | rg -i '\.(pdf|png|jpe?g)$'` shows nothing from this case.
