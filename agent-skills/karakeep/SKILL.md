---
name: karakeep
description: Manage Greg's Karakeep bookmarks from the terminal via its REST API — search, add, edit (title/url/note/archive/favourite), delete, and tag/list membership. Use whenever Greg wants to touch his bookmarks: "dodaj do karakeep", "zapisz zakładkę", "znajdź zakładkę", "zaktualizuj link w karakeep", "otaguj", "wrzuć na listę", "usuń zakładkę", "add a bookmark", "update the link in karakeep", "tag this", "which bookmarks point to X". Karakeep is his self-hosted bookmark manager on the lab (formerly Hoarder). NOT for saving agent facts (→ memory/Hindsight) and NOT for personal notes he reads himself (→ obsidian-notes).
---

# karakeep

Greg's Karakeep instance: **`https://karakeep.mrglaszki.com`**, REST API under
`/api/v1`. Everything here is plain `curl` + a bearer token — there is no CLI to
install.

Auth is already in the shell env as **`$KARAKEEP_API_KEY`** (a `ak2_…` token). Use
it verbatim; never print it back to Greg or paste it into a URL. Every call:

```bash
B="https://karakeep.mrglaszki.com/api/v1"; H="Authorization: Bearer $KARAKEEP_API_KEY"
```

## The core flow: search → resolve id → mutate

The API keys everything off opaque bookmark ids (`fyhm3k7l89l4fnd1vx4dj5ls`), which
Greg never has. So almost every task is two steps: **find the id, then act on it.**
Don't ask him for an id — search for the thing he described.

```bash
# 1. find it (full-text over title + url + content)
curl -sS -G "$B/bookmarks/search" --data-urlencode "q=announce report" -H "$H" \
  | python3 -c "import sys,json;[print(b['id'],b['content'].get('url','')) for b in json.load(sys.stdin)['bookmarks']]"

# 2. act on the id you found
curl -sS -X DELETE "$B/bookmarks/<id>" -H "$H" -w "\nHTTP %{http_code}\n"
```

`204` = success on delete. `200` with a JSON body = success on create/patch.

**Confirm before deleting or repointing.** Bookmarks are Greg's own curated data
and there's no undo. If a match is ambiguous (several hits) or you're about to
overwrite a URL, show him what you found and let him pick — same as you did the
first time. Adding a bookmark is safe to just do.

## Reading

```bash
# search — the workhorse. Supports qualifiers: is:archived is:fav is:tagged #tagname
curl -sS -G "$B/bookmarks/search" --data-urlencode "q=grafana billing" --data "limit=20" -H "$H"

# list everything, paginated (cursor-based; follow nextCursor until null)
curl -sS "$B/bookmarks?limit=50" -H "$H"          # → { bookmarks:[...], nextCursor:"..." }
curl -sS "$B/bookmarks?limit=50&cursor=<nextCursor>" -H "$H"

# one bookmark, full shape (tags, content.url, note, archived, favourited)
curl -sS "$B/bookmarks/<id>" -H "$H"
```

A link bookmark carries its URL at **`content.url`** (not top-level). `content.type`
is `link`, `text`, or `asset`.

## Adding

`type` is required and decides the shape. A link gets crawled + auto-tagged
asynchronously (`taggingStatus` goes `pending` → `success`), so the response comes
back before the title/preview exist — that's normal, not a failure.

```bash
# a link
curl -sS -X POST "$B/bookmarks" -H "$H" -H "Content-Type: application/json" \
  -d '{"type":"link","url":"https://example.com/thing"}'

# a text note
curl -sS -X POST "$B/bookmarks" -H "$H" -H "Content-Type: application/json" \
  -d '{"type":"text","text":"remember this"}'
```

Optional on create: `title`, `note`, `archived`, `favourited`. Tags and list
membership are attached in a **separate call** (below) — you can't inline them.

## Editing

`PATCH` only the fields that change. This is what "zaktualizuj link" means — repoint
`content.url`, keep the id, keep the tags.

```bash
curl -sS -X PATCH "$B/bookmarks/<id>" -H "$H" -H "Content-Type: application/json" \
  -d '{"url":"https://announce.mrglaszki.com/review"}'   # repoint a dead link
```

Patchable: `url` (links only), `title`, `note`, `summary`, `archived`,
`favourited`. Archiving (`{"archived":true}`) is the soft alternative to delete —
prefer it when Greg says "schowaj"/"z archiwum" rather than "usuń".

## Tags

Tags attach by name — Karakeep creates the tag if it's new, reuses it if it exists
(there are ~1000 already, so a plain word usually resolves to one he has).

```bash
# attach
curl -sS -X POST "$B/bookmarks/<id>/tags" -H "$H" -H "Content-Type: application/json" \
  -d '{"tags":[{"tagName":"homelab"},{"tagName":"announce"}]}'

# detach
curl -sS -X DELETE "$B/bookmarks/<id>/tags" -H "$H" -H "Content-Type: application/json" \
  -d '{"tags":[{"tagName":"announce"}]}'

curl -sS "$B/tags" -H "$H"     # all tags with ids + counts, to match an existing one
```

## Lists

Lists are Karakeep's folders (his are named `📁 <area> - …`). Membership is a
join, toggled per bookmark:

```bash
curl -sS "$B/lists" -H "$H"                                   # id + name of every list
curl -sS -X PUT    "$B/lists/<listId>/bookmarks/<bookmarkId>" -H "$H"   # add
curl -sS -X DELETE "$B/lists/<listId>/bookmarks/<bookmarkId>" -H "$H"   # remove
```

## Where it lives

- Service: `home-lab/services/karakeep/compose.yaml` — `karakeep` + `meilisearch`
  (search) + `chrome` (link crawling), on `lab_network`, routed by traefik.
- URL: `https://karakeep.mrglaszki.com` (web UI is the same host, no `/api`).
- Token: `$KARAKEEP_API_KEY` in the shell env; also `$env.l` in nushell
  `private.nu`. It's a user API key minted in Karakeep settings, not a server
  secret — rotating it in the UI means updating both places.
- Upstream API docs: https://docs.karakeep.app/API/ — check there before assuming
  an endpoint that isn't listed above (the instance exposes no OpenAPI at runtime).
