---
name: karakeep
description: Manage Greg's Karakeep bookmarks (self-hosted on the lab, formerly Hoarder) via its REST API — search, add, edit, delete, tags, lists. Use on "dodaj do karakeep", "zapisz zakładkę", "znajdź zakładkę", "zaktualizuj link w karakeep", "otaguj", "wrzuć na listę", "usuń zakładkę", "add a bookmark", "update the link in karakeep", "tag this", "which bookmarks point to X". Not for agent facts (memory) or notes he reads himself (obsidian-notes).
---

# karakeep

`https://karakeep.mrglaszki.com/api/v1`, plain `curl` + `$KARAKEEP_API_KEY` (`ak2_…`, also `$env.l` in nushell `private.nu`; rotating it in the UI means updating both). Never print it or put it in a URL.

```bash
B="https://karakeep.mrglaszki.com/api/v1"; H="Authorization: Bearer $KARAKEEP_API_KEY"
```

## Search → id → act

Greg never has ids: search for what he described, don't ask.

```bash
curl -sS -G "$B/bookmarks/search" --data-urlencode "q=announce report" --data "limit=20" -H "$H" \
  | python3 -c "import sys,json;[print(b['id'],b['content'].get('url','')) for b in json.load(sys.stdin)['bookmarks']]"
```

- Qualifiers: `is:archived is:fav is:tagged #tag`. List all: `GET /bookmarks?limit=50[&cursor=<nextCursor>]`. One: `GET /bookmarks/<id>`. URL lives at `content.url`; `content.type` is `link|text|asset`.
- **Confirm before deleting or repointing** (no undo): show ambiguous matches and let him pick. Adding is safe to just do.
- `DELETE /bookmarks/<id>` → 204. Create/patch → 200 + JSON.

## Write

```bash
curl -sS -X POST "$B/bookmarks" -H "$H" -H "Content-Type: application/json" -d '{"type":"link","url":"https://…"}'   # or {"type":"text","text":"…"}
curl -sS -X PATCH "$B/bookmarks/<id>" -H "$H" -H "Content-Type: application/json" -d '{"url":"https://…"}'
```

- Create takes optional `title`, `note`, `archived`, `favourited`; tags and lists need separate calls. Links are crawled and auto-tagged async (`taggingStatus` pending → success): an empty title right after create is normal.
- PATCH only what changes: `url` (links), `title`, `note`, `summary`, `archived`, `favourited`. "Zaktualizuj link" = repoint `url`, keep id and tags. "Schowaj" → `{"archived":true}`, not delete.

## Tags and lists

```bash
curl -sS -X POST   "$B/bookmarks/<id>/tags" -H "$H" -H "Content-Type: application/json" -d '{"tags":[{"tagName":"homelab"}]}'   # DELETE detaches
curl -sS "$B/tags" -H "$H"        # ~1000 existing tags; names are created or reused
curl -sS "$B/lists" -H "$H"       # folders named "📁 <area> - …"
curl -sS -X PUT "$B/lists/<listId>/bookmarks/<bookmarkId>" -H "$H"   # DELETE removes
```

## Where it lives

`home-lab/services/karakeep/compose.yaml` (karakeep + meilisearch + chrome crawler, traefik). Web UI on the same host. No OpenAPI at runtime: check https://docs.karakeep.app/API/ before assuming an unlisted endpoint.
