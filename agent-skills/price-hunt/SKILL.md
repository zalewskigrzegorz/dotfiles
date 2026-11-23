---
name: price-hunt
description: Find a product cheaper than the price Greg is looking at, comparing final delivered totals across Allegro, eBay, AliExpress and clones, Amazon.de and OLX. Use on "znajdź taniej", "gdzie taniej", "czy jest gdzieś taniej", "porównaj ceny", "find it cheaper", or a product page / part number with a price question. Not for leasing or car offers.
---

# Price hunt

Totals, brutto/netto, source labels, conversion rate, "bez wysyłki, nie sprawdzone": rule `money-figures.md`. WebFetch 429/empty → `browsentic` in the same turn: rule `browser-stacks.md`.

## Start

- Baseline = the product page Greg has open, read via `browsentic` (`page_getPageInfo`, `page_extractText`): exact model, part number, variant, price **with shipping to Poland**. No page → ask for the link or part number in one line.
- One sentence: "szukam <model>, part <number>, baza <kwota> brutto z wysyłką".

## Search all, then report once (no popup between shops)

Allegro (filter "Nowe" unless used is fine) → eBay (shipping shown at checkout) → AliExpress, Temu, Banggood (generic items, parts) → Amazon.de/.pl → OLX (used). A shop behind a captcha gets "captcha" in the table.

- From outside the EU: check whether the cart includes VAT (IOSS up to €150); if not, add 23% VAT + the carrier's customs fee, marked `szacunek`.
- Sort by total only.
- Substitutes only with confirmed compatibility (listing names the exact model/part, or the maker's list); otherwise leave out or mark "zgodność niepotwierdzona". DIY only when he asks.

## Report

One table: shop, offer (link), total, brutto/netto, source, delivery time, condition; cheapest first, baseline row marked. One line under it: the cheapest real option and the saving. Never add to cart or pay.
