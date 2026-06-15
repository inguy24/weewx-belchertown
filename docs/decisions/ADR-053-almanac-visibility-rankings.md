---
status: Accepted
date: 2026-06-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-053: Almanac Visibility Ranking System & Unified Color Scale

## Context

The almanac page displays four types of astronomical events — solar eclipses, lunar eclipses, meteor showers, and planet viewing quality — each with a visibility/quality rating. Without a unified system, each card would invent its own tier names, colors, and formulas, creating an inconsistent user experience.

This ADR locks the tier definitions, computation formulas, color scale, and data provenance for all four event types so implementation agents have unambiguous specifications.

Planet viewing quality is already implemented (see archived `PLANET-VIEWING-QUALITY-PLAN.md`). This ADR documents it for completeness and captures the three remaining event types.

## Decision

A unified 5-tier color scale applies across all almanac visibility ratings. Each event type maps its domain-specific metric to one of five tiers.

### Unified color scale

| Tier | Color | Hex | Meaning |
|---|---|---|---|
| 1 (best) | Green | `#22c55e` | Excellent / Fully Visible |
| 2 | Lime | `#84cc16` | Good / Mostly Visible |
| 3 | Yellow | `#eab308` | Fair / Partially Visible |
| 4 | Orange | `#f97316` | Poor / Barely Visible |
| 5 (worst) | Red | `#ef4444` | Not Visible |

### Solar eclipse visibility

**Data source:** AstronomyAPI.com Events endpoint (`GET /api/v2/bodies/events/sun`). Provides `obscuration` (maximum percentage of solar disk covered at the observer's location) and `eventHighlights` with `altitude` at each contact time.

**Tier computation (from `obscuration` O and peak `altitude` A):**

| Tier | Label | Condition | User experience |
|---|---|---|---|
| 1 Green | Fully Visible | `totalStart` is non-null (observer in path of totality/annularity) | Corona visible or Ring of Fire |
| 2 Lime | Mostly Visible | O ≥ 75% | Noticeable twilight drop in daylight |
| 3 Yellow | Partially Visible | 10% ≤ O < 75% | Crescent Sun shape visible |
| 4 Orange | Barely Visible | O < 10% | Very slight dimming, hard to notice |

Note: "Not Visible" is not a solar eclipse tier because AstronomyAPI.com only returns eclipses visible from the observer's location. Eclipses whose shadow does not reach the station are omitted from the response entirely.

**Graceful degradation:** When AstronomyAPI.com credentials are not configured, the API returns eclipse dates and types from Skyfield only (no obscuration, no contact times). Dashboard shows the eclipse with type badge but omits visibility tier and contact times.

### Lunar eclipse visibility

**Data source:** AstronomyAPI.com Events endpoint (`GET /api/v2/bodies/events/moon`). Provides `eventHighlights` with `altitude` at each contact time (penumbralStart through penumbralEnd) and `obscuration`.

**Tier computation (from peak `altitude` A and contact altitudes):**

| Tier | Label | Condition | User experience |
|---|---|---|---|
| 1 Green | Visible All Night | Peak A > 15° AND all contact altitudes > 0° | Entire eclipse visible from start to finish |
| 2 Lime | Mostly Visible | Peak A > 15° AND some contacts < 0° | Peak visible but some phases below horizon |
| 3 Yellow | Low in Sky | 0° < Peak A ≤ 15° | Eclipse visible but low, atmospheric distortion |
| 4 Orange | Barely Visible | 0° < Peak A ≤ 5° | Just above horizon, very difficult to observe |
| 5 Red | Not Visible | Peak A ≤ 0° | Eclipse entirely below horizon |

### Meteor shower visibility

**Data source:** Skyfield (radiant altitude computation) + Skyfield (moon illumination at peak date). Both computed in `compute_meteor_showers()` in `services/almanac.py`. Static catalog data (ZHR, velocity, descriptions) from IMO/AMS.

**Tier computation (from radiant altitude R and moon illumination M at peak date):**

| Tier | Label | Condition | User experience |
|---|---|---|---|
| 1 Green | Excellent | R > 40° AND M < 25% | Dark skies, high radiant — ideal |
| 2 Lime | Good | R > 20° AND M < 50% (and not tier 1) | Mostly dark, decent radiant altitude |
| 3 Yellow | Fair | R > 10° AND (M ≥ 50% OR R ≤ 40%) (and not tier 1-2) | Some moon interference or moderate radiant |
| 4 Orange | Poor | R ≤ 10° OR (M > 75% AND R ≤ 30°) | Heavy moon washout or radiant too low |
| 5 Red | Not Visible | R < 0° (radiant never rises) | Shower not observable from this latitude |

### Planet viewing quality (reference — already implemented)

Documented in full in the archived `PLANET-VIEWING-QUALITY-PLAN.md`. Summary:

**Data sources:** 7Timer seeing forecast (API endpoint `GET /almanac/seeing-forecast`), planet altitude from Skyfield, cloud cover from 7Timer.

**Formula:** `score = (seeing_score × 0.80) + (transparency_score × 0.05) + (altitude_score × 0.15)`. Cloud gate (cloudcover > 6 → Not Visible). Mercury elongation gate (< 12° → Not Visible, cap at Good). Uranus/Neptune moon penalty.

**Tier mapping:** score ≥ 0.75 → Excellent, 0.50–0.74 → Good, 0.30–0.49 → Fair, < 0.30 → Poor.

## Data provenance

| Data | Authoritative source | Notes |
|---|---|---|
| Solar eclipse dates + types | Skyfield `eclipselib` | Computed locally, no API needed |
| Solar eclipse contact times, altitudes, obscuration | AstronomyAPI.com Events/sun endpoint | Optional — graceful degradation without credentials |
| Lunar eclipse dates + types | Skyfield `eclipselib` | Computed locally |
| Lunar eclipse contact times, altitudes | AstronomyAPI.com Events/moon endpoint | Optional |
| Meteor shower ZHR | IMO Annual Meteor Shower Calendar (imo.net) | Static catalog, entered once |
| Meteor shower velocity (km/s) | IMO Meteor Shower Working List | Static catalog |
| Meteor shower radiant RA/Dec | IMO Meteor Shower Working List (J2000.0) | Static catalog |
| Meteor shower descriptions | IMO + AMS (amsmeteors.org) published characteristics | One-line editorial summaries |
| Meteor shower solar longitude max | IMO Meteor Shower Database | Static catalog |
| Meteor shower radiant altitude | Skyfield — computed at observer location for peak date | Per-request computation |
| Meteor shower moon illumination | Skyfield — computed for peak date | Per-request computation |
| Planet seeing forecast | 7Timer ASTRO product (7timer.info) | 3-hour intervals, 3-day forecast |
| Planet altitude, RA/Dec, elongation, magnitude | Skyfield | Per-request computation |

## Consequences

- All four almanac card types share the same 5-color scale — users learn one visual language.
- The scale is ordinal (green→red = better→worse) which is universally intuitive.
- Orange (tier 4) is a thin band — most events will be clearly Good/Fair or Not Visible. Orange captures the edge cases (very low partial eclipses, heavy moon + low radiant showers).
- AstronomyAPI.com is the only external dependency for eclipse tiers; meteor and planet tiers are fully local (Skyfield + 7Timer).
- Repos affected: `weewx-clearskies-api` (tier computation in endpoints), `weewx-clearskies-dashboard` (color mapping in components).

## Acceptance criteria

- [ ] Solar eclipse endpoint returns `visibility` field with one of the 5 tier labels
- [ ] Lunar eclipse endpoint returns `visibility` field with one of the 5 tier labels
- [ ] Meteor shower endpoint returns `viewingQuality` field with one of the 5 tier labels
- [ ] Planet endpoint `viewingQuality` field uses the same tier label set (already implemented)
- [ ] Dashboard renders all tiers with the correct hex color from the unified scale
- [ ] Graceful degradation: when AstronomyAPI.com is unavailable, eclipse visibility is null (not a crash)
- [ ] ADR-053 color hex values match the CSS variables used in the dashboard (`vc-excellent`, `vc-good`, `vc-fair`, `vc-poor`, `vc-none`)

## Implementation guidance

- Solar/lunar tier computation goes in the API endpoint handlers (not the client class — the client returns raw data, the endpoint computes the tier).
- Meteor tier computation goes in `compute_meteor_showers()` in `services/almanac.py`.
- Dashboard color mapping: use CSS classes `.vc-excellent` (#22c55e), `.vc-good` (#84cc16), `.vc-fair` (#eab308), `.vc-poor` (#f97316), `.vc-none` (#ef4444) — already defined in the mockup CSS.
- Planet viewing quality is already implemented — do not re-implement. Reference the API's enrichment pipeline.
- Type badge click modals (Total/Annular/Partial definitions) are a dashboard-only UI feature, not an API concern.
- **AstronomyAPI.com obscuration scale:** The API returns `extraInfo.obscuration` as a 0–1 fraction (NOT 0–100 percentage). Multiply by 100 before comparing against the tier thresholds above.
- **AstronomyAPI.com is location-filtered:** The API only returns eclipses visible from the observer's location. If an eclipse's shadow does not reach the observer, it is omitted entirely. There is no global/unfiltered mode. The "Not Visible" tier therefore never appears for eclipses (only for meteor showers where radiant altitude < 0°).
- **AstronomyAPI.com response format:** Use `output=rows` query parameter to get `data.rows[].events[]` structure. The default `output=table` returns `data.table.rows[].cells[]` which is a different shape.

### Eclipse query window and progressive fill

- **API window:** Both endpoints default to a 10-year window (3652 days). This ensures enough data for the progressive fill algorithm.
- **Dashboard progressive fill rule:** The eclipse cards (solar + lunar) show up to 4 columns, never scrolling. Algorithm:
  1. Filter API results to eclipses within the next 2 years.
  2. If 2-year results fill or overflow 4 columns, show only the first 4 from the 2-year set.
  3. If fewer than 4 in the 2-year window, backfill from the full API result set (up to 10 years) until 4 columns are filled or data runs out.
  4. Never trigger horizontal scrolling on eclipse cards — max 4 columns.
- **Rationale:** Solar eclipses are rare per location (often 0–1 in a 2-year window). Showing a 10-year backfill prevents an empty card for locations between eclipse paths, while the 2-year priority ensures near-term events take precedence.

## References

- Related ADRs: ADR-048 (theme color tokens), ADR-049 (icon system), ADR-051 (card footprint model)
- Archived plan: `docs/archive/PLANET-VIEWING-QUALITY-PLAN.md`
- C7 plan: `docs/planning/briefs/C7-ALMANAC-PAGE-PLAN.md` (tasks T0.0, T1.4, T1.5, T1.7)
- AstronomyAPI.com docs: `docs/reference/api-docs/astronomyapi.md`
- 7Timer docs: `docs/reference/api-docs/7timer.md`
- IMO Meteor Shower Calendar: https://www.imo.net/resources/calendar/
- AMS Meteor Shower Guide: https://www.amsmeteors.org/meteor-showers/
