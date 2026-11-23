---
name: memory
description: Shared cross-machine fact memory (Hindsight on the lab, bank `greg`) used by Claude Code, n8n, Python agents and Raycast. Trigger on "remember", "recall", "save this", "zapisz to do pamięci", "co wiem o X", "co pamiętasz o X", "sprawdź pamięć", "what do I know about", "do you remember", "save to memory", any persistent cross-session knowledge; also manual HTTP/curl calls, Hindsight container troubleshooting, the model-slot collision with announce-agent.
---

# Memory — Hindsight

What goes where (facts here, documents to bazgroly, session history to MemPalace), the
`retain` / `recall` / `reflect` calls and the `metadata.project` hook: rule
`memory-location.md`. Guard denies `recall` without `max_tokens` (start at 512; `budget` is
no lever). This skill adds the stack.

**Engine:** [vectorize-io/hindsight](https://github.com/vectorize-io/hindsight) on the lab
(`192.168.50.10`), one container with embedded Postgres + pgvector + KG + reranker, no auth
(LAN boundary; Traefik basic-auth if ever needed). Bank `greg` for every client.

## Endpoints

| Use | URL |
|---|---|
| MCP, Claude Code (wired in `agent-mcp/mcp-servers.json.tmpl`) | `http://192.168.50.10:8888/mcp/greg/` |
| MCP, Raycast (needs HTTPS; HTTP/SSE, auth None, LE cert) | `https://mcp.mrglaszki.com/hindsight/mcp/greg/` |
| REST / Swagger | `http://192.168.50.10:8888`, `/docs` |
| Web UI | `http://192.168.50.10:9999/` |
| lab containers (n8n) | `http://hindsight:8888` |

## MCP notes

- `retain` is async (`{"status":"accepted"}`), ~10–20 s on Bielik CPU; one retain often becomes 2–5 facts. Atomic content; optional `metadata.source` / `metadata.type` (`user-pref`, `project-fact`, `decision`).
- `recall` runs semantic (BAAI/bge-small-en-v1.5) + BM25 + graph + temporal, then a cross-encoder rerank. The ~15 KB `entities` block can't be dropped via MCP; REST takes `"include":{"entities":null}` (82 KB → 7.5 KB).
- `reflect` = narrative answer instead of raw records.
- Also: `list_memories`, `get_memory`, `delete_document` (`bank_id="greg"`).

## REST (MCP down / n8n / debug)

Prefix is always `/v1/default/banks/greg/`, and retain takes an `items` array (`POST /memories` or `{"content":…}` → 404/empty):

```bash
H=http://192.168.50.10:8888/v1/default/banks/greg
curl -X POST $H/memories -H 'Content-Type: application/json' \
  --data-binary '{"items":[{"content":"…","context":"…","metadata":{"source":"manual","type":"user-pref"}}]}'
curl -X POST $H/memories/recall -H 'Content-Type: application/json' --data-binary '{"query":"…","max_tokens":512}'
curl -X POST $H/reflect -H 'Content-Type: application/json' --data-binary '{"query":"…"}'
curl $H/memories/list;  curl $H/memories/<uuid>;  curl $H/memories/<uuid>/history
```

n8n: HTTP Request node, POST `http://hindsight:8888/v1/default/banks/greg/memories` (body `{"items":[{"content":"$json.fact"}]}`) or `.../memories/recall`, no auth. Python: `pip install hindsight-client`, `Hindsight(base_url=…)`, `.retain/.recall/.reflect(bank_id="greg", …)`.

## Stack operations (lab)

```bash
C=/opt/homelab/services/hindsight/compose.yaml
ssh mrglaszki "docker compose -f $C restart hindsight"
ssh mrglaszki "sudo tar czf /opt/homelab/data/hindsight-snapshot-$(date +%F).tar.gz -C /opt/homelab/data hindsight"
```

- **Switch LLM:** `docker exec ollama ollama pull <model>`, set `HINDSIGHT_LLM_MODEL` in `services/hindsight/.env`, restart. Embeddings are fixed in-process, no re-index.
- **Backup:** backrest covers `/opt/homelab/data/hindsight/`. **Restore:** stop, `rm -rf` the data dir, untar the backup into `/opt/homelab/data/`, `chown -R 1000:1000`, `up -d`. **Full reset** = same without the untar (`up -d --force-recreate`); loses every memory, only when you must.

## Troubleshooting

- `Permission denied (os error 13)` on start → `sudo chown -R 1000:1000 /opt/homelab/data/hindsight` (container UID 1000; Docker creates bind dirs as root).
- LLM verification `HTTP 404` → `HINDSIGHT_API_LLM_BASE_URL=http://ollama:11434/v1` (needs `/v1`).
- Retain >30 s: cold Bielik-7b; timeouts >120 s → `docker logs ollama` for OOM.
- **Model-slot collision:** Ollama keeps one model warm (`OLLAMA_KEEP_ALIVE=-1`); Hindsight and announce-agent share `bielik-7b:latest`. A different model for either means reload ping-pong (30–60 s). Stay on bielik until more RAM or a second Ollama.
- First start downloads the reranker + embedder (~200 MB, 1–2 min), cached afterwards.

## Pointers

Stack source `~/Code/home-lab/services/hindsight/` (README runbook, `scripts/migrate-local-memory.py`); spec/plan in `~/Code/personal/bazgroly/home-lab/{specs,plans}/2026-06-03-hindsight-shared-memory*`; docs https://hindsight.vectorize.io. Lessons: check a public docker image exists before picking an engine (mem0 had none, ~2 h lost); one bank + `metadata.source` is enough for many agents.
