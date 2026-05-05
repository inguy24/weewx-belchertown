---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-025: Browser support matrix

## Context

Phase 3 dashboard scaffold needs an explicit browser floor. Older browsers cost build complexity (transpilation, polyfills) and constrain CSS/JS features. WCAG 2.1 AA ([ADR-026](ADR-026-accessibility-commitments.md)) implies modern browsers regardless.

## Decision

### Modern evergreen browsers, last 2 years

| Browser | Floor |
|---|---|
| Chrome / Edge / Chromium-based | last 2 years (~Chrome 110+) |
| Firefox | last 2 years (~Firefox 110+) |
| Safari (macOS / iPadOS) | 16.4+ |
| iOS Safari | 16.4+ |
| Android Chrome / Samsung Internet / WebView | last 2 years |

Older browsers may render the dashboard, but **we don't test against them and don't accept bug reports for them**.

### Browserslist config (Vite build target)

`>0.5%, last 2 years, not dead, not op_mini all`

Drives transpilation target and CSS prefixing. We don't ship IE11, Opera Mini, or `<2%`-niche browsers.

### Explicitly NOT supported

- Internet Explorer (any version) — EOL 2022.
- Browsers without ES2022 / `fetch` / `Intl.DateTimeFormat` / CSS custom properties / CSS Grid.
- No-JS rendering / progressive-enhancement-to-static — out of scope.

## Options considered

| Option | Verdict |
|---|---|
| A. Last 2 years evergreen + iOS Safari 16.4+ (this ADR) | **Selected** — current ecosystem mainstream, no transpilation tax. |
| B. Last 5 years evergreen | Rejected — pulls in pre-ES2022 baseline; bigger bundles, more polyfills, marginal user reach. |
| C. Bleeding edge (last 6 months) | Rejected — operators on stable distros run slightly older browsers; needlessly punitive. |
| D. Include IE11 / legacy Edge | Rejected — IE EOL, transpilation cost prohibitive, accessibility floor unmeetable. |

## Consequences

- Vite build targets recent ES baseline; minimal transpilation.
- Tailwind CSS Grid, container queries, and custom-property usage are unrestricted.
- `Intl.DateTimeFormat` ([ADR-020](ADR-020-time-zone-handling.md)) and `Intl.NumberFormat` ([ADR-021](ADR-021-i18n-strategy.md)) work natively — no polyfill.
- README and INSTALL.md state the supported browser floor.
- CI runs Playwright tests against latest Chromium, Firefox, WebKit.

## Out of scope

- Per-feature progressive enhancement — handled per-component.
- Browser-specific bugs in supported browsers — fixed.
- Continuous full cross-browser test matrix per release — Phase 4 work; Playwright defaults are the baseline.

## References

- Browserslist: https://browsersl.ist/
- Vite browser target: https://vitejs.dev/guide/build.html#browser-compatibility
- Related: [ADR-002](ADR-002-tech-stack.md), [ADR-020](ADR-020-time-zone-handling.md), [ADR-021](ADR-021-i18n-strategy.md), [ADR-026](ADR-026-accessibility-commitments.md).
