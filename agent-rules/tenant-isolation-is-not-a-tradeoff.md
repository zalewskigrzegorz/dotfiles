---
description: When a conflict or design choice pits the access boundary between organizations/tenants against convenience, take the stricter side in one sentence — no essay, no popup
alwaysApply: true
---

# Tenant Isolation Is Not a Trade-off

During a rebase two fixes for the same bug collided ("a user without
membership reaches another organization's routes"): lazy resolve on `main`
versus withholding membership on the branch. Greg got a long comparison of
both worlds and answered: "No ale zły user nie powinien mieć dostępu do danych
innej organizacji kropka" (9befa5d1, 2026-10-12).

## Rules

1. **One side is the access boundary between organizations or tenants, the
   other is convenience** (a fallback, a lazy resolve, a looser check) → take
   the stricter one. Convenience is allowed only behind that boundary.
2. **Say it in one sentence**: what you picked and why. No essay comparing
   both sides, no popup.
3. **A popup only when the strict version breaks a feature** (e.g. an editor
   that legitimately works without membership). Then the fork is real: name
   the broken feature, and offer the narrowest exception, scoped to sessions
   bound to that organization and logged at `error` on every use.
