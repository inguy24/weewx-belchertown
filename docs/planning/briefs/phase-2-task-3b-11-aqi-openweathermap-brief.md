# Phase 2 task 3b round 11 — /aqi/openweathermap

**Round identity.** Third AQI provider per [ADR-013](../../decisions/ADR-013-aqi-handling.md). Adds `providers/aqi/openweathermap.py` plus EPA-breakpoint per-pollutant tables to `providers/aqi/_units.py` (NEW shared infrastructure — the last meaningful AQI common-helper addition). Reuses 3b-5/3b-8 OWM auth plumbing (`WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID` env var on `ForecastSettings`). FREE-tier endpoint (`/data/2.5/air_pollution`) — no basic-tier-401 graceful-empty pattern needed (distinct from 3b-5 forecast/owm and 3b-8 alerts/owm both of which use paid endpoints).

**Pre-brief verifications (3b-10 lessons applied):**
- Cross-check rule (4-time-validated): canonical §4.2 OWM column **matches** the OWM Air Pollution wire shape exactly. No Q-amend. `docs/reference/api-docs/openweathermap.md` extended in lead-direct commit (pre-brief) with `### Air Pollution` section sourced from https://openweathermap.org/api/air-pollution.
- Codebase-state verification (NEW 3b-10 rule): every cited path opened and verified —
  - Credential source: `settings.forecast.openweathermap_appid` (env var `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID`) at [`config/settings.py:457`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py#L457). Confirmed.
  - `AQISettings.validate` at [`config/settings.py:405`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py#L405) currently accepts `{"openmeteo", "aeris"}` — must extend with `"openweathermap"`.
  - `_units.py` currently contains `ugm3_to_ppm`, `ppb_to_ppm`, `epa_category`, `_EPA_CATEGORY_BANDS`, `_MOLECULAR_WEIGHTS_G_PER_MOL`. **NO concentration→sub-AQI tables.** This round adds them.
  - `endpoints/aqi.py` `wire_aqi_settings` (lines 109–157) has explicit "When 3b-11 lands OWM AQI: add elif provider == 'openweathermap': branch" comment at L156. Dispatch in `get_aqi_current` (lines 220–246) similarly has the `openmeteo`/`aeris` pattern — add a third `elif provider_id == "openweathermap"` branch.
  - `providers/_common/dispatch.py` `PROVIDER_MODULES` (line 31) needs `("aqi", "openweathermap"): aqi_openweathermap` row + import.
  - `__main__.py` `_wire_providers_from_config` line 251 needs valid-providers list update from `"openmeteo, aeris"` to `"openmeteo, aeris, openweathermap"` (CRITICAL log on unknown provider id).
  - Helpers to reuse: `epa_category` (existing), `ugm3_to_ppm` (existing — used for canonical storage of gas pollutants in ppm). `ppb_to_ppm` (existing) — NOT used here (OWM returns µg/m³ for all pollutants, no PPB).

---

## Scope (in / out)

**In scope (this round):**
1. `weewx_clearskies_api/providers/aqi/openweathermap.py` — NEW module (~500 lines).
2. `weewx_clearskies_api/providers/aqi/_units.py` — extend with EPA breakpoint per-pollutant tables + `concentration_to_sub_aqi(concentration, pollutant)` piecewise-linear helper (~80–120 new lines).
3. `weewx_clearskies_api/providers/_common/dispatch.py` — add `("aqi", "openweathermap")` import + row.
4. `weewx_clearskies_api/config/settings.py` — `AQISettings.validate` accept `"openweathermap"`.
5. `weewx_clearskies_api/endpoints/aqi.py` — add module-level `_OWM_APPID` + extend `wire_aqi_settings` + extend `get_aqi_current` dispatch.
6. `weewx_clearskies_api/__main__.py` line 251 CRITICAL log valid-providers list update.
7. Tests covering all of the above (see §Coverage shape).

**Out of scope:**
- `/aqi/history` — still 501 stub per LC21 (3b-9 / 3b-10 carry-forward).
- IQAir AQI — 3b-12.
- AQI persistence to a writable datastore — deferred per ADR-013 §Out of scope.
- OWM Air Pollution **forecast** / **history** sub-endpoints — `/data/2.5/air_pollution/forecast` (4-day hourly) and `/data/2.5/air_pollution/history` (since 2020-11-27) are NOT in scope; v0.1 only consumes the current-snapshot endpoint.

---

## Reading list (in order)

1. [CLAUDE.md](../../../CLAUDE.md) — domain routing + always-applicable rules.
2. [rules/clearskies-process.md](../../../rules/clearskies-process.md) — full file. Carry-forwards relevant this round: cross-check rule (4× validated) + NEW codebase-state-verification bullet (applied above); brief-questions-audit-themselves; L1 paid-tier-max-surface + PARTIAL-DOMAIN extension; "Lead-direct remediation when surface is small"; "Live scratchpad during multi-agent rounds"; "Poll background teammates at every user-prompt boundary"; "Multi-line commit messages on PowerShell: use `git commit -F`"; "Round briefs land in the project, not in tmp."
3. [rules/coding.md](../../../rules/coding.md) — §3 carry-forwards: dispatch on exception state via attributes (not message strings); DRY — search before writing a new helper; No dead code.
4. [.claude/agents/clearskies-api-dev.md](../../../.claude/agents/clearskies-api-dev.md) — L2 carry-forward (3b-4): don't re-construct canonical exceptions; bare `client.get()`. Any narrow wrap MUST be intentional and documented in commit body.
5. [.claude/agents/clearskies-test-author.md](../../../.claude/agents/clearskies-test-author.md) — L3 carry-forward: synthetic-from-real fixture pattern when paid-tier access unavailable. **NOT expected to fire this round** — OWM Air Pollution is FREE tier, real-capture should succeed with operator's existing OWM appid.
6. [.claude/agents/clearskies-auditor.md](../../../.claude/agents/clearskies-auditor.md) — agent definition.
7. [docs/contracts/canonical-data-model.md](../../contracts/canonical-data-model.md) §3.8 (`AQIReading`) + §4.2 (provider mapping, OWM column at row 504 — cross-check already passed).
8. [docs/contracts/openapi-v1.yaml](../../contracts/openapi-v1.yaml) — `/aqi/current` + `/aqi/history` endpoint shapes (already wired in 3b-9 / 3b-10).
9. [docs/reference/api-docs/openweathermap.md](../../reference/api-docs/openweathermap.md) — newly-extended `### Air Pollution` section (lead-direct commit pre-brief). Wire example response, 1–5 OWM ordinal scale + per-pollutant µg/m³ breakpoints, gotchas list.
10. [docs/decisions/ADR-013-aqi-handling.md](../../decisions/ADR-013-aqi-handling.md) — AQI provider plug-in pattern (this round adds the third of four day-1 providers).
11. [docs/decisions/ADR-038-data-provider-module-organization.md](../../decisions/ADR-038-data-provider-module-organization.md) — module 5-responsibility pattern.
12. **Precedent modules** (read all three, in this order):
    - [`providers/aqi/aeris.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/aqi/aeris.py) — closest precedent (keyed AQI, query-param auth, full max-surface CAPABILITY, derives aqiCategory client-side via `epa_category(aqi)`).
    - [`providers/aqi/openmeteo.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/aqi/openmeteo.py) — keyless precedent. Read for `_main_pollutant_from_sub_aqis()` argmax pattern (deterministic table-order tie-break) and the µg/m³→ppm conversion path for gases.
    - [`providers/forecast/openweathermap.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/forecast/openweathermap.py) — OWM auth plumbing reference (env var, query-param `appid`, ProviderHTTPClient usage). **Do NOT reuse the One-Call-401 graceful-empty-bundle pattern from this module** — it's specific to the paid `/data/3.0/onecall` endpoint; OWM's Air Pollution endpoint is on the free tier.

---

## Module spec — `providers/aqi/openweathermap.py`

### Five responsibilities (per ADR-038 §2)

1. **Outbound API call** — single GET per cache miss:
   ```
   GET https://api.openweathermap.org/data/2.5/air_pollution
       ?lat={lat}&lon={lon}&appid={appid}
   ```
   No `units=` or `lang=` params (response is always µg/m³ + OWM 1–5 ordinal).

2. **Response parsing** — wire-shape Pydantic models with `extra="ignore"`:
   - `_OWMAirPollutionComponents` — `co / no / no2 / o3 / so2 / pm2_5 / pm10 / nh3` all `float | None = None`.
   - `_OWMAirPollutionMain` — `aqi: int | None = None` (1–5 OWM ordinal; we ignore this field — see LC4).
   - `_OWMAirPollutionEntry` — `dt: int`, `main: _OWMAirPollutionMain`, `components: _OWMAirPollutionComponents`.
   - `_OWMAirPollutionResponse` — `list: list[_OWMAirPollutionEntry] = []`. (Note: shadows the Python builtin `list`; alias via Pydantic Field(...) — see LC11.)

3. **Translation to canonical `AQIReading`** (`_wire_to_canonical(entry)`):
   - `pollutantPM25` = `components.pm2_5` (passthrough, µg/m³ — group_concentration).
   - `pollutantPM10` = `components.pm10` (passthrough, µg/m³ — group_concentration).
   - `pollutantO3` = `ugm3_to_ppm(components.o3, pollutant="O3")` (group_fraction, ppm).
   - `pollutantNO2` = `ugm3_to_ppm(components.no2, pollutant="NO2")` (group_fraction, ppm).
   - `pollutantSO2` = `ugm3_to_ppm(components.so2, pollutant="SO2")` (group_fraction, ppm).
   - `pollutantCO` = `ugm3_to_ppm(components.co, pollutant="CO")` (group_fraction, ppm).
   - `aqi` = `_compute_owm_aqi_max(components)` — max EPA sub-AQI across 6 pollutants via `_units.concentration_to_sub_aqi()`. Capped at 500.
   - `aqiCategory` = `epa_category(aqi)` — derived from computed AQI (single source of truth shared with Aeris + Open-Meteo).
   - `aqiMainPollutant` = pollutant with highest sub-AQI (argmax pattern from openmeteo.py — deterministic table-order tie-break: `PM2.5 > PM10 > O3 > NO2 > SO2 > CO`).
   - `aqiLocation` = `None` (PARTIAL-DOMAIN — no location field on wire; canonical §4.2 OWM column shows `—`; see L1 application below).
   - `observedAt` = `epoch_to_utc_iso8601(entry.dt)` from `providers/_common/datetime_utils.py` (DRY — already used by forecast/openweathermap.py).
   - `source` = `"openweathermap"`.
   - **Drop NH3 and NO unconditionally** — present on wire, not in EPA AQI methodology, not on canonical AQIReading (mirrors aeris.py dropping pm1).

4. **Capability declaration** — `CAPABILITY` symbol consumed at startup. Full max-surface MINUS `aqiLocation` (the only categorical PARTIAL-DOMAIN for this provider — no location field at ANY tier):
   ```python
   supplied_canonical_fields=(
       "aqi", "aqiCategory", "aqiMainPollutant",
       "pollutantPM25", "pollutantPM10",
       "pollutantO3", "pollutantNO2", "pollutantSO2", "pollutantCO",
       "observedAt", "source",
       # aqiLocation EXCLUDED — PARTIAL-DOMAIN (no location field on wire)
   )
   auth_required=("appid",)
   geographic_coverage="global"
   default_poll_interval_seconds=DEFAULT_AQI_TTL_SECONDS  # 900
   ```

5. **Error handling** — `ProviderHTTPClient.get()` raises canonical taxonomy with all attributes set (L2 carry-forward, 3b-4 audit F1). NO re-construction of canonical exceptions. The ONLY narrow wrap in this module is `(ValidationError, ValueError)` → `ProviderProtocolError` at the wire-validation boundary (this IS adding context the inner layer didn't have — wire-shape validation is a higher-level error class). **No LC27 envelope mapping** — OWM Air Pollution returns errors via HTTP status codes (401/429/5xx), not via a 200-success-false envelope (distinct from Aeris).

### Cache layer (ADR-017)

- **TTL:** 900 s (15 min) — same as openmeteo.py + aeris.py (canonical AQI TTL).
- **Key:** SHA-256 of `{"provider_id": "openweathermap", "endpoint": "aqi_current", "params": {"lat4": round(lat,4), "lon4": round(lon,4)}}`. NO `appid` in key per LC7 (privacy/leakage concern — same as aeris.py).
- **Value:** `AQIReading.model_dump()` dict (JSON-serializable for Redis backend).
- **Sentinel:** `{"_no_reading": True}` when wire response has empty `list[]` or all-null `components`.
- **Reconstruction on hit:** `AQIReading.model_validate(cached_dict)`.

### Rate limiter (LC8)

`max_calls=5, window_seconds=1` ("be polite" guard — same shape as openmeteo + aeris). 15-min TTL → ~96 calls/day well below the documented free-tier 60 calls/min (1,000,000 calls/month) cap.

### Fetch entrypoint signature

```python
def fetch(
    *,
    lat: float,
    lon: float,
    appid: str,
    http_client: ProviderHTTPClient | None = None,
) -> AQIReading | None:
```

- `appid` required (str, NOT `str | None`). Empty / None → raise `KeyInvalid(provider_id="openweathermap", domain="aqi", ...)` BEFORE outbound call — matches the explicit-fail-fast pattern from forecast/openweathermap.py L818–822.
- Cache-first; on miss → rate-limit → `client.get(OWM_AIRPOL_BASE_URL + OWM_AIRPOL_PATH, params={"lat": ..., "lon": ..., "appid": ...})`.
- Returns canonical `AQIReading` or `None` (no useful reading at this location).

---

## `_units.py` extension — EPA breakpoint per-pollutant tables

### New code surface (~80–120 lines)

Add a **single module-level constant** `_EPA_BREAKPOINTS` mapping canonical pollutant id → list of `(c_low, c_high, i_low, i_high)` tuples. Concentrations expressed in the **same units the canonical AQIReading uses for that field**:

| Pollutant | Unit (canonical) | Source EPA table             | Notes                                                  |
|-----------|------------------|-------------------------------|--------------------------------------------------------|
| PM2.5     | µg/m³            | 24-hr avg PM2.5 (post-2024)   | Use 2024 revised breakpoints: 9.0 / 35.4 / 55.4 / etc. |
| PM10      | µg/m³            | 24-hr avg PM10                | Standard 54 / 154 / 254 / 354 / 424 / 604.             |
| O3        | ppm              | **8-hr O3** (NOT 1-hr — see Q1) | 0.054 / 0.070 / 0.085 / 0.105 / 0.200; cap at 300.    |
| CO        | ppm              | 8-hr CO                       | 4.4 / 9.4 / 12.4 / 15.4 / 30.4 / 50.4.                 |
| SO2       | ppm              | **1-hr SO2** (NOT 24-hr — see Q1) | 0.035 / 0.075 / 0.185 / 0.304; cap at 200.         |
| NO2       | ppm              | 1-hr NO2                      | 0.053 / 0.100 / 0.360 / 0.649 / 1.249 / 2.049.         |

Add a single helper `concentration_to_sub_aqi(concentration: float | None, *, pollutant: str) -> int | None`:

```python
def concentration_to_sub_aqi(
    concentration: float | None,
    *,
    pollutant: str,
) -> int | None:
    """Compute EPA sub-AQI from a pollutant concentration via piecewise-linear interpolation.

    Returns:
        Integer 0–500 sub-AQI for the pollutant, or None when concentration is None.
        Above the table's top breakpoint, returns the table-top index (cap behavior;
        Q1 user decision 2026-05-10 — see brief for averaging-period operationalization).
        Below the table's bottom breakpoint (0), returns 0.

    Raises:
        KeyError: pollutant not in _EPA_BREAKPOINTS (canonical id required).
    """
```

Piecewise-linear interpolation formula (EPA Technical Assistance Document):
```
sub_aqi = round( ((I_high - I_low) / (C_high - C_low)) * (C - C_low) + I_low )
```

Cap behavior: values above the table's top `c_high` return the table-top `i_high` (300 for O3, 200 for SO2; 500 for PM2.5/PM10/CO/NO2 which have a full 0–500 EPA table). This is the conservative honest answer for OWM's instantaneous snapshots — see Q1 below for rationale.

### Coverage extension on `tests/providers/aqi/test_units.py` (~150–200 new lines)

- One parametrized test per pollutant covering: bottom of each band (boundary in), top of each band (boundary in), midpoint of each band, value above top breakpoint (cap), value below 0 (defensive — returns 0 or None), `None` input (returns None).
- One test per pollutant where the input lands exactly on a band-boundary (e.g. PM2.5 = 9.0 µg/m³ exactly = sub-AQI 50, NOT 51). EPA's spec is inclusive at the lower bound, exclusive at the upper bound for sub-AQI computation — but the standard formula uses BP_low and BP_high inclusive on both ends (the rounding then handles tie cases). Verify the chosen impl handles the boundary exactly (sub-AQI 50 not 51 for PM2.5 = 9.0).
- Coverage for the table-cap path on O3 (≥0.200 ppm → sub-AQI 300) and SO2 (≥0.305 ppm → sub-AQI 200).
- `KeyError` test: unknown pollutant id raises.

---

## Endpoint + wiring extensions

### `endpoints/aqi.py`

**Add module-level OWM appid storage** (mirrors `_AERIS_CLIENT_ID` / `_AERIS_CLIENT_SECRET`):
```python
_OWM_APPID: str | None = None
```

**Extend `wire_aqi_settings`** with an `elif provider == "openweathermap":` branch:
- Read `settings.forecast.openweathermap_appid` (same source the forecast / alerts OWM modules use — provider-scoped, NOT a separate `[aqi]` env var per the 3b-5 Q2 user decision).
- Store in `_OWM_APPID`.
- If absent, log ERROR same shape as the Aeris credentials-missing branch ("capability still registered but /aqi/current will return 502 until wired").

**Extend `get_aqi_current` dispatch** with an `elif provider_id == "openweathermap":` branch:
- Validate `_OWM_APPID` not None / empty; if missing → `HTTPException(status_code=502, detail="OpenWeatherMap appid missing")`.
- Call `openweathermap.fetch(lat=station.latitude, lon=station.longitude, appid=_OWM_APPID)`.

### `providers/_common/dispatch.py`

- Add `from weewx_clearskies_api.providers.aqi import openweathermap as aqi_openweathermap` import.
- Add `("aqi", "openweathermap"): aqi_openweathermap,` row to `PROVIDER_MODULES` (alphabetical-by-key within the `aqi` group).

### `config/settings.py`

- Extend `AQISettings.validate` at line 405: add `"openweathermap"` to `valid_providers = {"openmeteo", "aeris", "openweathermap"}`.
- Update the error message accordingly: `"Supported values: 'openmeteo', 'aeris', 'openweathermap'. Additional providers (iqair) land in 3b-12."`.

### `__main__.py`

- Line 251 CRITICAL log message: change `"Supported values: openmeteo, aeris."` to `"Supported values: openmeteo, aeris, openweathermap."`.

---

## Lead-resolved calls (LCs) — informational, no user sign-off needed

| # | Call | Resolution |
|---|------|------------|
| LC1  | Endpoint URL + path | `https://api.openweathermap.org/data/2.5/air_pollution` — FREE tier, no subscription gate. Confirmed in api-docs cross-check. |
| LC2  | Wire shape envelope | `{ coord, list[ { dt, main: { aqi }, components: {...} } ] }`. Read `list[0]`. Empty `list[]` → return None + cache sentinel. |
| LC3  | Cache TTL | 900 s (15 min) — same as openmeteo + aeris (canonical AQI TTL per ADR-017). |
| LC4  | OWM `main.aqi` (1–5) field | **IGNORED.** Canonical aqi is EPA 0–500; we derive it from concentrations via EPA breakpoints. Pydantic model declares `aqi: int | None = None` so wire validates, but the field is not read in translation. (Document in module docstring + commit body — operators expecting `main.aqi` to flow through need to understand why we don't.) |
| LC5  | Wire-shape model strictness | `extra="ignore"` on all four models per LC5 carry-forward. `coord` field on the response is present but not consumed (we already have lat/lon from `StationInfo`). |
| LC6  | Cache layer reuse | `get_cache()` from `providers/_common/cache.py` — same shape as openmeteo + aeris. Value = `AQIReading.model_dump()` dict. Sentinel = `{"_no_reading": True}`. |
| LC7  | Cache key composition | SHA-256 of `(provider_id="openweathermap", endpoint="aqi_current", {lat4, lon4})`. `appid` NOT in key (privacy/leakage; same shape as aeris.py). |
| LC8  | Rate limiter | `RateLimiter(name="openweathermap-aqi", max_calls=5, window_seconds=1)` — same shape as openmeteo + aeris. |
| LC9  | HTTP client singleton | Module-level `_http_client: ProviderHTTPClient \| None` + `_client_for()`. User-Agent = `f"weewx-clearskies-api/{_API_VERSION}"`. Same shape as openmeteo + aeris. |
| LC10 | Error handling | Bare `client.get()` per L2; ProviderHTTPClient raises canonical taxonomy with all attributes set. Only narrow wrap is `(ValidationError, ValueError) → ProviderProtocolError` at the wire-validation boundary. |
| LC11 | Pydantic field shadows builtin | `_OWMAirPollutionResponse.list` shadows Python's `list` builtin. Use `Field(default_factory=list)` and `model_config = ConfigDict(extra="ignore")`. Mypy/ruff are fine with this; verify no `# noqa` needed. |
| LC12 | `aqiLocation` | PARTIAL-DOMAIN — no location field on wire. Canonical field stays `None`. NOT in `CAPABILITY.supplied_canonical_fields`. |
| LC13 | `aqiCategory` derivation | Derived client-side via `epa_category(aqi)`. Single source of truth shared with aeris.py + openmeteo.py. No client-side OWM-1-5 → EPA mapping. |
| LC14 | `aqiMainPollutant` derivation | argmax over the 6 EPA-AQI pollutants by their EPA sub-AQI value. Deterministic table-order tie-break: PM2.5 wins over PM10, over O3, etc. (mirrors openmeteo.py `_SUB_AQI_TO_POLLUTANT` table order). |
| LC15 | Gas conversion | `ugm3_to_ppm` for canonical storage (group_fraction = ppm). NOT `ppb_to_ppm` — OWM returns µg/m³, not PPB. The same converted-to-ppm value also feeds `concentration_to_sub_aqi` for the EPA sub-AQI lookup (SO2/NO2 breakpoint tables also expressed in ppm; conversion happens once). |
| LC16 | Drop NH3 + NO | Present on wire, no EPA AQI band, not on canonical AQIReading — silently dropped during translation. Mirrors aeris.py dropping `pm1`. |
| LC17 | `observedAt` | `epoch_to_utc_iso8601(entry.dt)` — `entry.dt` is Unix UTC seconds. Use the shared helper from `providers/_common/datetime_utils.py` (DRY — already used by forecast/openweathermap.py). |
| LC18 | Credential source | `settings.forecast.openweathermap_appid` (env var `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID`) — same env var the forecast + alerts OWM modules consume per 3b-5 Q2 user decision (provider-scoped, NOT domain-scoped). Confirmed in settings.py at L457. |
| LC19 | Module-level credential storage | `_OWM_APPID: str \| None = None` in `endpoints/aqi.py`. Wired by `wire_aqi_settings` at startup. Dispatch reads at request time. Same shape as `_AERIS_CLIENT_ID` / `_AERIS_CLIENT_SECRET`. |
| LC20 | No basic-tier-401 graceful-empty | Distinct from forecast/owm + alerts/owm. OWM Air Pollution is FREE tier — a basic-tier appid works. No narrow try/except for 401-graceful-empty in this module. A 401 from this endpoint means the appid is genuinely invalid (operator misconfiguration); let `KeyInvalid` propagate per L2. |
| LC21 | `/aqi/history` | Still 501 per 3b-9 / 3b-10 — no change in this round. |
| LC22 | URL composition | `client.get(OWM_AIRPOL_BASE_URL + OWM_AIRPOL_PATH, params={"lat": ..., "lon": ..., "appid": ...})`. Lat/lon rounded to 6 decimal places (precision limit). `appid` in params dict (avoids logging at INFO if URL is logged — credentials stay in the params dict per security baseline). |
| LC23 | Empty-result guard | If `wire.list` is empty OR `_compute_owm_aqi_max(components)` returns None AND all pollutant fields are None → return None + cache sentinel. Mirrors aeris.py L482–488 + L611–628 patterns. |
| LC24 | CAPABILITY operator_notes | One-paragraph summary: FREE-tier endpoint; OWM 1–5 main.aqi field IGNORED, EPA 0–500 derived from concentrations via EPA breakpoints; aqiLocation PARTIAL-DOMAIN; NH3/NO dropped; averaging-period limitation documented (Q1). |
| LC25 | Lat/lon decimal precision in URL | 6 decimal places matches aeris.py L572–573 + openmeteo.py L408–409. ~10 cm precision; well below the cache-key 4-decimal-place dimension. |
| LC26 | All-null guard granularity | `has_data` check: any of (computed aqi non-None) OR (any pollutant value non-None). If false → return None + cache sentinel. (Matches openmeteo.py L302–312 pattern.) |
| LC27 | No envelope error dispatch | OWM Air Pollution uses HTTP status codes (401 / 429 / 5xx) — NOT a 200-success-false envelope. ProviderHTTPClient handles these directly. **Distinct from Aeris** (3b-10) which DID need an envelope dispatcher. |

---

## Numbered open questions for user sign-off

### Q1 — EPA breakpoint averaging-period operationalization (USER DECIDED 2026-05-10: Option A)

OWM Air Pollution returns a single instantaneous snapshot per pollutant. EPA's AQI breakpoint tables are defined for specific averaging periods that vary per pollutant:

| Pollutant | EPA averaging period | Range covered by that table |
|-----------|----------------------|------------------------------|
| PM2.5     | 24-hr avg            | 0–500 (full range)           |
| PM10      | 24-hr avg            | 0–500 (full range)           |
| O3        | 8-hr avg             | 0–300 only                   |
| O3        | 1-hr avg             | 100–500 (overlaps with 8-hr at index 100–300; EPA uses the higher) |
| CO        | 8-hr avg             | 0–500 (full range)           |
| SO2       | 1-hr avg             | 0–200 only                   |
| SO2       | 24-hr avg            | 201–500                      |
| NO2       | 1-hr avg             | 0–500 (full range)           |

**USER DECISION 2026-05-10: Option A — use the lower-averaging-period table only for each pollutant, with table-top cap behavior:**
- **O3** — use 8-hr table only; cap at sub-AQI 300 above 0.200 ppm.
- **SO2** — use 1-hr table only; cap at sub-AQI 200 above 0.304 ppm.
- Document the cap as a known limitation in commit body + module operator_notes + api-docs §Gotchas.

Rationale: honest about the cap; matches the conservative posture other AQI services (AirNow, IQAir, AccuWeather) take for unspecified-averaging-period inputs. OWM's snapshot doesn't actually distinguish 1-hr vs 8-hr vs 24-hr averages, so applying upper-table breakpoints would manufacture precision the wire shape can't support.

(Lead picked the EPA breakpoint values themselves per the standard EPA Technical Assistance Document; user picked the averaging-period table for the two pollutants where EPA publishes both. Options B/C considered and rejected in brief draft — left out of locked spec.)

---

## Risks / risk register (acknowledge at brief-read; mitigations baked in)

| Risk | Mitigation in this brief |
|------|---------------------------|
| EPA breakpoint table mistakes (off-by-one band boundaries, transcription errors from EPA TAD). | Test-author asserts every band boundary explicitly per pollutant; PR includes the EPA TAD URL in commit body. Reviewer verifies tables against EPA's PDF before approval. |
| Pydantic `list` field name shadows Python builtin. | LC11. Use `Field(default_factory=list)` for the default; no `# noqa` should be needed (verified pattern). |
| Operator with OWM as forecast OR alerts AND AQI all set → shared `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID`. | LC18 — provider-scoped per 3b-5 Q2 user decision. Same env var; one appid works for all three domains. Documented in wire_aqi_settings + module docstring. |
| Future iqair (3b-12) is the FIRST header-auth keyed provider. This round does NOT extend `redaction_filter.py`. | OWM uses query-param `appid` — same redaction pattern as 3b-5 forecast/owm + 3b-8 alerts/owm. No `redaction_filter.py` change in this round. |
| Real-capture fixture may catch breakpoint-table or argmax-tie-break behavior the synthetic tests missed. | Test-author runs real-capture against `lat=47.6062 lon=-122.3321` (Seattle — same as 3b-9 / 3b-10 fixture coords) with operator's existing OWM appid. Free-tier endpoint, no L3 fallback expected. |
| OWM `coord` field is an ARRAY `[lat, lon]` not an object `{lat, lon}` — wire-shape divergence vs forecast/owm's `lat`+`lon` scalar fields. | LC5 — `extra="ignore"` swallows the unread `coord` field. Wire model doesn't declare it; no validation hazard. |

---

## Test coverage shape

**File budget (rough):**

| File | Type | New lines | Notes |
|------|------|-----------|-------|
| `tests/providers/aqi/test_openweathermap.py` | NEW unit | ~700–900 | Module unit tests; mirror `test_openmeteo.py` + `test_aeris.py` shape. Includes `respx` mocking, real-fixture replay, all error paths (KeyInvalid via missing appid, KeyInvalid via 401, QuotaExhausted via 429, ProviderProtocolError via validation failure, TransientNetworkError via 5xx-after-retries), all-null reading, empty `list[]`, cache hit + miss, cache sentinel reconstruction. |
| `tests/providers/aqi/test_units.py` | EXTEND | ~150–200 | EPA breakpoint table coverage per pollutant: every band boundary in / out, table-top cap, below-zero defensive, None input, unknown-pollutant KeyError. |
| `tests/test_providers_aqi_endpoint.py` | EXTEND | ~80–130 | OWM dispatch branch in `/aqi/current`: provider=openweathermap + valid appid → fetch called with correct args; missing `_OWM_APPID` → 502; ProviderHTTPClient errors propagate per the existing decision tree. |
| `tests/test_providers_aqi_openweathermap_integration.py` | NEW integration | ~400–500 | Real-capture replay against MariaDB + Redis backends (when `MARIADB_RO_PASSWORD` set). Skip-mark when paid env var absent. Mirror `test_providers_aqi_aeris_integration.py` shape. |
| `tests/fixtures/providers/aqi/openweathermap_current.json` + `.md` sidecar | NEW | — | Real-capture from OWM appid against Seattle coords. Sidecar documents the capture date, AQI value, dominant pollutant, sha256 of the JSON body. |

**Coverage rules:**
- Real-fixture-based assertions (per `clearskies-test-author.md` agent definition).
- All canonical exception members raised from `fetch()` get an explicit test.
- Cache key collision avoidance: tests that exercise the cache flush Redis between scenarios (per 3b-9 / 3b-10 precedent — see `_reset_module_state_for_tests` plus the Redis fixture in `conftest.py`).
- Mark `live_network` tier in pyproject.toml is still NOT registered (parking-lot follow-up from 3b-9); no live-network tests added in this round.

---

## Acceptance criteria (round close gates)

1. **Pytest green on weather-dev:**
   - AQI domain isolated: ≥ 261 passed (3b-10 baseline) + new OWM cases; 0 failures.
   - Redis tier: ≥ 21 passed (3b-10 baseline) + new OWM Redis cases; 0 failures.
   - Full default+integration: regression-free vs 3b-10's 1488/218/0 baseline (env-dependent skipped count acceptable per 3b-10 close notes).
2. **No new ruff / mypy violations** vs pre-round baseline.
3. **Auditor closeout** (Opus, post-pytest-green spawn) — accept / push-back / defer triage per "Lead synthesizes auditor findings; doesn't forward."
4. **Cross-check rule satisfied** — canonical §4.2 OWM column matches new module impl (lead verifies at audit time).
5. **L1 paid-tier-max-surface rule satisfied** — `CAPABILITY.supplied_canonical_fields` enumerates everything OWM Air Pollution can deliver; `aqiLocation` correctly excluded as PARTIAL-DOMAIN.
6. **L2 carry-forward satisfied** — no new canonical-exception re-construction sites; only intentional wrap is `(ValidationError, ValueError) → ProviderProtocolError` at the wire-validation boundary (documented in commit body + module docstring).
7. **EPA breakpoint correctness** — every band boundary in `_EPA_BREAKPOINTS` matches the EPA TAD source; test-author verifies via parametrized tests; commit body cites the EPA TAD URL.
8. **API-docs cross-check stays consistent** — no canonical or api-docs amendments needed mid-flight (cross-check rule already passed pre-brief).

---

## Process gates

**Agents addressability fallback chain** (sixth round running on the auditor harness gap; spawn prompts MUST restate):
```
lead → team-lead → opus → accumulate-to-closeout
```

**Spawn prompts MUST restate (don't trust agent-def auto-load alone):**
- Mid-flight SendMessage cadence (4-min floor).
- "No > 5 min in pure file-reading without a SendMessage" research-mode mitigation.
- "Commit early and often" rule.
- L2 "don't re-construct canonical exceptions" rule + the one intentional wrap site.
- L3 synthetic-from-real fixture pattern (NOT expected to fire — free-tier endpoint).
- L1 paid-tier-max-surface rule + PARTIAL-DOMAIN extension (`aqiLocation` is the only PARTIAL-DOMAIN here).

**Live scratchpad** at `c:\tmp\3b-11-scratch.md` — created at round start, appended continuously per "Live scratchpad during multi-agent rounds."

**Multi-line commit messages** on PowerShell — use `git commit -F c:\tmp\3b-11-<step>-msg.txt` not inline `-m`.

**Auditor spawn ONLY after** both teammates submit closeouts AND pytest is green on weather-dev (auditor counts toward agent-teams active-3 limit; don't burn the slot on a non-green diff).

**Lessons triage at round close** — per CLAUDE.md "Capture lessons in the right place." Default to decision-log-only; rules only for genuine process gaps not caught by current process; fold into existing rules where possible. 3b-8 = 0 new rules; 3b-9 = 0 new rules; 3b-10 = 1 rule extension (folded). Discipline target this round: ≤ 1 new rule unless a genuine new gap surfaces.

**Round close** — plan-status commit on meta repo; queue 3b-12 resume prompt at `c:\tmp\3b-12-resume-prompt.md`.

---

## Network caveat from session start (2026-05-10)

At session start (before this brief was written) the api repo had pending pushes from 3b-10 close that diverged with `ed8a805` (test-author's last commit, pushed from weather-dev). The 3b-10 lead-direct commit `dd61c09` is currently a sibling of `ed8a805` rather than a successor — both have parent `0d13800` on local DILBERT. Resolution required before this round's commits can push cleanly. Surfaced to user at session start; user said "we don't have to sit and wait to commit" — proceeding with brief draft. Push resolution + weather-dev sync remains queued for the network-recovered window.

Two pending meta-repo commits (`2a9dd9c` rule extension + `389853a` plan-status close) are clean fast-forwards on origin/master — no resolution required there.

---

## Quick reference — what changes where

```
weewx_clearskies_api/providers/aqi/
  openweathermap.py            NEW    ~500 lines
  _units.py                    EXTEND ~80-120 new lines (EPA breakpoints + helper)

weewx_clearskies_api/providers/_common/
  dispatch.py                  EXTEND import + 1 row in PROVIDER_MODULES

weewx_clearskies_api/config/
  settings.py                  EXTEND AQISettings.validate adds "openweathermap"

weewx_clearskies_api/endpoints/
  aqi.py                       EXTEND module-level _OWM_APPID + wire_aqi_settings branch + dispatch branch

weewx_clearskies_api/
  __main__.py                  EXTEND L251 valid-providers error message

tests/providers/aqi/
  test_openweathermap.py       NEW    ~700-900 lines
  test_units.py                EXTEND ~150-200 new lines
tests/
  test_providers_aqi_endpoint.py                  EXTEND ~80-130 new lines
  test_providers_aqi_openweathermap_integration.py NEW   ~400-500 lines
tests/fixtures/providers/aqi/
  openweathermap_current.json + .md sidecar       NEW
```

---

End brief.
