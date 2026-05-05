---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-023: Light/dark mode mechanism

## Context

[ADR-009](ADR-009-design-direction.md) commits to four theme modes: **light**, **dark**, **auto-by-sunrise-sunset**, **auto-by-OS** (`prefers-color-scheme`). This ADR locks the runtime mechanism that resolves the active theme.

## Decision

Resolved theme is communicated to CSS via a **`data-theme` attribute on `<html>`** (dashboard) and on the equivalent root element (configuration UI). Values: `light` | `dark`. Auto modes resolve to one of these at runtime.

A theme provider at the top of the React tree:

1. Reads operator default mode from configuration (`light` / `dark` / `auto-sunrise-sunset` / `auto-os`).
2. Reads user override from `localStorage` (`clearskies.theme.user-override`) if present. User override wins.
3. Resolves to a concrete `light` or `dark` and sets `<html data-theme="...">` synchronously on first render — no flash of wrong theme.
4. **`auto-sunrise-sunset`**: re-evaluates at app load and at the next sunrise/sunset (timer set from sunrise/sunset times the api supplies).
5. **`auto-os`**: subscribes to `window.matchMedia('(prefers-color-scheme: dark)')` and updates on change.
6. Provides a UI control (footer or settings) for the user to override the operator default.

Tailwind reads `data-theme` via the v3+ `darkMode: ['selector', '[data-theme="dark"]']` config (or equivalent) so utilities like `dark:bg-slate-900` continue to work.

## Options considered

| Option | Verdict |
|---|---|
| A. `data-theme` attribute on `<html>` (this ADR) | **Selected** — extends to future themes (high-contrast, sepia) without churning class names. |
| B. Tailwind's class-based dark mode (`<html class="dark">`) | Rejected — works for two modes but constrains future palette additions. |
| C. Two pre-built CSS bundles | Rejected — runtime mode switching breaks; bundle size doubles. |

## Consequences

- Auto-sunrise-sunset depends on sunrise/sunset times in the api payload (already needed by the Now page and Almanac per [ADR-014](ADR-014-almanac-data-source.md)).
- localStorage override key: `clearskies.theme.user-override`. Values: `light` / `dark` / `system` (= follow operator default).
- Operator default mode is set in the setup wizard ([ADR-027](ADR-027-config-and-setup-wizard.md)) and re-configurable later.
- No theme-transition animation; instant swap respects [ADR-009](ADR-009-design-direction.md) motion budget and `prefers-reduced-motion`.

## Out of scope

- Specific palette hex values — Phase 3.
- High-contrast or sepia themes — future ADR if added.
- Per-page theme override — not supported.

## References

- Walk artifact: cat 11 in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Related: [ADR-009](ADR-009-design-direction.md), [ADR-014](ADR-014-almanac-data-source.md), [ADR-022](INDEX.md) (theming — Pinned), [ADR-027](ADR-027-config-and-setup-wizard.md).
