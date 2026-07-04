---
name: memory
description: Shared cross-machine memory layer for retaining and recalling atomic facts about Greg, his projects, preferences, and decisions. Backed by Hindsight on home-lab, single bank `greg`, shared between Claude Code (Mac+lab), n8n workflows, custom Python agents, and Raycast. Trigger on memory phrases — "remember", "recall", "save this", "zapisz to do pamięci", "co wiem o X", "co pamiętasz o X", "sprawdź pamięć", "what do I know about", "do you remember", "save to memory", or any phrase about persistent cross-session knowledge. Also covers manual HTTP/curl operations, troubleshooting the Hindsight container backend, and the model-slot collision with announce-agent.
---

# Memory — Shared Cross-Machine Memory Layer

Greg's centralized agent memory. **Engine:** Hindsight on home-lab (`minis`,
Debian, `192.168.50.10`). Single container z embedded Postgres+pgvector+KG+
reranker. Zero auth (LAN to "hasło"). Wszystkie agenty (Claude Code Mac+lab,
n8n, Raycast, Python) gadają do tego samego "brain" — namespace
**bank_id=`greg`**.

**Engine:** [vectorize-io/hindsight](https://github.com/vectorize-io/hindsight) (MIT, SOTA na LongMemEval).

## Memory model (read first)

This is the **fact layer**. Long-form work products (plans, specs,
brainstorms, analyses) go to **bazgroly**, not here. See
`agent-rules/superpowers-artifact-location.md` for the bazgroly routing.

| Goes here (Hindsight) | Goes to bazgroly |
|---|---|
| Atomic facts (single claim, 1-2 sentences) | Long-form docs (>500 chars, headers, multi-paragraph) |
| User preferences, decisions, current state | Past-tense work products (specs, audits, plans) |
| Cross-session knowledge | Per-project markdown |
| Semantic + KG queryable | File-system browsable, git-versioned |

If unsure: would this be a sentence or a document? Sentence → here. Document
→ bazgroly file.

The PreToolUse hook `~/.claude/hooks/hindsight-tag.sh` auto-injects
`metadata.project` based on git repo root / PWD basename — you don't need to
set it explicitly.

## When to use this skill

- "Zapisz to do pamięci / save this to memory"
- "Co wiem o X / what do I know about X / recall"
- "Sprawdź czy gdzieś pamiętamy że..."
- Cokolwiek związanego z long-term memory cross-machine
- Setup / connect Hindsight z nowego klienta
- Debug Hindsighta jeśli nie działa

**Nie używaj** dla:
- Krótkoterminowych session notes (TodoWrite lub task plan)
- Markdown long-form notes / plans / specs (te idą do bazgroly — patrz `superpowers-artifact-location` rule)
- Stary local auto-memory `~/.claude/projects/.../memory/` (deprecated, archived do `.legacy-*`)

## Connection details

| Use case | URL |
|---|---|
| MCP from Claude Code (Mac, lab) — auto-wired w dotfiles | `http://192.168.50.10:8888/mcp/greg/` |
| MCP from Raycast (wymaga HTTPS) | `https://mcp.lab/hindsight/mcp/greg/` |
| REST API base | `http://192.168.50.10:8888` |
| Web UI | `http://192.168.50.10:9999/` |
| OpenAPI Swagger | `http://192.168.50.10:8888/docs` |
| Internal Docker network (n8n, other lab containers) | `http://hindsight:8888` |

**Brak auth.** Network boundary = WiFi/cable. Jeśli kiedyś trzeba — Traefik basic-auth middleware (~5 min setup).

## Core operations — MCP tools (preferowane)

Wewnątrz Claude Code masz natywne MCP tools — używaj ich zamiast curl'a.
`metadata.project` auto-injectuje hook `hindsight-tag.sh`, nie musisz podawać.

### Retain — save a fact

```
mcp__hindsight__retain(
  content="Greg pivoted memory layer from mem0 to Hindsight on 2026-06-03 because mem0 had no public docker image",
  context="hindsight-rollout-decision"
)
```

Response: `{"status":"accepted","operation_id":"<uuid>"}`. Async — Hindsight
ekstraktuje atomic facts + entities w tle (~10-20s on Bielik CPU). 1 retain
często staje się 2-5 world-facts.

### Recall — semantic search

```
mcp__hindsight__recall(query="memory layer pivot history")
```

Response: `{results: [{id, text, fact_type, entities, context, mentioned_at, ...}]}`.

Recall robi 4 strategies w parallel: semantic vectors (BAAI/bge-small-en-v1.5),
keyword BM25, graph traversal (entity links), temporal filtering. Plus
cross-encoder reranker na top.

### Reflect — narrative answer

```
mcp__hindsight__reflect(query="what do I know about Greg's deploy flow")
```

Zwraca narracyjną odpowiedź zamiast surowych rekordów — używaj kiedy chcesz
"opowiedz mi" zamiast "daj raw".

### List / get / delete

```
mcp__hindsight__list_memories(bank_id="greg")
mcp__hindsight__get_memory(bank_id="greg", memory_id="<uuid>")
mcp__hindsight__delete_document(...)
```

## Raw HTTP (fallback / debug)

Jeśli MCP nie działa, możesz uderzyć REST bezpośrednio:

### Retain — save fact(s)

```bash
curl -X POST http://192.168.50.10:8888/v1/default/banks/greg/memories \
  -H 'Content-Type: application/json' \
  --data-binary '{
    "items": [
      {
        "content": "Greg używa nushell jako głównej powłoki. Ctrl+R to fzf-history, Alt+T to Television.",
        "context": "shell setup",
        "metadata": {"source": "manual", "type": "user-pref"}
      }
    ]
  }'
```

Response:
```json
{"success": true, "items_count": 1, "usage": {"total_tokens": 5000}}
```

**Uwaga:** retain wewnętrznie wywołuje Ollama (Bielik-7b on CPU) żeby wyciągnąć
facts + entities + relacje. Per call: ~10-20s. Hindsight **rozkłada** jeden
content na wiele world-facts. Czyli `items_count: 1` w response = 1 input,
ale w Hindsight powstanie często 2-5 atomic facts.

### Recall — semantic search

```bash
curl -X POST http://192.168.50.10:8888/v1/default/banks/greg/memories/recall \
  -H 'Content-Type: application/json' \
  --data-binary '{"query": "jak Greg używa terminala"}'
```

Response:
```json
{
  "results": [
    {
      "id": "uuid",
      "text": "Greg używa nushell jako głównej powłoki",
      "type": "world",
      "entities": ["Greg", "nushell"],
      "context": "shell setup",
      ...
    }
  ]
}
```

Recall robi 4 retrieval strategies w parallel: semantic vectors (BAAI/bge-small-en-v1.5),
keyword BM25, graph traversal (entity links), temporal filtering. Plus cross-encoder
reranker (ms-marco-MiniLM-L-6-v2) na top.

### Reflect — disposition-aware response

```bash
curl -X POST http://192.168.50.10:8888/v1/default/banks/greg/reflect \
  -H 'Content-Type: application/json' \
  --data-binary '{"query": "tell me about Greg shell setup"}'
```

Reflect generuje narracyjną odpowiedź na bazie retained memories — używaj kiedy
chcesz "co wiesz, opisz" zamiast surowych rekordów.

### List all / get one

```bash
# all in bank
curl http://192.168.50.10:8888/v1/default/banks/greg/memories/list

# specific memory by id
curl http://192.168.50.10:8888/v1/default/banks/greg/memories/<uuid>

# memory history (changes over time)
curl http://192.168.50.10:8888/v1/default/banks/greg/memories/<uuid>/history
```

## From Claude Code (MCP)

Jeśli skill jest aktywny i MCP wpięty (przez `agent-mcp/mcp-servers.json.tmpl` w
dotfiles z entry `hindsight`) — Claude Code dostaje natywne tools `mcp__hindsight__*`.

**Typowy flow:**
1. User pyta "co wiesz o X"
2. Claude woła `mcp__hindsight__recall` z query
3. Wyniki wracają jako structured JSON
4. Claude formatuje dla usera

**Save flow:**
1. Coś warto zapamiętać (decyzja, fakt, pref)
2. Claude woła `hindsight_retain` z `content`, opcjonalnie `context` + `metadata`
3. Response z usage tokens

**Best practice w prompt'cie:**
- Dodaj `metadata.source` (np. `"claude-code-session-X"`, `"manual"`, `"migrated-local"`)
- Dodaj `metadata.type` (np. `"user-pref"`, `"project-fact"`, `"decision"`)
- Krótkie atomic content zamiast długiego paragraph — Hindsight i tak rozłoży

## From Python (hindsight-client)

```bash
pip install hindsight-client
```

```python
from hindsight_client import Hindsight

client = Hindsight(base_url="http://192.168.50.10:8888")

# retain
client.retain(
    bank_id="greg",
    content="Project Acme oklepuje certyfikaty w marcu — termin oddania DR jest 2026-03-15",
    context="acme-deadline",
    metadata={"source": "claude-code", "type": "deadline"}
)

# recall
results = client.recall(bank_id="greg", query="kiedy są deadliny w Acme")

# reflect
narrative = client.reflect(bank_id="greg", query="co wiesz o Acme")
```

## From n8n

W workflow:
1. HTTP Request node
2. Method: POST
3. URL: `http://hindsight:8888/v1/default/banks/greg/memories` (internal `lab_network`)
4. Body: `{"items":[{"content":"$json.fact"}]}`
5. Brak auth headers

Albo dla recall: ten sam pattern, URL `.../memories/recall`, body `{"query":"$json.q"}`.

## From Raycast (HTTPS wymagane)

Pre-req: Traefik route na `mcp.lab` gateway + cert install (per `mcp.lab`
flow w home-lab README). **Nie używamy** `mem.lab` jako osobnego hostu —
cert `*.lab` nie matchuje single-label wildcard (RFC 6125), więc wpinamy
się pod istniejący gateway `mcp.lab/hindsight/...` razem z Homey/Excalidraw.

Raycast Settings → MCP Servers → Add:
- URL: `https://mcp.lab/hindsight/mcp/greg/`
- Type: HTTP/SSE
- Auth: None

Raycast cert install: Safari → `https://mcp.lab/cert/cert.pem` → import do Keychain System → "Always Trust" → restart Raycast.

## Operations on the stack

### Restart Hindsight

```bash
ssh lab "docker compose -f /opt/homelab/services/hindsight/compose.yaml restart hindsight"
```

### Switch Ollama model

1. Pull: `ssh lab "docker exec ollama ollama pull <model>"`
2. Edit `/opt/homelab/services/hindsight/.env` na labie: zmień `HINDSIGHT_LLM_MODEL`
3. Restart Hindsight (wyżej)

**Uwaga:** Embeddings ma własny model (`BAAI/bge-small-en-v1.5`, fixed in-process).
Zmiana LLM model NIE wymaga re-indeksacji — tylko fact extraction się zmienia.

### Backup

`backrest` automatycznie łapie `/opt/homelab/data/hindsight/`. Brak osobnego
cron-scriptu — embedded Postgres robi WAL flush, KG indeksy też na dysku.

Manual snapshot:
```bash
ssh lab "sudo tar czf /opt/homelab/data/hindsight-snapshot-$(date +%F).tar.gz -C /opt/homelab/data hindsight"
```

### Restore

```bash
ssh lab "docker compose -f /opt/homelab/services/hindsight/compose.yaml stop hindsight && \
  sudo rm -rf /opt/homelab/data/hindsight && \
  sudo tar xzf /path/to/backup.tar.gz -C /opt/homelab/data/ && \
  sudo chown -R 1000:1000 /opt/homelab/data/hindsight && \
  docker compose -f /opt/homelab/services/hindsight/compose.yaml up -d hindsight"
```

## Troubleshooting

### Recall zwraca pustkę albo `404` na retain

Sprawdź MCP/REST endpoint format — schema URL ma **prefix `/v1/default/banks/<bank>/`**, nie samo `/memories`:
- ✅ `POST /v1/default/banks/greg/memories`
- ❌ `POST /memories`

Body MUSI mieć `items` array, nie samo `content`:
- ✅ `{"items":[{"content":"..."}]}`
- ❌ `{"content":"..."}`

### Hindsight container nie startuje — `Permission denied (os error 13)`

Bind mount `/opt/homelab/data/hindsight` musi być owned by UID 1000 (container's
`hindsight` user). Fix:
```bash
ssh lab "sudo chown -R 1000:1000 /opt/homelab/data/hindsight"
```
Restart Hindsight.

### LLM verification `HTTP 404` w logach

`HINDSIGHT_API_LLM_BASE_URL` musi mieć `/v1` na końcu (Ollama OAI-compat endpoint):
```env
HINDSIGHT_API_LLM_BASE_URL=http://ollama:11434/v1
```
NIE `http://ollama:11434` (bez /v1 = 404 na `/chat/completions`).

### Retain wisi długo (>30s)

Bielik-7b on CPU. Pierwsze retain w sesji może być wolne (cold start), kolejne
szybsze (model warm). Jeśli pojawiają się timeouts po >120s — sprawdź
`docker logs ollama` czy nie OOM.

### Model-slot collision z announce-agent

Ollama trzyma JEDEN model warm (`OLLAMA_KEEP_ALIVE=-1`). Hindsight + announce-agent
oba używają `bielik-7b:latest` — dzielą warm slot, brak ping-pongu. Jeśli kiedyś
zmienisz Hindsight na inny model (np. llama3.1), wpadniesz w ping-pong — model
będzie się przeładowywał między requestami z 30-60s latency. Trzymaj się
bielik-7b dopóki nie dorzucisz RAM / drugiego Ollama containera.

### `docker logs hindsight` pokazuje cross-encoder/embedding download

First start ściąga `cross-encoder/ms-marco-MiniLM-L-6-v2` + `BAAI/bge-small-en-v1.5`
(~200MB total). Cache w volume — kolejne starty NIE pobierają. Pierwszy start ~1-2 min.

### Coś się rozjechało — full reset (DESTRUCTIVE)

```bash
ssh lab "docker compose -f /opt/homelab/services/hindsight/compose.yaml stop hindsight && \
  sudo rm -rf /opt/homelab/data/hindsight && \
  sudo mkdir -p /opt/homelab/data/hindsight && \
  sudo chown -R 1000:1000 /opt/homelab/data/hindsight && \
  docker compose -f /opt/homelab/services/hindsight/compose.yaml up -d --force-recreate hindsight"
```
**Tracimy wszystkie memories.** Tylko gdy naprawdę musisz.

## Architecture quick reference

```
[Mac]                                    [Lab — minis]
 │                                              │
 ├─ Claude Code MCP   ─┐                  hindsight (8888 + 9999)
 ├─ n8n               ─┼─→ http://192.168.50.10:8888 (LAN)
 ├─ Python            ─┘                        │
 ├─ Raycast           ───→ https://mcp.lab/hindsight/mcp/greg/  (Traefik gateway)
                                                │
                                          ollama:11434/v1  (bielik-7b)
                                                │
                                          /opt/homelab/data/hindsight  (PG + KG + caches)
```

## Pointers

- **Spec:** `~/Code/personal/bazgroly/home-lab/specs/2026-06-03-hindsight-shared-memory-design.md`
- **Plan:** `~/Code/personal/bazgroly/home-lab/plans/2026-06-03-hindsight-shared-memory.md`
- **Stack source:** `~/Code/home-lab/services/hindsight/` (compose, env, scripts, tests)
- **Runbook:** `services/hindsight/README.md` (operations cheatsheet)
- **Migration script:** `services/hindsight/scripts/migrate-local-memory.py`
- **Hindsight upstream docs:** https://hindsight.vectorize.io
- **Paper:** https://arxiv.org/abs/2512.12818

## Lessons learned (z deploymentu)

1. **Sprawdź public docker image PRZED commitowaniem na engine.** mem0 wybraliśmy w spec'u, potem okazało się że nie ma image'u → pivot do Hindsighta po 5 taskach pracy. Strata: ~2h.
2. **Embedded DB + bind mount = UID mismatch zawsze.** Container leci jako non-root (UID 1000 dla Hindsighta), host dir auto-created przez Docker jako root. Pre-chown lub named volume.
3. **OAI-compatible endpoints to nie zawsze base URL.** Ollama ma `/v1` prefix dla OpenAI-compat shim. Bez tego = 404 na `/chat/completions`.
4. **`format: json` na Bielik 7B działa zaskakująco dobrze** — w testach wyciąga entities + relations cleanly, normalizuje PL→EN automatycznie.
5. **Single bank "greg" + metadata.source filtering** to wystarcza dla wieloagentowego użycia. Per-agent namespacing byłoby premature optimization.
