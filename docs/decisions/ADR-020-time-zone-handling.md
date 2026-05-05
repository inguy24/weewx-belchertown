---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-020: Time zone handling

## Context

[ADR-010](ADR-010-canonical-data-model.md) locks UTC ISO-8601 with `Z` suffix as the wire format for every timestamp. This ADR locks where the time zone for **display** comes from, where the station's TZ value lives, and the per-user override policy for v0.1.

## Decision

### Storage and wire format: UTC

Every timestamp on the wire ends in `Z`. No local-time strings in api responses.

### Display: station-local by default

The dashboard renders timestamps in the **station's local time zone**, not the visitor's browser-local zone. A visitor in Tokyo viewing a New England station sees Eastern times — they're looking at the station, not their location. Same precedent as every weewx skin.

The station TZ is delivered via `StationMetadata` ([ADR-010](ADR-010-canonical-data-model.md)) as an IANA identifier (e.g., `America/New_York`). Source priority:

1. Explicit operator setting in clearskies-api config (configuration UI / setup wizard, [ADR-027](ADR-027-config-and-setup-wizard.md)).
2. weewx config (`Station.timezone` if set).
3. Derived from operator lat/lon at first-run (one-time lookup; result persisted in operator config).

### Browser-side rendering

`Intl.DateTimeFormat` with the station TZ + active locale ([ADR-021](ADR-021-i18n-strategy.md)). No JS date library required for v0.1.

### No per-user TZ override at v0.1

Same precedent as units ([ADR-019](ADR-019-units-handling.md)). No per-user identity to attach a preference to. Phase 6+ enhancement: localStorage override that re-formats client-side using `Intl.DateTimeFormat` — no server change.

## Options considered

| Option | Verdict |
|---|---|
| A. Station-local default; UTC on the wire; IANA TZ in StationMetadata (this ADR) | **Selected** — matches weewx-skin precedent and visitor intent. |
| B. Browser-local default | Rejected — surprises visitors who think they're seeing the station's clock. |
| C. UTC display | Rejected — readable for ops, hostile for everyone else. |

## Consequences

- StationMetadata response includes `timezone` (IANA string) and `timezoneOffsetMinutes` (current offset, useful for clients that don't ship full IANA TZ data).
- Phase 2 work: TZ derivation at first-run setup if operator and weewx config don't supply one (e.g., `timezonefinder` or a small lookup table).
- Daylight saving transitions handled by browser IANA TZ data; no server-side DST logic.
- NOAA-report rendering, Records-page year boundaries, Charts-page x-axes all use station TZ.
- Dashboard never calls `toLocaleString()` without an explicit `timeZone` option — always station TZ.

## Out of scope

- Per-user TZ override — Phase 6+.
- TZ lookup library choice — Phase 2.
- Stations that moved across zones (historical TZ change in the archive) — out of scope; v0.1 assumes a stable station TZ.

## References

- IANA TZ database: https://www.iana.org/time-zones
- `Intl.DateTimeFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat
- Related: [ADR-010](ADR-010-canonical-data-model.md), [ADR-019](ADR-019-units-handling.md), [ADR-021](ADR-021-i18n-strategy.md), [ADR-027](ADR-027-config-and-setup-wizard.md).
