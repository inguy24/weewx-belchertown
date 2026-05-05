---
status: Accepted
date: 2026-04-30
deciders: shane
---

# ADR-007: Forecast provider day-1 set

## Context

Clear Skies needs forecast, current-conditions, and (where available) alerts data from external providers. The current Belchertown skin pulls from Aeris; many other providers exist with different APIs, geographic coverage, and free-tier policies.

Phase 2 implementation needs a locked day-1 set of providers so the client-module work has clear scope. Per [ADR-006](ADR-006-compliance-model.md), end users register their own keys and manage their own compliance — our scope is technical: which providers' APIs are compatible with our architecture, and which client modules ship in the day-1 release.

Research artifacts: [docs/reference/FORECAST-PROVIDER-RESEARCH.md](../reference/FORECAST-PROVIDER-RESEARCH.md) and per-provider API docs at [docs/reference/api-docs/](../reference/api-docs/).

## Options considered

| Provider | Public API verified? | Free tier? | Coverage / data types | Verdict |
|---|---|---|---|---|
| Aeris (AerisWeather / Xweather) | Yes | Yes (developer trial) | Current, hourly, daily, alerts (US/CA/EU). Rich endpoint surface. | **Include.** Existing Belchertown integration; full data-type coverage. |
| NWS (National Weather Service) | Yes | Yes (no key required) | Current, hourly, daily, alerts. USA only. | **Include.** Free, government-run, reliable. USA-only is a known constraint, handled at the dashboard layer when the user is outside the US. |
| OpenMeteo | Yes | Yes (non-commercial use) | Current, hourly, daily. **No alerts endpoint.** Global. | **Include.** Best free-tier option for global coverage; no key required for free use. Lack of alerts handled at module level (module reports "alerts not provided"). |
| OpenWeatherMap | Yes | Yes (limited APIs) | Current via free tier; hourly/daily/alerts via One Call 3.0 (separate subscription). Global. | **Include.** Module supports both API tiers; user picks based on their subscription. |
| Weather Underground | Yes — PWS API only | Yes (PWS contributors only) | Current observations, daily forecast. **No hourly, no alerts.** PWS network. | **Include.** Module ships, but with explicit gating: requires user to have a registered PWS to obtain a key. Clear error at config time if no key. |
| Meteoblue | Yes | Yes, but extremely limited | — | **Exclude.** Free-tier API call limit was so restrictive that practical use required upgrading; other providers covering the same geography offer more generous free tiers. Eliminated 2026-04-29. |

## Decision

Day-1 client modules ship for **Aeris, NWS, OpenMeteo, OpenWeatherMap, and Weather Underground.** Meteoblue is not in the day-1 set.

Each module is independently enable/disable per the user's configuration. A user can run with any single provider, any combination, or all five. Per [ADR-006](ADR-006-compliance-model.md), missing or unconfigured keys disable that provider's pieces only — the rest of the service runs normally.

## Consequences

- Phase 2 scope includes five Python client modules, each implementing the same canonical interface (canonical data model defined by [ADR-010](INDEX.md), pinned).
- Geographic and feature limitations are per-provider, not project-wide:
  - NWS — USA only.
  - Aeris alerts — US, Canada, Europe only.
  - OpenMeteo — no alerts at all.
  - Weather Underground — no hourly forecast, no alerts; gated to PWS contributors.
- If no configured provider supplies a given data type (e.g., user has only OpenMeteo configured, which has no alerts endpoint), the dashboard simply hides that data type's panel. **No on-dashboard explanation, no "no provider configured" message — just absence.** Per [ADR-006](ADR-006-compliance-model.md), provider selection is the user's responsibility; the dashboard does not lecture them about it.
- Setup-time advisory only: install docs note that providers vary in geographic coverage and data types, and point users to the per-provider files at [docs/reference/api-docs/](../reference/api-docs/) if they want to verify coverage for their region/needs. The project does not maintain a "which provider covers what in which region" map — that information changes upstream and is not our responsibility to track.
- Maintenance burden: five modules to keep current as providers update their APIs. Mitigation: per-provider API docs are captured locally at [docs/reference/api-docs/](../reference/api-docs/) so updates can be diffed.
- Future providers can be added in Phase 6+ via a new ADR; the day-1 set is not a ceiling.

## Implementation guidance

### Module layout

Each provider gets its own Python module under the API package:

```
weewx_clearskies_api/providers/
  __init__.py
  aeris.py
  nws.py
  openmeteo.py
  openweathermap.py
  wunderground.py
```

Each module implements the same interface (defined when [ADR-010](INDEX.md) is drafted). Until ADR-010 exists, modules can use a temporary internal `_types.py`; the canonical model replaces it.

### Auth pattern per provider (see per-provider files for full detail)

| Provider | Auth pattern | Required env var(s) |
|---|---|---|
| Aeris | `client_id` + `client_secret` as query params | `AERIS_CLIENT_ID`, `AERIS_CLIENT_SECRET` |
| NWS | `User-Agent` header (mandatory); no key | `NWS_USER_AGENT` (e.g., `"clearskies (admin@example.com)"`) |
| OpenMeteo | None for free use; `apikey` query param + custom server URL for commercial | `OPENMETEO_APIKEY` (optional), `OPENMETEO_BASE_URL` (optional) |
| OpenWeatherMap | `appid` query param | `OPENWEATHERMAP_APPID` |
| Weather Underground | `apiKey` query param | `WUNDERGROUND_API_KEY`, `WUNDERGROUND_PWS_STATION_ID` |

### Per-module behavior

- **At startup:** if required env var(s) unset, module reports "disabled" and the rest of the service starts normally (per [ADR-006](ADR-006-compliance-model.md)).
- **NWS module:** USA-only check at config time; if user's configured location is outside the US, module reports "geography unsupported" and disables itself.
- **Wunderground module:** explicit error message at config time if `WUNDERGROUND_PWS_STATION_ID` is unset, pointing to the PWS registration requirement.
- **OpenMeteo module:** must report "alerts not provided" when alerts are queried; the rest of the data types work.
- **OpenWeatherMap module:** distinguishes basic-tier vs One Call 3.0 — if user's key only has basic-tier access, hourly/daily/alerts queries return "not available with this subscription."

### Out of scope for this ADR

- Caching strategy (deferred to ADR-017, pinned).
- Per-provider rate-limit handling specifics (each module implements its own backoff; cross-cutting policy is ADR-017).
- Severe-weather alert aggregation across providers (deferred to ADR-016, pinned).
- AQI handling (deferred to ADR-013, pinned).
- Which provider supplies which data type at runtime — that's user configuration, not an architecture decision.

## References

- Related ADRs: [ADR-006](ADR-006-compliance-model.md) (end-user-managed compliance), [ADR-010](INDEX.md) (canonical data model — pinned), [ADR-013](INDEX.md) (AQI — pinned), [ADR-016](INDEX.md) (alerts aggregation — pinned), [ADR-017](INDEX.md) (caching — pinned)
- Research: [docs/reference/FORECAST-PROVIDER-RESEARCH.md](../reference/FORECAST-PROVIDER-RESEARCH.md)
- Per-provider API docs: [docs/reference/api-docs/](../reference/api-docs/)
