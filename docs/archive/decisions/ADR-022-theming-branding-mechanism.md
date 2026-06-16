---
status: Archived — consolidated into DESIGN-MANUAL.md
date: 2026-05-02
deciders: shane
amended: 2026-06-10
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
- **Logo** — upload a light-theme image; optional second image for dark theme. If only one is
  provided, the dashboard CSS-inverts it for the other theme (see single-logo inversion note
  in Consequences below). Alt text is stored as `logo_alt` in `branding.json`; the
  dashboard enforces a non-empty alt guarantee: if the operator leaves `logo_alt` blank, it
  falls back to `"<site_title> logo"` or a generic default so the rendered `<img alt="...">`
  is never empty (ADR-026 §5.5 satisfied).
- **Site title** — operator-supplied string written to `branding.json` (`siteTitle` field);
  the dashboard's `BrandingProvider` writes it to `document.title` at runtime.
- **Favicon URL** — operator-supplied URL written to `branding.json` (`faviconUrl` field);
  `BrandingProvider` updates `<link rel="icon">` at runtime.
- **Custom CSS slot** — operator-supplied URL; the dashboard `<link>`s it last so operator
  rules override theme tokens. Delivered as `customCssUrl` in `branding.json` (null when not
  configured). Power-user escape hatch; CSS variable names are NOT promised stable across
  versions.
- **Google Analytics Measurement ID** — GA4 tracking ID (`G-XXXXXXXXXX`). When configured,
  the dashboard shows a cookie consent banner (GDPR-compliant opt-in). GA loads only after
  visitor consent. Stored as `googleAnalyticsId` in `branding.json`.
- **Privacy regions** — comma-separated continent list (e.g., `"north-america,europe"`) or
  `"global"`. Controls which jurisdiction-specific privacy/accessibility laws are shown on
  the Legal page. Stored as `privacyRegions` in `branding.json`.
- **Default theme mode** — locked by [ADR-023](ADR-023-light-dark-mode-mechanism.md).
- **Hero imagery** — locked by [ADR-009](ADR-009-design-direction.md).

### Storage and delivery

Branding configuration is a static JSON file served by Caddy — the same pattern as `webcam.json` ([ARCHITECTURE.md](../ARCHITECTURE.md)). The API has no branding awareness.

| Concern | Mechanism |
|---------|-----------|
| **Writer** | Setup wizard writes `branding.json` to `/etc/weewx-clearskies/` on apply |
| **Storage** | `/etc/weewx-clearskies/branding.json` (outside the web root, safe from rsync --delete) |
| **Transport** | Caddy `handle /branding.json { root * /etc/weewx-clearskies; file_server }` |
| **Reader** | Dashboard fetches `/branding.json` at boot via `BrandingProvider` |

**`branding.json` schema:**

```json
{
  "siteTitle": "",
  "copyrightEntity": "",
  "logo": { "lightUrl": "", "darkUrl": "", "alt": "" },
  "faviconUrl": "",
  "accent": "blue",
  "defaultThemeMode": "auto-os",
  "customCssUrl": null,
  "social": { "facebook": "", "twitter": "", "instagram": "", "youtube": "" },
  "googleAnalyticsId": "",
  "privacyRegions": "global"
}
```

**Why not the API?** The API is a weather data access layer — archive queries, provider aggregation, setup endpoints. Branding is site presentation config with no relationship to weather data. The API may run on a different host than the front-end (two-host topology, ADR-034). Serving branding from the API couples a presentation concern to a data service and forces a cross-host round-trip for static config the front-end host already has on disk.

### Runtime mechanism

1. Dashboard fetches `branding.json` from Caddy at boot (static file, no API involvement).
2. Theme provider sets variables via `style.setProperty('--brand-primary-light', ...)`,
   `style.setProperty('--brand-primary-dark', ...)`,
   `style.setProperty('--brand-primary-fg-light', ...)`, and
   `style.setProperty('--brand-primary-fg-dark', ...)` on the root element after
   [ADR-023](ADR-023-light-dark-mode-mechanism.md)'s `data-theme` is applied.
   `index.css` aliases these into the shadcn `--primary` / `--primary-foreground` tokens
   inside `:root` and `[data-theme="dark"]` blocks so Tailwind utility classes
   (`bg-primary`, `text-primary-foreground`, etc.) pick up the operator palette
   without knowing the accent key.
3. Logo URLs and alt text are consumed via the `useBranding()` hook inside layout
   components (no prop-drilling). Components call `useBranding()` directly to read
   `branding.logo.light`, `branding.logo.dark`, and `branding.logo.alt`.
   When the operator has uploaded only a light logo (`branding.logo.dark` is absent),
   the dashboard applies a CSS `invert` class to the `<img>` when the resolved theme
   is dark, making the logo visible on the dark rail background. This inversion is
   CSS-only — no server-side processing.
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
- **Single-logo inversion note:** The setup wizard's Appearance step warns the operator when
  only one logo variant is uploaded (light-only or dark-only) that the dashboard will
  CSS-invert that single logo for the opposite color theme and it may not look correct. This
  is a non-blocking advisory; uploading a matching second variant avoids the inversion.
  (Built.)

## Out of scope

- Specific accent hex values per palette entry — Phase 3.
- Adding palette entries post-launch — future ADR if demand surfaces.
- Hero imagery upload pipeline — [ADR-009](ADR-009-design-direction.md).
- Operator media directory paths — [ADR-027](ADR-027-config-and-setup-wizard.md).

## Amendment log

### 2026-06-10 — Branding moves from API to static file via Caddy

**Previous:** Branding config stored in `api.conf [branding]`, served by the API at `GET /api/v1/branding`, proxied through the former realtime service to the dashboard.

**New:** Branding config stored in `/etc/weewx-clearskies/branding.json`, served directly by Caddy as a static file at `/branding.json`. The wizard writes the file on apply. The API has no branding awareness.

**Rationale:** The API is a weather data access layer (ADR-010). Branding is site presentation config — accent colors, logos, theme mode, social URLs, analytics IDs, privacy regions. In a two-host topology (ADR-034), the API runs on the weewx host while the front-end host already has the branding config on disk. Routing branding through the API forces a cross-host round-trip for static config. The `webcam.json` pattern (wizard writes, Caddy serves) is proven and simpler.

**Impact on existing code:**
- API: `BrandingSettings`, `BrandingApplyConfig`, `BrandingConfig` response model, `/api/v1/branding` endpoint, branding service — all to be removed or deprecated.
- Dashboard: `BrandingProvider` fetch URL changes from `/api/v1/branding` to `/branding.json`.
- Wizard: Apply function writes `branding.json` directly instead of sending branding to `/setup/apply`.
- Caddy: Add `handle /branding.json` route (same pattern as `handle /webcam.json`).
- OpenAPI contract: Remove `/branding` endpoint definition.

## References

- Walk artifact: cat 11 in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Related: [ADR-009](ADR-009-design-direction.md), [ADR-023](ADR-023-light-dark-mode-mechanism.md), [ADR-026](ADR-026-accessibility-commitments.md), [ADR-027](ADR-027-config-and-setup-wizard.md).
