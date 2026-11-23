---
description: Every amount carries brutto/netto and its source (offer, configurator, estimate) — no bare numbers in leasing, tax or budget answers
alwaysApply: true
---

# Money figures: label the tax status and the source

In a leasing thread Greg had to ask "czy to potwierdzone info i mówimy o cenie
brutto?" and "ta 85 taniej niż w Lellku u nich?" because a 3 968 zł instalment
from the dealer's PDF stood next to "ok. 3 120 zł" from the configurator with
nothing telling them apart (2026-09-24).

- Every amount in prose, a table or a popup says **brutto** or **netto**.
- Every amount says where it comes from: `oferta` (a document or mail),
  `konfigurator` (the vendor's tool), `szacunek` (our arithmetic).
- A recommendation never rests on a `szacunek` without saying so.
- Currency conversions state the rate used (`przy 3,67`). Amounts for Greg are
  in zł first, the foreign one in parentheses: "~37 zł (7,70 CHF)" (db368cfb).
- A price of goods is the final sum (goods + shipping + VAT / duty). Shipping
  unknown → "bez wysyłki, nie sprawdzone" in the same line. Shops are compared
  by the final sum ("$39" came without €20 shipping, 45126c6e).
