---
description: Keep Reunite auth Playwright tests simple and helper-driven
globs: e2e/reunite/tests/auth/**/*.ts
alwaysApply: false
---

# Reunite Auth Playwright Tests

When working in `e2e/reunite/tests/auth/**/*.ts`, keep tests simple and aligned with Playwright best practices.

- Do not use page objects in auth tests.
- Do not import from `e2e/reunite/page-objects`.
- Do not import from `e2e/reunite/helpers/commands`.
- Do not use `cleanUpNomadJobs` in auth tests.
- Prefer small function helpers under `e2e/reunite/tests/auth/helpers`.
- Prefer fixtures under `e2e/reunite/tests/auth/fixtures` for setup and login flows.
- Keep specs readable: arrange steps around user-visible behavior and assertions, not implementation details.
- If a flow needs shared behavior, add a narrow helper function instead of a class abstraction.

## Why

Follow the functional-helper style described in [Page Objects vs. Functional Helpers](https://dev.to/muratkeremozcan/page-objects-vs-functional-helpers-2akj):

- Playwright already provides high-level interaction APIs, so wrapping `page`, `locator`, `click`, or `fill` in page-object classes usually adds little value.
- Functional helpers compose better than class-based page objects and avoid inheritance/base-page abstractions.
- Direct helpers make failures easier to debug because the test flow stays close to the Playwright actions and assertions.
- Prefer stable locators and focused helper functions over broad page abstractions.
