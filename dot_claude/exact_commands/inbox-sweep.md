---
description: Sweep Greg's mailbox — verify pending unsubscribes, classify noise senders, then unsubscribe / block via Spark, bulc.club and agent-browser. Explicit-invoke command; nothing runs without a confirmation popup.
---

# inbox-sweep

Monthly, or when Greg says the inbox is loud. Find noise senders, decide unsubscribe / block / keep, act through whatever works for that sender, record it so the next run checks they obeyed.

## Hard rules

1. Never archive, delete or move a message: only unsubscribe, block, mark priority (all reversible).
2. Never click an unsubscribe link in spam (confirms the address); spam gets blocked.
3. Never enter a password, create an account or solve a captcha: login wall → BLOCKED for that sender.
4. Nothing executes before the plan popup.
5. `never_touch` and already-primary senders are skipped before classification.

## Ledger

`~/.local/state/inbox-sweep/ledger.json` (v2), the only state. Top level: `never_touch`, `vip_primary` (the cumulative white list; never re-derive it from one run). `runs[]`: `blocked`, `unsubscribed`, `spared`, `findings`, each action with `verify_after` +14 days.

First run (no file, don't hunt with `fd`): create it and say "pierwszy bieg, brak ledgera":

```bash
L=~/.local/state/inbox-sweep/ledger.json
test -f "$L" || { mkdir -p ~/.local/state/inbox-sweep && echo '{"version":2,"runs":[],"never_touch":[],"vip_primary":[]}' > "$L"; }
```

Defensive `jq`: version is `version` (not `schema`); `blocked[]`/`unsubscribed[]` hold strings (old) or objects keyed `sender`/`domain`/`contact` → `.blocked[]? | objects`; `(.verified // false)`.

## 0. Verify the last run

For each action past `verify_after`: `spark search "<brand>" --in maksim009@gmail.com` for mail after the action date. None → `verified: true`. Still arriving → escalate one rung (polite unsubscribe → bulc `/ba/` → bulc `/bd/` → `spark contact-action blockDomain`), shown in the plan popup.

## 1. Scan

Wrap pipelines in `bash -lc '…'` (nushell doesn't word-split).

```bash
spark emails Archive --filter "newer_than:120d" --page N --page-size 100   # same for Inbox; 365d for the long tail
```

Delegate paging to a read-only subagent (`emails`, `search`, `thread`, `folders`) that returns one compact table. Group by leading display name (`From` truncates at ~30 chars); real address via `spark thread <id>`. **Gmail-only:** marketing to `zalewski.grzegorz@icloud.com` never shows; say so in the report.

## 2. Classify

| Signal | Bucket |
|---|---|
| transactional history (order, invoice, shipping, login code, device alert) | **keep** |
| unsubscribe header/link + a real purchase or account | **unsubscribe** |
| no transactional history and no unsubscribe link (fresh/rotating domains) | **spam**: block, browser never runs |

Device/account alerts on the marketing domain (SwitchBot) → keep the whole domain. A shop he may buy from again → block the address (`/ba/`), never the domain.

## 3. Present, one popup

Verdict as text, grouped, with volume and last-seen; then one `AskUserQuestion` over groups (unsubscribe N newsletters / block N spam domains / sort N notification senders). A second popup only for the 3–6 genuinely conflicting senders; never one per sender.

## 4. Execute, cheapest rung first

a. **Spark header unsubscribe:** `spark action unsubscribe <id> …`, batched; `Skipped` = no `List-Unsubscribe`, not an error.

b. **bulc.club relay** (`relay@bulcclub.com`; Spark's blocklist fails on it): `spark thread <id> | grep -oE "https://www.bulc.club/(ba|bd)/[^)]*"`. Links need his session (curl gets the login page): `browsentic` `page_openTab` on the first, then `page_navigate` + `page_extractText` (~300 chars) per link, `page_closeTab` at the end. The page text (`YOU'VE (ALREADY) BLOCKED THIS DOMAIN`, rating, counters) is the confirmation to record. `/ba/` and `/bd/` share a token; prefer `/ba/`.
   - Member console `members.bulc.club`: its Block buttons never fire under automation (JS click, CDP click, bulk menu; 2026-08-31) and a row's `disabled` state verifies nothing. Read it only: `#/forwarders/N` (100 rows/page) and a forwarder's Statistics view find leaked aliases; scrape with `page_extractText`, act via footer links.
   - Gmail filters: not via XML import (the file picker never appears). One at a time: `#create-filter/has=<query>`, toggle checkboxes with `Space` (JS `.click()` is ignored).

c. **Direct senders:** `spark contact-action blockDomain|blockContact <addr>` → Gmail `Blocked` label, reversible with `acceptDomain`/`acceptContact`.

d. **Body-link unsubscribe** (~90%): a subagent with the `agent-browser` skill, only the approved URLs, safety rules restated, one screenshot and one-line result per target, no HTML or snapshots back. Shapes: Klaviyo → `manage.kmail-lists.com`, one click; TrustMate confirm gate then YES (idempotent); Insta360 button inside an iframe; some are a plain GET.

e. **White list:** `spark contact-action markContactAsPrimary <addr> …`.

## 5. Record the run

Date, blocked (how), unsubscribed (confirmation text), spared (why), `verify_after`, new mechanisms in `findings`:

```bash
f=~/.local/state/inbox-sweep/ledger.json; cp "$f" "$f.bak-$(date +%F)"
jq --slurpfile run <scratch>/run.json '.runs += $run' "$f" > "$f.tmp" && jq empty "$f.tmp" && mv "$f.tmp" "$f"
jq '.runs | length' "$f"
```

## Known facts (measured)

- Spark unsubscribe covered 4 of 40 newsletters (needs `List-Unsubscribe`); bulc strips that header, so no bulc mail is reachable by Spark unsubscribe or blocklist.
- Spark has no rule engine: only per-contact/per-domain rules keyed on the sender. Recipient-side rules (plus-tags, alias domains) go to Gmail filters or Cloudflare Email Routing.
- bulc aliases: `<alias>@zinsoft.bulc.club`, `(alias)` prefix on subjects; `--filter "subject:(alias)"` fails on hyphens. Aliases carry several senders (`allegro` also InPost, Poczta Polska; `emp` also DHL): never kill one wholesale.
- 402 forwarders, 25 477 messages lifetime, 35 used in 90 days, 194 silent 3+ years; `kickstarter` + `allegro` = 39% of traffic. Leaked alias: `kickstarter` got mail from 134 domains (real one ~1/12): block the ring domain by domain, never `Block All` an alias that carries orders.
- A domain block holds for every member at bulc rating 100%, only for Greg at ~50%. Never block shared ESP relays (`shared.klaviyomail.com`): block the address.
- AliExpress: promo on `selections.`/`mail.`/`newarrival.aliexpress.com`, `promotion@`, and member-benefit promo now on `notice.` too. Working filter: `from:(aliexpress.com) -from:(transaction@notice.aliexpress.com)` → Blocked.
- His DNS blocklist NXDOMAINs tracking domains (`click.revolut.com`, `campaign.synerise.com`): a "dead link" counts only if it also fails on `1.1.1.1`.
- Kick unsubscribe returns a JSON error: go straight to bulc `/ba/` on `***@notifications.kick.com` (~33%, holds for Greg only) and note it in `findings`.
- `*@mrglaszki.com` is his own Cloudflare Email Routing (`mail.mrglaszki.com`): report, don't touch.
