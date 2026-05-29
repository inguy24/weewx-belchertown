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
3. No-flash is achieved via a two-layer approach:
   - **Inline `<script>` in `index.html`** (classic script, not `type="module"`) runs
     synchronously during HTML parse, before any CSS or React loads. It reads
     `localStorage.getItem('clearskies.theme.user-override')` and calls
     `document.documentElement.setAttribute('data-theme', ...)` immediately, so the
     correct theme is applied before the first paint.
   - **`ThemeProvider` `useEffect`** keeps `data-theme` in sync on subsequent renders
     (preference change, operator default change).
   The inline script handles the stored `light` / `dark` preferences; if neither is set
   it falls back to `window.matchMedia('(prefers-color-scheme: dark)')`, matching the
   ThemeProvider's 'system' default.
4. **`auto-sunrise-sunset`**: fetches sunrise/sunset UTC times from the almanac API at app
   load. Computes the current day/night state and schedules a timer to flip `data-theme`
   at the next sunrise or sunset. Additionally schedules a **midnight re-fetch** timer so
   that the next day's almanac times are loaded at local midnight (not just on the next
   app load). **Polar-region clamp**: if the next event (sunrise or sunset) is more than
   24 hours away — which can happen near polar day/night even with non-null rise/set
   strings — the timer is clamped to local midnight so stale times do not hold the theme
   frozen for an entire day. If the almanac returns null rise/set (true polar night/day),
   the provider falls back to `prefers-color-scheme`.
5. **`auto-os`**: subscribes to `window.matchMedia('(prefers-color-scheme: dark)')` and updates on change.

The user-facing toggle cycles through three states: **system → light → dark → system**.
`system` means "follow the operator default" (which may itself be auto-sunrise-sunset
or auto-os). The stored localStorage value is `light`, `dark`, or `system`; `system`
is the default for new visitors (no stored value).

6. Provides a UI control embedded in the **nav-rail** for the user to override the operator
   default. On desktop, a `DesktopThemeButton` sits at the bottom of the left rail.
   On mobile, a `ThemeRowButton` appears inside the "More" sheet (accessed via the
   bottom-bar overflow trigger). There is no standalone settings page or footer control.

Tailwind v4 reads `data-theme` via a `@custom-variant` declaration in `index.css`:

```css
@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));
```

There is no `darkMode` key in a `tailwind.config.*` file — Tailwind v4 moves all
configuration into CSS. Utilities like `dark:bg-slate-900` continue to work because
the `dark` variant is now defined by the `@custom-variant` rule above, which
activates whenever the `data-theme="dark"` attribute is on any ancestor element.

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
