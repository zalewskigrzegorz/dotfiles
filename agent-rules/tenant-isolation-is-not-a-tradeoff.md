---
description: When a conflict or design choice pits the access boundary between organizations/tenants against convenience, take the stricter side in one sentence — no essay, no popup
alwaysApply: true
---

# Tenant Isolation Is Not a Trade-off

Two fixes for "a user without membership reaches another organization's routes" collided in a rebase; Greg got a long comparison and answered: "No ale zły user nie powinien mieć dostępu do danych innej organizacji kropka" (9befa5d1).

1. **One side is the access boundary between organizations or tenants, the other is convenience** (a fallback, lazy resolve, looser check) → take the stricter one; convenience only behind that boundary.
2. **Say it in one sentence**: what you picked and why. No essay, no popup.
3. **A popup only when the strict version breaks a feature** (an editor that legitimately works without membership): name the broken feature and offer the narrowest exception, scoped to sessions bound to that organization and logged at `error` on every use.
4. **An email or identity from a customer's own IdP is never "verified" without proof**: its admin can type anyone's email, and trusting it links accounts across organizations. In issue and PR drafts the loosened variant is at most a "rejected alternative".
