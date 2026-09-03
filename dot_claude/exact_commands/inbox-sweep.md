---
description: Sweep Greg's mailbox — verify pending unsubscribes, classify noise senders, then unsubscribe / block via Spark, bulc.club and agent-browser. Explicit-invoke command; nothing is executed without a confirmation popup.
---

# inbox-sweep

Periodic mailbox cleanup. Finds noise senders, decides unsubscribe vs block vs keep,
executes through whichever mechanism actually works for that sender, and records
everything so the next run can check whether they obeyed.

Run it monthly, or whenever Greg says the inbox is getting loud.

## Hard rules

1. **Never archive, delete, or move a message.** This command may only unsubscribe,
   block future mail, and mark contacts as priority. Everything it does is reversible.
2. **Never click an unsubscribe link on mail classified as spam.** A click confirms the
   address is live. Spam gets blocked, never asked politely.
3. **Never enter a password, create an account, or solve a captcha.** If a page demands
   a login, stop and report BLOCKED for that sender.
4. **Nothing executes before the plan popup.** Present the full verdict as text first,
   then one popup over grouped batches.
5. **The white list is untouchable.** Anything in `never_touch` or already marked
   primary is skipped before classification even runs.

## Ledger

`~/.local/state/inbox-sweep/ledger.json` (schema v2). Top level holds `never_touch` and
`vip_primary` — the cumulative white list, read before anything else. `runs[]` holds one
entry per run with `blocked`, `unsubscribed`, `spared`, `findings`. Every action carries a
`verify_after` date 14 days out. This file is the only state; there is no service.

Never re-derive the white list from a single run — read it from the top level.

## Step 0 — verify what the last run did

Read the ledger. For every `blocked` / `unsubscribed` entry whose `verify_after` has
passed, check whether mail arrived from that sender **after** the action date:

```bash
spark search "<brand>" --in maksim009@gmail.com
```

- Nothing new → mark `verified: true`, done.
- Still arriving → they ignored the unsubscribe. Escalate one rung:
  polite unsubscribe → bulc `/ba/` → bulc `/bd/` → `spark contact-action blockDomain`.

Report the escalations in the plan popup like any other action.

## Step 1 — scan

Shell is nushell and does **not** word-split. Wrap every pipeline in `bash -lc '...'`.

```bash
spark emails Archive --filter "newer_than:120d" --page N --page-size 100
spark emails Inbox   --filter "newer_than:120d" --page N --page-size 100
```

Widen to `newer_than:365d` when hunting the long tail — monthly and quarterly senders
look like one-offs in a 120-day window.

Delegate the paging to a subagent with a read-only brief (`emails`, `search`, `thread`,
`folders` only) and ask for one compact table back. The raw listings are large and do
not belong in the main context.

Group by the **leading display name** — the `From` column is truncated at ~30 chars, so
the domain is not readable there. Get the real address from `spark thread <id>`.

## Step 2 — classify each sender

| Signal | Bucket |
|---|---|
| transactional history (order, invoice, receipt, shipping, login code, device alert) | **keep** — never touch |
| `List-Unsubscribe` or a body unsubscribe link, plus a real purchase or account | **unsubscribe** |
| no transactional history, no unsubscribe link, fresh or rotating domains | **spam** — block, no clicks |

Safety default: **no transactional history AND no unsubscribe link → treat as spam.**
The browser does not run on those.

Signals that override volume:
- Device or account alerts on the same domain as the marketing (SwitchBot sends door-lock
  low-battery warnings and sale mail through one alias) → **keep the whole domain.**
- A shop Greg might buy from again → block the **address** (`/ba/`), never the domain.

## Step 3 — present, then one popup

Print the verdict as text, grouped, with per-sender volume and last-seen. Then a single
`AskUserQuestion` over the **groups**, not the senders:

- ☑ Unsubscribe from N newsletters
- ☑ Block N spam domains
- ☐ Sort N notification senders

A second popup only for senders where the signals genuinely conflict — usually 3–6.
Never one popup per sender.

## Step 4 — execute, cheapest rung first

**a. Spark header unsubscribe** — free, but only ~10% of mail carries `List-Unsubscribe`.
Batch it; unsupported ids come back as `Skipped`, which is not an error.

```bash
spark action unsubscribe <id> <id> ...
```

**b. bulc.club relay** — for anything arriving via `relay@bulcclub.com`.
`spark contact-action blockDomain` **cannot touch these** — Spark only sees
`relay@bulcclub.com`, so it returns `Failed`. Use the footer links instead:

```bash
spark thread <id> | grep -oE "https://www.bulc.club/(ba|bd)/[^)]*"
```

**The links need Greg's logged-in session — `curl` lands on the login page.** Open them
through `bsk` against his Comet profile instead, one per navigate:

```bash
bsk session start                                    # 4-letter id
bsk navigate "https://www.bulc.club/bd/<token>" --session <id>
bsk evaluate "document.body.innerText" --session <id> | head -c 300
bsk session stop <id>
```

The landing page states the outcome in plain text — `YOU'VE BLOCKED THIS DOMAIN` or
`YOU'VE ALREADY BLOCKED THIS DOMAIN`, plus the member rating and received/blocks/held
counters. That text is the confirmation to record; do not verify any other way.

`/ba/` and `/bd/` share the same per-message token. Prefer `/ba/`.

**Do not try the member console at `members.bulc.club`.** Its `Block Domain` /
`Block Address` buttons never fire under automation — measured 2026-08-31, no POST in
the network log from a JS `.click()`, from a real CDP click, or from the bulk
`Edit N Items` menu. The greyed-out `disabled` state on a dropdown item is that single
message's state, not a standing rule, so the same domain reads blocked on one row and
open on the next; it cannot verify anything.

The console is still worth reading. `#/forwarders/N` (100 rows/page) lists every
forwarder with last-used, distinct addresses, distinct domains, received and forwarded
counts, and a forwarder's Statistics view names its top sending domains — that is how
you find a leaked alias. Scrape it with `bsk evaluate`, act through the footer links.

**c. Direct senders** — Spark handles these:

```bash
spark contact-action blockDomain  <addr>   # whole domain
spark contact-action blockContact <addr>   # one address
```

Blocked mail lands under the Gmail `Blocked` label — still delivered, out of the inbox,
reversible with `acceptDomain` / `acceptContact`.

**d. Body-link unsubscribe** — the remaining ~90%. Delegate to a subagent running the
`agent-browser` skill, one brief listing only the approved URLs, with the safety rules
above restated. Ask for a screenshot per target and a one-line result each. Do not let
it paste page HTML or accessibility snapshots back.

Observed shapes: Klaviyo redirects to `manage.kmail-lists.com` and needs one click;
TrustMate shows a confirm gate then a YES link, and is idempotent; Insta360 keeps the
button **inside an iframe**; some tokens are a plain GET with no click at all.

**e. White list** — for anything that must never be lost:

```bash
spark contact-action markContactAsPrimary <addr> ...
```

## Step 5 — write the run to the ledger

Append a run object with the date, what was blocked and how, what was unsubscribed and
with what confirmation text, who was deliberately spared and why, and a `verify_after`
14 days out. Add any new mechanism discovered to `findings` — that is how this command
gets smarter between runs.

## Known facts (measured, do not re-derive)

- `spark action unsubscribe` needs a real `List-Unsubscribe` header. Measured coverage:
  **4 of 40 newsletters, 10%.** Everything else needs the browser.
- bulc.club relay strips `List-Unsubscribe`, so **no** bulc-relayed mail is reachable
  by Spark's unsubscribe or its blocklist.
- bulc alias addresses look like `<alias>@zinsoft.bulc.club`; the alias also appears as
  a `(alias)` prefix on every relayed subject line.
- Spark has no rule engine. Its only durable rules are per-contact and per-domain, both
  keyed on the **sender**. Recipient-side rules (plus-tags, alias domains) do not exist
  there — those belong in Gmail filters or Cloudflare Email Routing.
- `spark emails --filter "subject:(alias)"` fails when the alias contains a hyphen.
- Aliases are not one-to-one with senders: `allegro` also carries InPost and Poczta
  Polska, `emp` also carries DHL. Never kill an alias wholesale without checking.
- Greg has **402 bulc forwarders**, not the ~63 an earlier pass assumed. 25 477 messages
  received by the relay lifetime; only 35 forwarders used in the last 90 days, 194 silent
  for 3+ years. Two aliases are 39% of all traffic: `kickstarter` and `allegro`.
- A leaked alias looks like this: `kickstarter` took 5 339 messages from **134 distinct
  sender domains**, of which real `kickstarter.com` is a twelfth. Block the resale ring
  domain by domain; never `Block All` an alias that also carries orders or shipping.
- Blocking a domain whose bulc **member rating is 100%** holds it for every Bulc Club
  member, not just Greg. At 50% it only holds for him until the rating climbs.
- Never block `shared.klaviyomail.com` (rating 91) or any other shared ESP relay —
  legitimate senders ride the same infrastructure. Block the address, not the domain.
- AliExpress splits cleanly: promo on `selections.` / `mail.` / `newarrival.aliexpress.com`
  plus `promotion@aliexpress.com`; orders and parcels on `transaction@notice.aliexpress.com`.
- Mail sent to `*@mrglaszki.com` is Greg's own Cloudflare Email Routing setup — he manages
  those aliases himself at `mail.mrglaszki.com`. Report them, do not touch them.
