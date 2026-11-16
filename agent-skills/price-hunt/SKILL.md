---
name: price-hunt
description: Find a product cheaper than the price Greg is looking at, comparing final delivered totals across Allegro, eBay, AliExpress and its clones, Amazon.de and OLX. Use when he says "znajdź taniej", "gdzie taniej", "czy jest gdzieś taniej", "porównaj ceny", "find it cheaper", or sends a product page or part number and asks about price. Not for leasing or car offers (those have their own threads and money rules).
---

# Price hunt

From 45126c6e: the first answer quoted $39 / €35,10 without the €20 shipping
("to jest cena + shipping"), and every shop was a separate popup.

## Start

- The starting point is the product page Greg has open, read through
  `browsentic` (`page_getPageInfo`, `page_extractText`): exact model, part
  number, variant, and the price **with shipping to Poland**. That total is the
  baseline. No page? Ask for the link or the part number in one line.
- Say in one sentence what you are searching for ("szukam <model>, part
  <number>, baza <kwota> brutto z wysyłką").

## Search, no popup between stages

Go through all of these in one run, then report once:

1. Allegro (filter "Nowe" unless he wants used).
2. eBay (ships to Poland, shipping cost shown at checkout).
3. AliExpress and clones (Temu, Banggood) when the item is generic or a part.
4. Amazon.de (and .pl).
5. OLX for used.

A shop page that `WebFetch` answers with 429, an empty body or no price goes to
`browsentic` (`page_openTab` + `page_extractText`) in the same turn. No waiting
for the limit, no "try again" popup. A shop behind a captcha is skipped with
one word in the table ("captcha").

## Every price is a final total

- Total = item + shipping to Poland + VAT/customs. Label it **brutto** or
  **netto** and with its source: `oferta` (the shop's page or cart), `szacunek`
  (our arithmetic). Rule: `agent-rules/money-figures.md`.
- Shipping not visible → write "bez wysyłki, nie sprawdzone" on the same line,
  never a bare item price.
- From outside the EU: check whether the cart price already includes VAT
  (marketplaces collect it under IOSS up to €150). If not, add 23% VAT plus the
  carrier's customs fee and mark it `szacunek`.
- Currency conversion states the rate (`przy 4,25`).
- Compare and sort by the total only.

## Substitutes and DIY

- A different brand or a compatible part only with confirmed compatibility
  (the listing names the exact model or part number, or the manufacturer's
  compatibility list). Unconfirmed → leave it out or mark "zgodność
  niepotwierdzona".
- DIY (print it, repair, build) only when Greg asks.

## Report

One table: shop, offer (link), total, brutto/netto, source, delivery time,
condition. Cheapest first, the baseline row marked. Under it one line: the
cheapest real option and how much it saves against the baseline. Buying is
Greg's click: never add to cart or pay (browser-stacks rule 1).
