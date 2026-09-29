---
name: firefly
description: Greg's Firefly III (self-hosted finance ledger on the lab) — look up a transaction by id or title, check categories and budgets, import a Moje ING export, read importer logs. Use when Greg asks about a transaction ("co to za transakcja #4988", "znajdź płatność za …"), budgets, categories, "wrzuć eksport z ING do firefly", "firefly import", or when an import "nie widzi końca" / shows errors. Firefly runs on the lab only; the Mac has the `firefly` nushell command for imports.
---

# firefly

Firefly III lives on the lab (`services/firefly`, importer in `services/firefly-importer`, both in `~/Code/home-lab`). The Mac has no API access; every query goes through `ssh lab`.

## Import a Moje ING export (Mac side)

`firefly` is a **nushell** def in `~/.config/nushell/autoload/firefly.nu`. From the Bash tool:

```bash
nu -c 'source ~/.config/nushell/autoload/firefly.nu; firefly'            # newest Lista_transakcji_nr_*.csv from ~/Downloads
nu -c 'source ~/.config/nushell/autoload/firefly.nu; firefly --dry'      # convert + preview, nothing goes to the lab
nu -c 'source ~/.config/nushell/autoload/firefly.nu; firefly --all'      # every account, no picker
```

It straightens the ING CSV (`ing-csv.py`), splits per account, `scp`s to the lab and runs `php artisan importer:import` per file. Duplicates are safe: `ing-pl.json` maps `tx_id` to external-id with `duplicate_detection_method=cell`, so overlapping exports are fine. The mapping config in `home-lab/data/firefly-importer/import/ing-pl.json` is the source of truth and overwrites the lab copy on every run.

## Query the API (lab side)

The token sits in `/opt/homelab/services/firefly-importer/.env` as `FIREFLY_III_ACCESS_TOKEN`. Line 7 of that file breaks `source`, so read keys with `grep`:

```bash
ssh lab 'cd /opt/homelab/services/firefly-importer && T=$(grep "^FIREFLY_III_ACCESS_TOKEN=" .env | cut -d= -f2-) && curl -s -H "Authorization: Bearer $T" -H "Accept: application/vnd.api+json" "http://firefly:8080/api/v1/transactions/4988" | python3 -m json.tool | head -80'
```

Adjust the host to whatever `services/firefly/compose.yaml` names the container. Never print the token, never copy it to the Mac.

- **Search is broken** (`/api/v1/search/transactions` returns 0 for known payees). List `/api/v1/transactions?limit=500&page=N` and filter by `description` / `amount` / `date` in Python instead.
- One transaction: `/api/v1/transactions/<id>` → `attributes.transactions[0]` holds `description`, `amount`, `category_name`, `budget_name`, `external_id`.
- Categories and budget rules are applied by `ing-classify.py` in `services/firefly-importer`; electricity and gas arrive through the internet-payment gateway, so `recheck` matches them by title, not payee. Budget rules were recomputed from 2026-09-01 onwards only.

## Importer logs and errors

- `docker logs` shows nothing useful. The log is inside the importer container: `/var/www/html/storage/logs/data-import-<YYYY-MM-DD>.log`.
- `Add error on index … [a115]` is a **duplicate**, not a failure. `importer:import` still exits 1 on duplicates, which is why the `firefly` loop tolerates that code.
- A wait loop on `pgrep -f "artisan importer:import"` through `ssh lab` matches its own shell and never ends — poll the log file or use `pgrep -x` inside the container (see `zsh-bash-tool` rule).
- `herdr-peek` keeps ~700–999 lines; a DEBUG import floods it. Read the log file.

## Facts that shape answers

- Firefly 6.6.6 has no sharing: an invited user (Estera) sees an empty ledger. Shared views go through `deck push` pages instead.
- MariaDB: `docker exec -e MYSQL_PWD="$(grep '^DB_PASSWORD=' .env | cut -d= -f2-)" <mariadb> mariadb -u firefly firefly -e '…'`. The password never appears in output or in a file.
