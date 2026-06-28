---
status: Archived — consolidated into PROVIDER-MANUAL.md
date: 2026-06-20
deciders: shane
supersedes:
superseded-by:
---

# ADR-063: Aeris Forecast Model Selection (Standard vs Xcast)

## Context

XWeather (Vaisala) offers two forecast endpoints:

- **`/forecasts`** — standard forecast blend. Currently used by the Aeris provider module.
- **`/xcast/forecasts`** — ML-enhanced forecasts. Uses machine learning to blend Vaisala's proprietary sensor network (AtmoCast, GroundCast, TempCast hardware), global weather models, satellite data, and connected car data. Documented up to 78% improvement for temperature and wind speed where Xcast sensors are deployed. All other fields use the standard blend.

Both endpoints are available on the PWS contributor subscription tier (no add-on required). Live testing (2026-06-20) confirmed both return HTTP 200 with the same envelope structure. The hourly wire shape is identical except xcast appends `tempConfidenceLimit` and `windConfidenceLimit` (both `null` where no sensors are deployed nearby).

**Daynight limitation:** `/xcast/forecasts` does not support `filter=daynight`. It ignores the filter and returns hourly periods regardless. Verified 2026-06-20: requesting `filter=daynight` on xcast returns `interval: "1hr"` with hourly periods, while standard `/forecasts?filter=daynight` returns `interval: "daynight"` with proper day/night summary periods.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| A — Always use standard `/forecasts` | No code change; zero risk | Ignores available ML improvement |
| B — Always use xcast `/xcast/forecasts` | Automatic improvement; no operator choice needed | No operator control if pricing changes; daynight filter unsupported |
| C — Operator selects model in wizard (recommended) | Operator controls endpoint; can switch if pricing changes; default to xcast for best quality | One new config key; one new wizard UI element |

## Decision

Option C. The setup wizard presents Aeris operators with a choice between "Standard" and "Xcast (ML-enhanced)" forecast models. Default: xcast. Config key: `aeris_forecast_model` in `api.conf [forecast]`. Valid values: `"standard"`, `"xcast"`.

Because xcast does not support `filter=daynight`, only the hourly API call uses the selected model's path. The daynight call always uses the standard `/forecasts` endpoint regardless of the model setting. This is transparent to the operator — they select a model, and the module applies it where xcast is effective (hourly precision) while falling back to standard where it isn't (daily summaries).

## Consequences

- **One new config key:** `aeris_forecast_model` in `api.conf [forecast]`. Default `"xcast"`. Operators with existing configs get xcast automatically on next restart.
- **Hourly-only enhancement:** Xcast ML improvement applies to hourly forecast data only. Daily forecasts continue to use standard Aeris daynight aggregation.
- **Confidence limits in `extras`:** When xcast is selected and the operator is near Xcast sensors, `tempConfidenceLimit` and `windConfidenceLimit` pass through in the hourly point's `extras` dict. These are not new canonical fields — they are provider-specific metadata.
- **Cache key includes model:** Different models produce separate cache entries. Switching models does not serve stale data from the other model.
- **No fallback logic:** If the operator selects xcast and their key doesn't support it, the wizard's key-test step will show a 401/403 error suggesting they switch to standard. No runtime auto-probe or auto-fallback.
- **Wizard UI element:** Aeris-specific radio group shown only when Aeris is the selected forecast provider. Hidden for all other providers.

## Acceptance criteria

- [ ] `fetch(forecast_model="xcast")` calls `/xcast/forecasts` for hourly, `/forecasts` for daynight
- [ ] `fetch(forecast_model="standard")` calls `/forecasts` for both hourly and daynight
- [ ] Default model is `"xcast"` when config key is absent
- [ ] Cache keys differ between `"standard"` and `"xcast"` models
- [ ] `tempConfidenceLimit` and `windConfidenceLimit` appear in hourly point `extras` when non-null, absent when null
- [ ] Existing standard forecast fixtures parse without modification
- [ ] Wizard shows model selection radio only when Aeris is the selected forecast provider
- [ ] Wizard key-test uses the selected model's endpoint
- [ ] Full wizard round-trip: select model → test key → review → apply → re-run → pre-fill
- [ ] PROVIDER-MANUAL.md §4 updated to document model selection

Checked at: (a) phase-boundary QC, (b) pre-deploy verification.

## Implementation guidance

**API module (`providers/forecast/aeris.py`):**
- Add `AERIS_XCAST_FORECASTS_PATH = "/xcast/forecasts"` constant
- `_fetch_hourly()` accepts `forecasts_path` parameter, defaults to `AERIS_FORECASTS_PATH`
- `_fetch_daynight()` is NOT modified — always uses `AERIS_FORECASTS_PATH` (xcast doesn't support daynight)
- `fetch()` accepts `forecast_model: str = "xcast"`, resolves to path, passes only to `_fetch_hourly()`
- `_build_cache_key()` includes `forecast_model` in the hash payload
- `_AerisHourlyPeriod` gets optional `tempConfidenceLimit` and `windConfidenceLimit` fields (dict or None)
- Confidence limits written to hourly point's `extras` dict when non-null

**Config wiring (`config/settings.py`, `endpoints/forecast.py`):**
- `ForecastSettings.aeris_forecast_model` read from `[forecast]` section, default `"xcast"`, validated as `"standard"` or `"xcast"`
- `wire_forecast_settings()` passes model to a new `wire_aeris_forecast_model()` setter
- Aeris dispatch branch passes `forecast_model` to `aeris.fetch()`

**Wizard (`weewx-clearskies-stack`):**
- `WizardState.aeris_forecast_model` field, default `"xcast"`
- Radio group in provider step: "Xcast (ML-enhanced)" (default) / "Standard"
- Key-test hits the selected model's endpoint; 401/403 suggests switching to standard
- Model included in apply payload and pre-filled on re-run

**Out of scope:**
- Dashboard rendering of confidence intervals (extras pass through; rendering is a separate task)
- 10-minute resolution (`filter=10min`) — changes data volume, needs its own ADR
- Auto-probe/fallback logic — operator makes explicit choice

## References

- PROVIDER-MANUAL.md §4 (Forecast Providers)
- XWeather Xcast docs: https://www.xweather.com/docs/weather-api/endpoints/xcast-forecasts
- Live verification: 2026-06-20, Huntington Beach CA (33.6568, -117.9827), PWS contributor tier
- Fixture: `tests/fixtures/providers/aeris/xcast_forecasts_hourly.json`
