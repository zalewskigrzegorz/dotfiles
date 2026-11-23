---
name: growthbook-flags
description: Create, inspect, tag and target GrowthBook feature flags on the work stage and prod instances through the REST API, no browser. Use for any feature flag in the work monorepo — "załóż flagę", "dodaj feature flag", "zrób flagę na stage/prodzie", "włącz flagę dla orgi", "sprawdź czy flaga istnieje", "otarguj to po organizationId", "growthbook", "GrowthBook API" — and when apps/api adds a key to the FeatureFlagKey union (a key without a GrowthBook flag silently returns its default forever). Use before the web UI: the API is faster and avoids the wrong-host and dropped-tags traps.
---

# GrowthBook flags at work

Two self-hosted instances (stage, prod), driven from the terminal.

## The two silent traps (200 OK, nothing done)

1. **The web UI host is not the API host.** The UI host serves only Next.js
   and 404s `/api/v1/...` with HTML. The API hosts are in env (below); for a
   new instance or unexplained 404s ask it: `curl -s
   "https://<web-ui-host>/api/init" | jq .apiHost`.
2. **`POST /api/v1/features` drops `tags`** (description persists). Create is
   always create → set tags → read back. No read-back = reporting tags that
   aren't there.

## Credentials

1Password (vault `Dotfiles`, `GROWTHBOOK_API_KEY_STAGE` / `_PROD`), rendered
once at apply into `~/.config/nushell/autoload/private.nu`: `$env.GROWTHBOOK_API_KEY_STAGE`
/ `_PROD` (password field), `$env.GROWTHBOOK_API_HOST_STAGE` / `_PROD` (url
field). No `op read` per call. `nu -c` doesn't autoload it, so source it:

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_STAGE)"] $"($env.GROWTHBOOK_API_HOST_STAGE)/api/v1/features?limit=100"
'
```

Never paste or print a key. `{"message":"Invalid API key"}` = rotated: ask,
don't hunt. A `"` inside `$"..."` breaks nushell interpolation; build output
with `["label:"] | append $list | str join " "`.

## Tags and description are mandatory

A flag without both is unfinished (they're how 120 flags get found and
audited).

- **Description**: what turning it on does, the off path, how it's targeted,
  what to check before enabling, any danger. The off-path sentence is
  confirmed with one `rg` on the gate in the code, or not written.
- **Tags from the existing vocabulary.** Read them first; a page caps at 100
  and stage holds ~120, so page with `offset=100`:
  ```nushell
  nu -c '
  source ~/.config/nushell/autoload/private.nu
  let r = (http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_STAGE)"] $"($env.GROWTHBOOK_API_HOST_STAGE)/api/v1/features?limit=100")
  $r.features | get tags | flatten | uniq -c | sort-by count --reverse
  '
  ```
  Aug 2026 stage: `AI-Review` 12, `AI` 10, `mcp` 5, `billing` 3, `Replay` 2,
  `auth` 2, `Autonomous Agent` 1, `sso` 1, `login` 1 (`Autonomous Agent` and
  `Replay` as a second tag next to `AI`). Run the query, don't trust the list.
  Case splits tags (`Replay` ≠ `replay`). Take what siblings carry (every
  `ai-search-*` has `AI`); nothing fits → propose a new tag to the user, in
  the existing casing.

## Creating a flag

Environments differ per instance (stage 13: `local-dev`, `stage`, `dev`,
`lab0`–`lab7`, `e2e`, `replay-dev`; prod 3: `prod`, `prod-eu`, `replay`). Copy
the `enabled` map from the closest sibling (e.g. `ai-search-model` on prod:
`prod`, `prod-eu` on, `replay` off):

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
let f = (http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/ai-search-model").feature
print ($f.environments | items {|k v| $"($k)=($v.enabled)" })
'
```

`enabled` = served (targetable) in that environment, not "on";
`defaultValue: "false"` keeps it off. An environment left out of the POST is
disabled and drops out of that SDK payload. `defaultValue` is a **string**
even for booleans (a JSON boolean is rejected).

```json
{ "id": "my-flag", "valueType": "boolean", "defaultValue": "false", "owner": "Grzegorz Zalewski",
  "description": "What turning this on does. What the off path is. What to check before enabling.",
  "project": "", "archived": false, "environments": { "prod": { "enabled": true, "rules": [] } } }
```

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
let body = (open /tmp/flag.json)
http post --content-type application/json --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features" $body | ignore
http post --content-type application/json --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/my-flag" {tags: ["AI"]} | ignore
let g = (http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/my-flag").feature
print ($g | select id tags defaultValue)
'
```

Updating = the same `POST /features/{id}` with only the changed fields.

## The TypeScript side

In `apps/api/src/modules/common/feature-flags/`:

- `types.ts`: the key in the `FeatureFlagKey` union (else no type-check).
- `feature-flags.service.ts`: `validateFeatureFlag` runs zod only for JSON
  flags (a schema under `dto/` and a `case`); boolean/string/number fall
  through `default: return value`.
- `getFeatureValue(key, default, { organizationId })` returns `default` when
  the flag is missing, the org isn't targeted, or the call times out (5 s), so
  the default must be the safe/old behaviour. Each call builds a fresh client
  over the network: several lookups in one path go in one `Promise.all`.

## Targeting: a flag with no rules is dead

A new flag has `rules: []` everywhere, so everyone gets `defaultValue`, no
warning. Rollout per org = a `force` rule with `condition:
{"organizationId": "org_..."}`; copy the shape from `ai-search-tracing` or
`ai-search-model` on prod:

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
(http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/ai-search-tracing").feature.environments.prod.rules
'
```

A rule that exists still does nothing when: it sits in the wrong environment
(each has its own SDK key; a `stage` rule does nothing for a `lab3` or
`local-dev` service), it is `enabled: false` (dropped from the payload), or
the condition isn't literally `organizationId` with the `org_...` ULID (not
the slug). The call site must pass `{ organizationId: orgId }`; a lookup
without attributes never matches. To confirm, fetch the served payload for
that environment's client key, not the admin `rules`.

**Local UI**: a rule on `local-dev` in stage. It shows for everyone running a
local stack, so remove it only after Greg's test. After a change wait ~60 s
for the SDK cache and hard-refresh; no stack restart.

## Done means

- [ ] description explains the danger of switching on, off-path checked in code
- [ ] tags non-empty, from the existing vocabulary, read back from the API
- [ ] environments copied from a sibling, `defaultValue` safe and a string
- [ ] key in the `FeatureFlagKey` union
- [ ] both instances when it ships to prod
- [ ] a targeting rule in the environment the users' service runs in, if
      anyone should get the behaviour
- [ ] report: UI link, flag description, rule description as separate lines
