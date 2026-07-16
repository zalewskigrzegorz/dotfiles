---
name: read-the-damn-docs
description: >-
  Use when implementing, integrating, upgrading, debugging, or answering
  anything involving third-party APIs, libraries, frameworks, CLIs, cloud
  services, SDKs, fast-moving product behavior, requests for latest/current/
  official behavior, unfamiliar repo docs/specs, errors that may indicate API
  drift, or high-stakes auth, security, billing, data, migration, deployment,
  compliance, or privacy behavior. Forces a web-search for current official
  docs and reading primary docs before assuming from memory. Ported from
  BuilderIO/skills → skills/read-the-damn-docs (standalone rewrite).
---

# Read The Damn Docs

Don't guess when authoritative docs can answer the question. The usual right
move is: web-search the current official docs, open the relevant pages, read
them before coding. For APIs, versions, provider behavior, config, limits,
lifecycle hooks, or security-sensitive flows, ground the answer in what the
docs actually say.

> **Coordination:** for Claude / Anthropic / any LLM-provider work, the
> `claude-api` skill already owns the docs-first check — let it drive there.
> This skill covers everything else (every non-LLM third-party API, library,
> CLI, cloud service, framework).

## Docs-First Triggers

Read docs before proceeding when any of these hold:

- The user asks for "latest", "current", "official", "supported", "best
  practice", "recommended", "today", "now", or "look it up".
- The needed docs aren't already in the repo or supplied by the user. Search
  the web rather than hoping model memory is current.
- The task adds, upgrades, configures, or imports a package, SDK, framework,
  plugin, CLI, cloud resource, or provider integration.
- The API is fast-moving or version-sensitive: Next.js, React, Tailwind, Vite,
  Drizzle, Prisma, Stripe, GitHub, Slack, Notion, browser APIs, deployment
  platforms, auth libraries, and similar.
- The implementation depends on auth, OAuth scopes, permissions, secrets,
  webhooks, billing, payments, PII, encryption, data retention, migrations,
  retries, rate limits, quotas, caching, deploys, or compliance.
- An error mentions deprecation, unknown options, missing exports, invalid
  config, unsupported fields, changed defaults, or version mismatch.
- A repo has local docs, ADRs, generated schemas, OpenAPI specs, route/action
  registries, or package READMEs that could define the contract.
- The choice is expensive to reverse: public wire formats, DB schema, migration
  strategy, persistent IDs, event names, customer-visible behavior, external
  automation contracts.
- You catch yourself about to write "usually", "probably", "I think", "from
  memory", or copying code from memory for an external API.

## What Counts As Docs

Most authoritative source wins:

- Local repo docs, specs, ADRs, schemas, generated types, package READMEs, and
  tests for project-specific behavior.
- Official product docs, API references, migration guides, changelogs, release
  notes, and SDK source/types for third-party behavior. Find with web search
  when you don't have the exact URL.
- Registry metadata for versions. Before adding a dependency, run
  `npm view <pkg> version` / `pnpm view <pkg> version` (or the ecosystem
  equivalent), then read the docs for that major.
- Source code / type definitions when official docs are incomplete — treat as
  evidence, not folklore.

Avoid Stack Overflow, old blog posts, random snippets, and memory as the
primary source when official docs exist. Community sources only to debug
symptoms after the authoritative contract is known.

## Required Workflow

1. Identify the exact surface: package name, installed version, target version,
   provider endpoint, CLI command, config file, local helper, schema, or feature.
2. Web-search the current official docs unless they're already local or the user
   gave a URL. Targeted queries: `<product> <feature> official docs`,
   `<package> migration guide`, `<provider> API reference`.
3. Open and read the docs closest to that surface — local first for internal
   code, then official upstream. For new packages, verify the latest version
   before writing imports, config, or install commands.
4. Extract the few facts needed: option names, imports, lifecycle rules, default
   behavior, breaking changes, limits, permissions, current-major examples.
5. Implement using those facts. If docs conflict with existing code, inspect the
   local path and call out the discrepancy.
6. Verify with the smallest useful check: typecheck, tests, build, CLI dry run,
   schema validation, or a local repro.
7. In the final answer, name the docs / local files consulted when that evidence
   affected the recommendation or implementation.

## When A Quick Local Read Is Enough

Don't browse the web for every tiny edit. A local, brief pass is fine when the
answer's already in the repo: existing helper usage, nearby tests, typed
interfaces, generated clients, ADRs, package READMEs. But if the task depends on
an external tool, package, provider, or current product behavior, web search is
usually the right first step. For trivial syntax, typo fixes, formatting, or
self-contained code with no external contract — just proceed.

## If Docs Are Unavailable

If network/auth/missing files block reading the docs, say so plainly before
relying on memory. Narrow the uncertainty, inspect source or types if available,
and don't present the result as confirmed-current.
