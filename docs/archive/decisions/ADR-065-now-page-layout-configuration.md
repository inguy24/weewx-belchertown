---
status: Archived — consolidated into DASHBOARD-MANUAL.md + OPERATIONS-MANUAL.md
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-065: Now page layout configuration

## Context

The Now page card composition — which cards appear, in what order, and at what size — is hardcoded in `now.tsx`. An operator who wants to reorder cards, hide one, or change a card's column span must edit React source and rebuild the dashboard. This conflicts with the project's design principle that operators configure via admin UI, not source code.

ADR-064 introduces a card plugin contract that makes cards self-describing and self-contained. With that contract in place, the Now page can become a generic container that renders cards from a configuration file rather than hardcoded JSX. This ADR decides the configuration format and the container's rendering behavior.

The configuration must be a static file (not an API endpoint) because card layout is a presentation concern — the API is the data layer, not a UI control plane. This follows the same architectural boundary that motivates moving page visibility out of the API (ADR-024 amendment, same date).

## Options considered

| Option | Verdict |
|---|---|
| A. Static JSON file in config directory, served by Caddy | **Selected.** Matches existing patterns (`branding.json`, `webcam.json`). Caddy already serves static config from `/etc/weewx-clearskies/`. No API involvement. Dashboard fetches on load, falls back to built-in default on 404. |
| B. API endpoint (`/api/v1/layout`) | Rejected — layout is a presentation concern; adding it to the API violates the computation boundary (ARCHITECTURE.md). The API serves weather data and enrichment, not UI state. |
| C. localStorage only (no server-side config) | Rejected — layout is an operator decision (applies to all visitors), not a per-visitor preference. localStorage is per-browser. |
| D. Inline in `branding.json` | Rejected — `branding.json` is already dense; mixing visual branding with structural layout creates a mega-config that's hard to reason about. Separate concerns, separate files. |
| E. ConfigObj/INI section in `stack.conf` | Rejected — card layout is an ordered array of typed objects; INI is not well-suited for ordered collections of structured records. JSON is the natural fit and matches `branding.json`/`webcam.json` precedent. |

## Decision

**The Now page card composition is configurable via `/etc/weewx-clearskies/now-layout.json`, served by Caddy as a static file.**

File format:

```json
{
  "version": 1,
  "cards": [
    { "type": "current-conditions", "footprint": "tile", "rowSpan": 1 },
    { "type": "radar", "footprint": "wide", "rowSpan": 2.5 }
  ]
}
```

- **`version`**: schema version for forward compatibility.
- **`cards`**: ordered array. Each entry names a card type (from the card registry, per ADR-064), a footprint, and a rowSpan. Card order in the array determines rendering order; CSS Grid auto-placement fills the column grid.
- **Cards not in the list don't render.** This is how operators hide individual Now page cards.
- **The NowHeroCard is a layout element, not a configurable card.** It renders unconditionally outside the card grid. It is not listed in `now-layout.json`.

**Fallback behavior:** When the file is absent (fresh install before the admin has been used, or operator has not customized layout), the dashboard uses a built-in default layout matching the current hardcoded card arrangement. The default is compiled into the dashboard bundle — it is not generated at deploy time.

**Caddy serving:** A `handle /now-layout.json` block in the Caddyfile serves from `/etc/weewx-clearskies/` with `Cache-Control: no-cache` (operator changes take effect on next page load without cache busting). This follows the same pattern as `branding.json` and `webcam.json`.

**Admin editor (Phase 4):** The admin card layout editor (in the config UI stack repo) reads the card manifest (ADR-064 build-time JSON) to populate a palette of available cards, reads the current `now-layout.json` for the active layout, provides drag-and-drop reordering (Sortable.js) with keyboard-accessible alternatives, and writes the updated layout on save. The editor is a presentation tool — it writes a static file, not an API call.

**v2 cards directory:** Third-party cards (v2 scope) will be stored at `/var/www/clearskies/cards/`, excluded from redeploy rsync (same isolation pattern as `webcam/`). The card registry merges built-in and custom cards at runtime. `now-layout.json` can reference both built-in and custom card types.

## Consequences

- **Operator control without source edits.** Card order, selection, and sizing are configuration, not code.
- **Graceful fallback.** The dashboard works identically to today when no layout config exists — the default layout is compiled in.
- **New static config file.** `/etc/weewx-clearskies/now-layout.json` joins the existing config inventory (`api.conf`, `stack.conf`, `branding.json`, `webcam.json`, `secrets.env`, `charts.conf`). Must be documented in ARCHITECTURE.md and OPERATIONS-MANUAL.md.
- **New Caddy route.** All three Caddyfile variants (frontend-host, single-host, reverse-proxy example) need the `handle /now-layout.json` block.
- **Redeploy script update.** The `cards/` directory (v2 prep) needs an rsync `--exclude` to survive dashboard redeployments.
- **React hooks constraint.** The Now page container must call all data-fetching hooks unconditionally (React rules of hooks). Endpoints not needed by the active card set use skip/enabled flags — not conditional hook calls.

## Acceptance criteria

- [ ] The Now page renders identically to its current state when `now-layout.json` is absent (fallback to compiled-in default).
- [ ] Creating a `now-layout.json` with a subset of cards renders only those cards on the Now page.
- [ ] API endpoints not needed by the active card set are not fetched (verified via network inspector).
- [ ] The `cards/` directory in the web root survives a dashboard redeploy (rsync exclude).
- [ ] All three Caddyfile variants serve `/now-layout.json` from `/etc/weewx-clearskies/` with `Cache-Control: no-cache`.

## Implementation guidance

Prescriptive rules (TypeScript types, fetch behavior, default layout constant, Caddy route syntax, rsync exclude) will be extracted into **DASHBOARD-MANUAL.md**, **ARCHITECTURE.md**, and **OPERATIONS-MANUAL.md** after acceptance. Agents implement from the manuals.

## References

- Related: ADR-064 (card plugin contract), ADR-051 (card footprint model), ADR-024 (page taxonomy), ADR-027 (config wizard)
- Pattern precedent: `branding.json` and `webcam.json` static config files (ARCHITECTURE.md §Configuration files)
