---
name: firefly
description: Greg's Firefly III (self-hosted finance ledger on the lab): look up a transaction by id or title, check categories and budgets, import a Moje ING export, read importer logs. Use on "co to za transakcja #4988", "znajdź płatność za …", budgets, categories, "wrzuć eksport z ING do firefly", "firefly import", or an import that "nie widzi końca" / shows errors.
---

# firefly

Firefly III on the lab (`services/firefly`, importer `services/firefly-importer` in `~/Code/home-lab`). The Mac has no API access: queries go through `ssh mrglaszki`.

## Import a Moje ING export (Mac)

```bash
nu -c 'source ~/.config/nushell/autoload/firefly.nu; firefly'        # newest ~/Downloads/Lista_transakcji_nr_*.csv
#   … firefly --dry   (convert + preview, nothing sent)   … firefly --all   (every account, no picker)
```

It straightens the CSV (`ing-csv.py`), splits per account, `scp`s and runs `php artisan importer:import` per file. Overlapping exports are safe (`tx_id` → external-id, `duplicate_detection_method=cell`). `home-lab/data/firefly-importer/import/ing-pl.json` is the source of truth and overwrites the lab copy each run.

## API (lab)

Token: `FIREFLY_III_ACCESS_TOKEN` in `/opt/homelab/services/firefly-importer/.env`; line 7 breaks `source`, so `grep` it. Never print it or copy it to the Mac.

```bash
ssh mrglaszki 'cd /opt/homelab/services/firefly-importer && T=$(grep "^FIREFLY_III_ACCESS_TOKEN=" .env | cut -d= -f2-) && curl -s -H "Authorization: Bearer $T" -H "Accept: application/vnd.api+json" "http://firefly:8080/api/v1/transactions/4988" | python3 -m json.tool | head -80'
```

- Host = the container name in `services/firefly/compose.yaml`.
- **Search is broken** (0 hits for known payees): page `/api/v1/transactions?limit=500&page=N` and filter `description`/`amount`/`date` in Python.
- One transaction: `attributes.transactions[0]` has `description`, `amount`, `category_name`, `budget_name`, `external_id`.
- Categories/budgets come from `ing-classify.py`; electricity and gas arrive via the payment gateway, so `recheck` matches them by title. Budget rules recomputed from 2026-09-01 only.
- MariaDB: `docker exec -e MYSQL_PWD="$(grep '^DB_PASSWORD=' .env | cut -d= -f2-)" <mariadb> mariadb -u firefly firefly -e '…'`; the password never reaches output or a file.
- Firefly 6.6.6 has no sharing (an invited user sees an empty ledger); shared views go through `deck push` pages.

## Importer logs

- Log is inside the importer container: `/var/www/html/storage/logs/data-import-<YYYY-MM-DD>.log` (`docker logs` is useless). Read it rather than `tuios-peek` (a DEBUG import floods the scrollback).
- `Add error on index … [a115]` = duplicate, not a failure; `importer:import` exits 1 on duplicates, which the `firefly` loop tolerates.
- Waiting on an import: poll the log or `pgrep -x` inside the container (guard denies a bare `pgrep -f` loop).
