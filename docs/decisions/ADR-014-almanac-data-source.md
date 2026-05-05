---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-014: Almanac data source

## Context

The Almanac page and the Sun & Moon tile on the Now page ([ADR-024](ADR-024-page-taxonomy.md)) need ephemeris data: rise / transit / set, civil twilight, azimuth / altitude / RA / declination, moon phase + fullness, equinox / solstice / new-moon / full-moon dates. Phase 6+ candidates on the same page (planets, eclipses, meteor showers, conjunctions) need the same library.

Belchertown computes this with `pyephem`, which is unmaintained.

## Decision

Use **`skyfield`** (https://rhodesmill.org/skyfield/) for all almanac calculations.

- Actively maintained, MIT-licensed, pure Python.
- NASA JPL ephemerides (DE421 default).
- Drop-in replacement for `pyephem` use cases.
- Supports planets, eclipses, satellite passes — Phase 6+ content needs no library swap.

Calculations run **server-side in clearskies-api**: stateless given (lat, lon, time); sub-millisecond after the first ephemeris load.

## Options considered

| Option | Verdict |
|---|---|
| A. `skyfield` (this ADR) | **Selected.** |
| B. `pyephem` (Belchertown's current choice) | Rejected — unmaintained; upstream points users at `skyfield`. |
| C. External almanac API (e.g., USNO) | Rejected — adds a network dependency for math we can do locally. |

## Consequences

- clearskies-api adds `skyfield` to its Python dependencies and bundles/downloads the DE421 ephemeris (~17 MB) on first run.
- Almanac computations are stateless and local — no caching beyond the in-memory ephemeris.
- Phase 6+ Almanac additions don't require a library swap.

## Out of scope

- Almanac page card layout — [ADR-024](ADR-024-page-taxonomy.md) lists default cards; visual design is Phase 3.
- Twilight definition default (civil vs nautical vs astronomical) — Phase 2; default = civil per cat 5.
- Where the ephemeris file is bundled (Python package data vs first-run download) — Phase 2.

## References

- Skyfield: https://rhodesmill.org/skyfield/
- Walk artifact: cat 5 in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Related: [ADR-024](ADR-024-page-taxonomy.md).
