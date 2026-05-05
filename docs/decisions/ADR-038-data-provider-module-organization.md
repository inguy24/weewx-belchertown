---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-038: Data-provider module organization

## Context

Clear Skies integrates with multiple external providers across forecast ([ADR-007](ADR-007-forecast-providers.md)), AQI ([ADR-013](ADR-013-aqi-handling.md)), severe-weather alerts ([ADR-016](ADR-016-severe-weather-alerts.md)), earthquakes ([ADR-024](ADR-024-page-taxonomy.md) cat 6), and radar ([ADR-015](ADR-015-radar-map-tiles-strategy.md)). This ADR locks the **structural pattern** every external-data integration follows so domain ADRs reference one contract instead of re-deriving it.

Two paths get data into canonical SPA variables ([ADR-010](ADR-010-canonical-data-model.md)): operator-mapped weewx archive columns ([ADR-035](ADR-035-user-driven-column-mapping.md)) and provider modules calling external APIs (this ADR). The two don't coordinate. AQI uses both in parallel.

## Options considered

| Option | Verdict |
|---|---|
| A. Shared abstract base class (`ProviderBase[T]`) for all providers | Rejected — per-domain canonical types differ enough that a single base class fights the contract. ABCs grow; future providers either fit or work around. |
| B. Documented pattern + shared internals in `providers/_common/`, per-domain types | **Selected.** Lighter than A; shared infrastructure stays small. |
| C. Third-party plugin ecosystem (Python entry-points, external authors publish plugins) | Rejected per locked user direction — outside contributors PR into the bundled set; we don't run a marketplace. |

## Decision

Provider modules follow a documented structural pattern with shared internal infrastructure. Five rules govern.

### 1. One module per provider

Each provider lives in a self-contained module (single file or directory) named after the provider. Adding a new provider = adding a new module; removing = deleting that module. Cross-provider concerns (HTTP wrapper, retry, capability registry) live in shared infrastructure within the same repo.

### 2. Five module responsibilities (the contract)

Every provider module is responsible for, and only for:

1. **Outbound API call** — provider URL, auth, query parameters, rate-limit handling. Module owns its own rate limiter (per-provider quotas).
2. **Response parsing** — interpret the provider's response format.
3. **Translation to canonical Clear Skies fields** per [ADR-010](ADR-010-canonical-data-model.md): unit conversion, scale normalization (e.g., EPA AQI), identifier normalization (`PM2.5`/`pm25`/`pm2_5` → canonical `PM2.5`), time format → ISO 8601 UTC `Z`.
4. **Capability declaration** — static, deterministic statement of which canonical fields the module supplies. Read at startup to populate the runtime capability registry.
5. **Error handling** — provider errors translated to the canonical taxonomy (rule 4).

Anything outside these five — caching, logging format, persistence, dashboard rendering — is owned by other ADRs.

### 3. Shared-vs-per-module split

Within clearskies-api:

- **Shared (`weewx_clearskies_api/providers/_common/`):** HTTP client wrapper (timeouts, TLS, dual-stack per [coding rules §1](../../rules/coding.md)), retry/backoff helper, canonical error class hierarchy, capability declaration data structure, capability registry plumbing, rate-limiter primitive.
- **Per-module:** provider URL/auth/parsing, translation to canonical, module's own rate limiter, domain-specific helpers (e.g., a provider-specific pollutant identifier table).
- **Domain-wide canonical helpers** (EPA AQI category lookup, Beaufort scale, US-NWS alert-code translation) live in the canonical-model package per [ADR-010](ADR-010-canonical-data-model.md), not in providers.

### 4. Capability declaration fields

Each module exports a static structure with these fields (Python representation is a Phase 2 choice):

- **`provider_id`** — stable string (`"aeris"`, `"openmeteo"`, `"usgs"`, …).
- **`domain`** — `"forecast"` | `"aqi"` | `"alerts"` | `"earthquakes"` | `"radar"`. One module = one domain. A multi-domain provider gets multiple modules.
- **`supplied_canonical_fields`** — enumerated list of canonical fields per [ADR-010](ADR-010-canonical-data-model.md) the module can supply.
- **`geographic_coverage`** — `"global"` or enumerated regions. Used by the configuration UI to warn at setup if operator's lat/lon is outside coverage.
- **`auth_required`** — operator-config keys the module needs (e.g., `["AERIS_CLIENT_ID", "AERIS_CLIENT_SECRET"]`).
- **`default_poll_interval_seconds`** — recommended cadence.
- **`operator_notes`** — free text surfaced in the configuration UI for provider-specific quirks.

The capability registry is the union of all configured-and-enabled modules' declarations.

### 5. Canonical error taxonomy

All provider modules raise from this set; no leaking of upstream provider error types:

- `QuotaExhausted` — rate-limit/daily-cap; transient, retry after backoff.
- `KeyInvalid` — auth-time failure; permanent until operator updates config.
- `GeographicallyUnsupported` — provider doesn't cover operator's location.
- `FieldUnsupported` — provider doesn't supply the requested data type.
- `TransientNetworkError` — DNS/TCP/TLS/5xx; retry with backoff.
- `ProviderProtocolError` — response format unexpected (provider changed API silently); requires module update; logged loudly.

### Internal contract; outside contributors PR into the bundled set

No Python entry-point discovery. No runtime loading of plugins from operator config. The module set is the bundled set. Outside contributors open a PR; we review for code quality, license compatibility ([ADR-003](ADR-003-license.md)), and provider terms-of-use ([ADR-006](ADR-006-compliance-model.md)); we merge or decline.

## Consequences

- **[ADR-007](ADR-007-forecast-providers.md)** retroactively conforms; its module layout is the canonical example.
- **[ADR-013](ADR-013-aqi-handling.md)** AQI providers conform — modules in `providers/aqi/`, no bundled weewx extension.
- **[ADR-015](ADR-015-radar-map-tiles-strategy.md)** radar modules conform; capability declaration adds a `tile_format` field for the radar domain.
- **[ADR-016](ADR-016-severe-weather-alerts.md)** alert modules conform.
- **[ADR-024](ADR-024-page-taxonomy.md) cat 6 earthquake providers** (USGS / GeoNet / ReNaSS / EMSC) ship as four conforming modules in Phase 2.
- **Capability registry has a runtime API surface.** The dashboard asks "what does my configured forecast provider supply?"; the configuration UI asks "what providers cover X for my region?". Endpoint shape is part of the OpenAPI contract per [ADR-018](ADR-018-api-versioning-policy.md).
- **Phase 2 task:** the shared-infrastructure sub-package (HTTP wrapper, retry, error taxonomy, capability registry plumbing) is real code, not duplicated per provider.
- **Documentation gate** in `clearskies-api/DEVELOPMENT.md`: "How to add a new provider module" walkthrough with sample reference.

## Implementation guidance

### Module file layout

```
weewx_clearskies_api/providers/
├── _common/         # http, retry, errors, capability, ratelimit
├── forecast/        # ADR-007 modules
├── aqi/             # ADR-013 modules
├── alerts/          # ADR-016 modules
├── earthquakes/     # ADR-024 cat 6 modules
└── radar/           # ADR-015 modules
```

Each provider module exports a stable `CAPABILITY` symbol and a stable `fetch` callable (or callable set) per domain. The exact callable signature per domain is locked by the relevant domain ADR.

### Capability registry consumption

In-process within clearskies-api: `REGISTRY.providers_for_domain(...)`, `providers_supplying_field(...)`, `providers_covering_location(lat, lon)`. Exposed via API endpoint for dashboard / configuration UI consumption.

### Capability declaration is static at module-load time

Provider coverage changes ship in module updates and operator upgrades — no runtime introspection. Acceptable; coverage changes slowly.

### Provider-versioning when upstream API changes

Default: stay within the existing module — `fetch` selects API version based on operator config; `CAPABILITY` may differ across versions. Split into a new module only when version-branching dominates the code OR the new version is effectively a different product (separate auth, separate billing).

### Testing pattern

- **Recorded fixture** of a known-good provider response under `tests/fixtures/providers/{provider}/`.
- **Parser unit tests** load the fixture and assert canonical-translation correctness (units, identifiers, scales, time formats).
- **Mock-network tests** (`respx` or equivalent) for the API call: verifies auth, rate-limit handling, error-taxonomy mapping (`429` → `QuotaExhausted`, `401`/`403` → `KeyInvalid`).
- **NO live-network tests in CI.** Live-API testing is a developer-local workflow.

## Out of scope

- Specific Python interface (ABC vs Protocol vs duck-typed) — Phase 2.
- HTTP client library (`httpx`/`requests`/`aiohttp`) — Phase 2.
- Capability-registry HTTP endpoint shape — OpenAPI contract per [ADR-018](ADR-018-api-versioning-policy.md).
- Caching of provider responses — [ADR-017](ADR-017-provider-response-caching.md).
- Logging from provider modules — [ADR-029](ADR-029-logging-format-destinations.md).

## References

- Related: [ADR-003](ADR-003-license.md), [ADR-006](ADR-006-compliance-model.md), [ADR-007](ADR-007-forecast-providers.md), [ADR-010](ADR-010-canonical-data-model.md), [ADR-013](ADR-013-aqi-handling.md), [ADR-015](ADR-015-radar-map-tiles-strategy.md), [ADR-016](ADR-016-severe-weather-alerts.md), [ADR-017](ADR-017-provider-response-caching.md), [ADR-018](ADR-018-api-versioning-policy.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-029](ADR-029-logging-format-destinations.md), [ADR-035](ADR-035-user-driven-column-mapping.md).
- Walk: [CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md) cat 8.
- Coding rules: [coding.md §1](../../rules/coding.md) (IPv4/IPv6-agnostic — applies to provider HTTP).
