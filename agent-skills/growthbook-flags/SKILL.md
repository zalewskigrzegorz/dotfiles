---
name: growthbook-flags
description: Create, inspect, tag and target GrowthBook feature flags on the work stage and prod instances through the REST API, without the browser. Use this whenever a task involves a feature flag in the work monorepo — "załóż flagę", "dodaj feature flag", "zrób flagę na stage/prodzie", "włącz flagę dla orgi", "sprawdź czy flaga istnieje", "otarguj to po organizationId", "growthbook", "GrowthBook API" — and also when work on apps/api adds a new key to the FeatureFlagKey union, because a key in TypeScript without a matching flag in GrowthBook silently returns its default forever. Reach for this before opening the GrowthBook web UI in a browser; the API path is faster and avoids the two traps below (wrong host, silently dropped tags).
---

# GrowthBook flags at work

Two self-hosted instances, both driven entirely from the terminal. The browser
is never needed and is the slower path.

## The two traps

These are why this skill exists. Both fail *silently* — you get a 200 back and
believe you're done.

**1. The web UI origin is not the API origin.** The web UI host (the one from
the browser) serves only the Next.js frontend and returns a 404 HTML page for `/api/v1/...`,
which looks like "endpoint doesn't exist" rather than "wrong host". The real API
lives somewhere else entirely. Don't hardcode or guess it — ask the instance:

```bash
curl -s "https://<web-ui-host>/api/init" | jq .apiHost
```

Both resolved API hosts (stage and prod) are already stored in env (below), so you rarely need this. Use it when a *new* instance shows up or
when calls 404 for no obvious reason.

**2. `POST /api/v1/features` accepts `tags` in the body and drops them.** It
returns 200 with the feature, `description` from the same body persists fine,
and `tags` comes back empty. Verified on both instances. So creating a flag is
always **two calls**: create, then update tags, then read back to confirm. If
you skip the read-back you will report success on a flag that has no tags.

## Credentials

Keys live in 1Password (vault `Dotfiles`, items `GROWTHBOOK_API_KEY_STAGE` /
`GROWTHBOOK_API_KEY_PROD`) and chezmoi renders them **once at apply time** into
`~/.config/nushell/autoload/private.nu`. Nothing calls `op read` per invocation
— same arrangement as `GRAFANA_SERVICE_ACCOUNT_TOKEN`.

| Variable | Holds |
|---|---|
| `$env.GROWTHBOOK_API_KEY_STAGE` / `_PROD` | the API key (1Password `password` field) |
| `$env.GROWTHBOOK_API_HOST_STAGE` / `_PROD` | the API origin (1Password `url` field) |

A non-interactive `nu -c` does **not** autoload `private.nu`, so these look
unset from a tool call. Source it explicitly:

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_STAGE)"] $"($env.GROWTHBOOK_API_HOST_STAGE)/api/v1/features?limit=100"
'
```

Never paste a key inline in a command and never print one. If a call returns
`{"message":"Invalid API key"}` the key was rotated — ask, don't hunt for it.

Nushell string interpolation chokes on a `"` inside `$"..."`. Building output
with `["label:"] | append $list | str join " "` avoids the quoting mess that
`str join ", "` inside an interpolation causes.

## Tags and description are mandatory

Both matter internally — they're how flags get found and audited later, and a
flag without them is noise in a list of 120. Treat a flag as unfinished until
both are set.

**Description** should answer what flipping it on actually does, plus anything
dangerous about enabling it. Good shape: what changes when on, what the off path
is, how it's targeted, and any precondition to check first.

**Tags: take one from what already exists.** Read the current tags before
inventing anything, because the vocabulary is small and reusing it is the whole
point:

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
let r = (http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_STAGE)"] $"($env.GROWTHBOOK_API_HOST_STAGE)/api/v1/features?limit=100")
$r.features | get tags | flatten | uniq -c | sort-by count --reverse
'
```

As of Aug 2026 stage has: `AI-Review` 12, `AI` 10, `mcp` 5, `billing` 3,
`Replay` 2, `auth` 2, `Autonomous Agent` 1, `sso` 1, `login` 1. `Autonomous
Agent` and `Replay` are used as a *second* tag next to `AI`.

Run the query rather than trusting that list — it was itself wrong once. Stage
holds 120 features and a page caps at 100, so a single `limit=100` silently
drops the tail; the counts above only came out right after paging with
`offset=100`. Case matters too: `Replay` and `replay` become two separate tags.

Pick the tag its siblings already carry: a new `ai-search-*` flag gets `AI`
because every other `ai-search-*` has it. Only when nothing fits, propose a new
tag to the user rather than deciding alone — a stray one-off tag is worse than
no tag, since it splits the family. New tags follow the existing casing
(`Autonomous Agent`, not `autonomous-agent`).

## Creating a flag

Environments differ per instance, so read them off a sibling flag rather than
assuming. Stage has 13 (`local-dev`, `stage`, `dev`, `lab0`–`lab7`, `e2e`,
`replay-dev`); prod has 3 (`prod`, `prod-eu`, `replay`). Copy the `enabled` map
from the closest sibling — e.g. `ai-search-model` on prod runs `prod` and
`prod-eu` enabled but `replay` disabled, and a new AI Search flag should match
that rather than switching itself on in Replay.

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
let f = (http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/ai-search-model").feature
print ($f.environments | items {|k v| $"($k)=($v.enabled)" })
'
```

`enabled` here means "this flag is served in that environment", not "the flag is
on". Keeping `defaultValue: "false"` is what keeps it off; enabling the
environment just makes it targetable there. An environment left out of the POST
defaults to disabled and the flag drops out of that environment's SDK payload
entirely, so list every environment you want it served in.

`defaultValue` is a **string**, even for a boolean flag — `"false"`, not
`false`. The API rejects a real JSON boolean.

Then the two-call dance. Body for the create:

```json
{
  "id": "my-flag",
  "valueType": "boolean",
  "defaultValue": "false",
  "owner": "Grzegorz Zalewski",
  "description": "What turning this on does. What the off path is. What to check before enabling.",
  "project": "",
  "archived": false,
  "environments": { "prod": { "enabled": true, "rules": [] } }
}
```

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
let body = (open /tmp/flag.json)
# 1. create (tags in here would be dropped — do not rely on them)
http post --content-type application/json --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features" $body | ignore
# 2. set tags in a second call
http post --content-type application/json --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/my-flag" {tags: ["AI"]} | ignore
# 3. read back — this is the only real confirmation
let g = (http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/my-flag").feature
print ($g | select id tags defaultValue)
'
```

Updating an existing flag uses the same `POST /features/{id}` with only the
fields you want changed.

## Keep the TypeScript side in sync

A GrowthBook flag and its code-side key are two halves; either alone is dead
weight. In `apps/api/src/modules/common/feature-flags/`:

- `types.ts` — add the key to the `FeatureFlagKey` union. Without it the call
  won't type-check.
- `feature-flags.service.ts` — `validateFeatureFlag` only runs a zod schema for
  JSON-valued flags. Boolean, string and number flags fall through
  `default: return value`, so they need no DTO. A JSON flag does: add a schema
  under `dto/` and a `case` in that switch.
- `getFeatureValue(key, default, { organizationId })` returns `default` when
  GrowthBook has no such flag, when the org isn't targeted, or when the network
  call times out (5s). That's why a missing flag fails quiet rather than loud —
  and why the default value must be the safe/old behaviour.

Each `getFeatureValue` call builds a fresh GrowthBook client and loads features
over the network, so several lookups in one request path belong in a single
`Promise.all` rather than sequential awaits.

## Targeting one org — a flag with no rules is dead

This is the step people skip. A freshly created flag has `rules: []` in every
environment, so GrowthBook serves `defaultValue` to *everyone*. Nothing is
broken and nothing logs a warning — the flag simply does nothing, forever, and
looks correctly configured in the UI. Creating the flag is half the job;
without a rule it is decoration.

`enabled: true` on an environment means "this flag is served here", not "this
flag is on". Those are separate ideas and the naming invites the mistake.

Rollout is per organization: add a `force` rule whose condition matches the
`organizationId` attribute. Copy the shape off a flag that already does it —
`ai-search-tracing` and `ai-search-model` on prod both carry
`condition: {"organizationId": "org_..."}`:

```nushell
nu -c '
source ~/.config/nushell/autoload/private.nu
(http get --headers [Authorization $"Bearer ($env.GROWTHBOOK_API_KEY_PROD)"] $"($env.GROWTHBOOK_API_HOST_PROD)/api/v1/features/ai-search-tracing").feature.environments.prod.rules
'
```

Three ways a rule that exists still does nothing:

- **Wrong environment.** Rules are per-environment and each environment has its
  own SDK connection key — 13 of them on stage. A rule added to `stage` does
  nothing for a service running with the `lab3` or `local-dev` key. Match the
  rule to the environment the deployed job actually uses.
- **Rule disabled.** A rule with `enabled: false` is dropped from the served
  payload silently, so the UI shows a rule and the SDK sees none.
- **Condition matches the wrong value.** The attribute must be literally
  `organizationId` and the value the `org_...` ULID, not the org slug.

The attribute itself needs no wiring — it's populated anywhere the API passes
`{ organizationId: orgId }` into `getFeatureValue`. But check that the *call
site* passes it: a `getFeatureValue` call without attributes can never match a
targeting rule, which is easy to miss when copying a flag lookup between
strategies.

To confirm what an SDK client will really receive, fetch the served payload for
that environment's client key rather than reading `rules` in the admin API —
the payload is the thing that decides.

## Checklist

Before saying a flag is done:

- [ ] `description` filled and it explains the danger of switching it on
- [ ] `tags` non-empty, taken from the existing vocabulary
- [ ] read back from the API after writing — the create call lies about tags
- [ ] environments copied from a sibling, not invented
- [ ] `defaultValue` is the safe/old behaviour, written as a string
- [ ] the key exists in the `FeatureFlagKey` union
- [ ] done on **both** instances if the change ships to prod
- [ ] if anyone is meant to actually get the new behaviour, a targeting rule
      exists in the environment their service runs in — otherwise the flag is
      created, tagged, documented and completely inert
