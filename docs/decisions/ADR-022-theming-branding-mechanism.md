---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-022: Theming and branding mechanism

## Context

[ADR-009](ADR-009-design-direction.md) commits to operator-customizable accent color (curated palette), operator-uploaded logo, and theme modes. This ADR locks the runtime mechanism — how operator branding choices reach the rendered dashboard without a rebuild.

## Decision

**CSS variables on `:root` and `[data-theme="dark"]`** (per [ADR-023](ADR-023-light-dark-mode-mechanism.md)) carry all theme tokens. Operator-controlled values flow from configuration to the root element at runtime — no rebuild.

### Operator inputs (configuration UI / setup wizard)

- **Accent color** — pick one from a curated set: `blue` / `teal` / `indigo` / `purple` / `green` / `amber`. Each entry holds two AA-tested hex values (one per theme). Curated, not a free-form picker — protects WCAG AA compliance against operator "I'll just use my brand red" choices.
- **Logo** — upload a light-theme image; optional second image for dark theme. If only one is provided, the dashboard CSS-inverts it for the other theme and the configuration UI **warns the operator** that the auto-inverted result may look wrong. Alt text required at upload per [rules/coding.md](../../rules/coding.md) §5.5.
- **Custom CSS slot** — operator can drop a `custom.css` into the config directory; dashboard `<link>`s it last so it overrides theme tokens. Power-user escape hatch; CSS variable names are NOT promised stable across versions.
- **Default theme mode** — locked by [ADR-023](ADR-023-light-dark-mode-mechanism.md).
- **Hero imagery** — locked by [ADR-009](ADR-009-design-direction.md).

### Runtime mechanism

1. Dashboard fetches branding values from clearskies-api at boot (endpoint shape lives with the OpenAPI contract / [ADR-018](INDEX.md), Pinned).
2. Theme provider sets variables via `style.setProperty('--accent', ...)` etc. on the root element after [ADR-023](ADR-023-light-dark-mode-mechanism.md)'s `data-theme` is applied.
3. Logo URLs are React props to layout components.
4. `custom.css` is served as a static asset and `<link>`'d last.

No Cheetah `*.inc` hooks (Belchertown precedent dropped — not portable to React).

## Options considered

| Option | Verdict |
|---|---|
| A. CSS variables + runtime config (this ADR) | **Selected** — runtime swappable, no rebuild, fits ADR-023's `data-theme` model. |
| B. Build-time Tailwind config (operator rebuilds for branding changes) | Rejected — operators are not Node developers. |
| C. Free-form accent color picker | Rejected — operators don't reliably pick AA-passing colors. Curated palette protects compliance. |

## Consequences

- Six accent palette entries × 2 themes × n consumers = at-most ~12 hex values to design and AA-verify in Phase 3.
- Operator media directory layout (logos, `custom.css`, hero images) is defined by [ADR-027](ADR-027-config-and-setup-wizard.md).
- `custom.css` documented in `CONFIG.md` as unsupported beyond best-effort: operator owns the override.
- Auto-inverting a single uploaded logo for the other theme is a documented compromise; operators with strong branding upload both variants.

## Out of scope

- Specific accent hex values per palette entry — Phase 3.
- Adding palette entries post-launch — future ADR if demand surfaces.
- Hero imagery upload pipeline — [ADR-009](ADR-009-design-direction.md).
- Operator media directory paths — [ADR-027](ADR-027-config-and-setup-wizard.md).

## References

- Walk artifact: cat 11 in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Related: [ADR-009](ADR-009-design-direction.md), [ADR-023](ADR-023-light-dark-mode-mechanism.md), [ADR-026](ADR-026-accessibility-commitments.md), [ADR-027](ADR-027-config-and-setup-wizard.md).
