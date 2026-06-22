---
status: Accepted
date: 2026-06-22
deciders: shane
supersedes:
superseded-by:
---

# ADR-068: Auto-Calibration Baseline System (Amended — Monthly Normals)

## Context

Haze detection (ADR-067) compares current Kcs against a "clean-sky baseline" — the Kcs value expected on a clear day with no aerosol loading. This baseline varies by station (altitude, local climate, horizon obstructions) and by season (water vapor column changes). A static threshold cannot work across the ~15,000 weewx stations worldwide.

Ground-based radiation networks (ARM, BSRN, SURFRAD) have solved this problem. Long & Ackerman's clear-sky detection algorithm (`long-ackerman-2000-summary.md`) and its operational descendants (`clear-sky-baseline-methodology.md`) establish that cos(Z) normalization (already done by Kcs = GHI/maxSolarRad) handles the diurnal cycle, no time-of-day binning is needed, and seasonal stratification is standard practice. Renner et al. (2019) used the 85th percentile across 42 BSRN stations; for haze detection (higher bar — exclude routine hazy-clear days), 92nd percentile is appropriate.

**Amendment (2026-06-22):** The original v1 design used a flat 90-day rolling window with no seasonal awareness. Research (Correa 2022, Renner 2019, Stein et al. 2012) establishes that clear-sky transmittance varies significantly by month — water vapor column, aerosol optical depth, and Rayleigh scattering all follow seasonal cycles. A flat 90-day window averages across seasons, producing a baseline that is too high in winter (water vapor is low, Kcs is naturally high) and too low in summer (water vapor is high, Kcs is naturally lower). This amendment replaces the flat window with 12 per-month climatological normals ("monthly normals"), the standard approach in radiation network science.

New operators need a bootstrap path. Historical PM data is available free for most stations via OpenAQ (141 countries, 2016-present). maxSolarRad can be recomputed for pre-weewx-4.0 records using the Ryan-Stolzenbach formula (`weewx-maxsolarrad-history.md`).

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Monthly normals with auto-bootstrap (chosen) | Science-backed seasonal stratification; each month gets its own baseline; auto-bootstrap removes operator burden | Requires 30 samples per month (vs 22 total) for full calibration; longer path to 12/12 |
| Flat 90-day rolling window (original v1) | Simpler to implement; fewer samples needed | Ignores seasonal variation; baseline too high in winter, too low in summer; contradicts the project's own research |
| Mean-based with outlier rejection | Simpler statistics | Sensitive to distribution skew; hazy-but-common days pull the mean down |
| Fixed reference from external climatology (e.g., NSRDB) | No learning period | Station-specific factors (horizon, local albedo) make external references unreliable |

## Decision

Monthly-normals percentile model. Parameters are **fixed** (not operator-tunable) — the science sets these values:

- **12 per-month baselines.** Each calendar month (January through December) maintains its own independent Kcs baseline. A sample collected at 11 PM January 31 local time is January's bin. Today's Kcs is compared against what clear sky looks like *this month*, not a seasonal average.
- **3-year rolling window.** Within each month bucket, samples older than 3 years are pruned. Sensor drift and hardware changes make older data unreliable. Minimum 2 years of data required for bootstrap (OpenAQ coverage).
- **92nd percentile.** Fixed at the 92nd percentile of qualifying clean-sky Kcs samples per month. Higher than Renner's 85th (climate research, where hazy-clear is "normal") because haze detection needs a reference that excludes routinely hazy-clear days.
- **30 samples per month minimum.** A month's learned baseline activates only when it has >= 30 qualifying clean-sky samples. Below this, the month falls back to the flat baseline (pooled across all months).
- **Progressive activation.** Each month independently transitions from the flat fallback to its learned normal at >= 30 samples. The system starts with flat baseline behavior (current v1 behavior) and progressively improves as months accumulate data. Admin shows "N of 12 months calibrated."
- **Clean-sample selection criteria** — unchanged from v1. A sample qualifies only when ALL are true: (a) PM2.5 < 12 µg/m³ AND PM10 < 50 µg/m³ (EPA "Good" breakpoints), (b) solar elevation > 10°, (c) sky classifier returns a clear-ish label, (d) no rain in prior 30 minutes.
- **No time-of-day bins:** cos(Z) normalization via Kcs handles the diurnal cycle. No reviewed radiation network uses time-of-day stratification.
- **Persistent storage:** `/etc/weewx-clearskies/calibration.json`, v2 format with month-keyed structure. v1 migration on load (distributes flat samples into month buckets by timestamp using station timezone).
- **Auto-enable at 12/12.** Operator can toggle `haze_detection` off during the learning period. System auto-enables once all 12 months are calibrated.

**Removed from operator configuration (v1→v2):**
- `calibration_percentile` — fixed at 0.92 (science-determined).
- `calibration_window_days` — replaced by 3-year per-month window (not tunable).
- `calibration_min_samples` — fixed at 30 per month (science-determined).

**Retained operator configuration:**
- `haze_detection` — toggle (bool).
- `gamma` — hygroscopic correction exponent (float, advanced override).
- `haze_aqi_provider` — AQI provider override (string).

### Auto-bootstrap

Automatic, not manual. The API detects conditions at startup and bootstraps in the background:

1. OpenAQ API key is present in `secrets.env`.
2. Calibration state has fewer than 12 months calibrated.
3. A pyranometer is present (radiation column in archive schema).

When all three are true, bootstrap runs synchronously after `load_persisted()` but before packet-tap registration. This avoids thread-safety issues and follows the same pattern as the cache warmer. Takes 2-5 minutes. No CLI command, no admin button, no SSH required.

The `--years` and `--max-distance-km` CLI flags are removed. Bootstrap always pulls the maximum available history (up to 3 years) from the nearest monitor (within 25 km per OpenAQ API limit).

### Hardware change detection

Station hardware changes (e.g., replacing a pyranometer) invalidate accumulated baseline data because a new sensor may have different spectral response characteristics.

- **Station type tracking:** `calibration.json` records the `station_type` from weewx.conf at time of last persist. On startup, if the current station type differs from the persisted value, log a WARNING.
- **Drift detection:** Within each month, if the mean of the last 10 samples diverges from the month's baseline by more than 0.05 (5%), a drift warning is generated. Reported in the admin UI and API endpoint.
- **Manual reset:** Admin UI "Reset Calibration" button. Clears all samples and baselines. Triggers re-bootstrap if conditions are met.

### Graceful sensor failover

When sensor data is absent, the affected module silently falls back to provider present-weather codes — same deferral mechanism as nighttime (ADR-071). No operator-facing warnings. Dashboard never shows null data.

| Sensor absent | Failover |
|---|---|
| `radiation` (no pyranometer) | Sky: provider cloud cover % (already works). Haze: provider present weather (HZ) 24/7. Calibration: skipped entirely. |
| `dewpoint` (no hygrometer) | Fog/mist: provider present weather (BR/FG). f(RH) correction: skipped (use uncorrected Kcs deficit). |

### API endpoints for cross-host calibration state

Admin UI runs on weather-dev; calibration data lives on weewx. Two new endpoints enable cross-host access:

- `GET /setup/calibration-state` — returns per-month calibration data. Auth: proxy secret.
- `POST /setup/calibration-reset` — clears all data, triggers re-bootstrap. Auth: proxy secret.

## Consequences

- **Reworked module:** `sse/auto_calibration.py` — monthly-normals model, 12 per-month Kcs baselines, 3-year rolling window, automatic bootstrap, persistent v2 storage, drift detection, station type tracking.
- **Updated module:** `bootstrap/importer.py` — appends to monthly bins, reports per-month counts.
- **Updated module:** `__main__.py` — auto-bootstrap at startup, `configure()` removed, sensor checks wired.
- **Updated module:** `config/settings.py` — `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` removed from `ConditionsSettings`.
- **Existing module (interface unchanged):** `sse/haze_condition.py` — still receives a single `set_baseline(float)` call. f(RH) correction handles None humidity gracefully.
- **New API endpoints:** `GET /setup/calibration-state`, `POST /setup/calibration-reset`.
- **Updated admin UI:** 12-month status grid replaces flat sample count. Reset button. Drift warnings. No parameter inputs.
- **Haze detection dependency:** ADR-067's Kcs deficit comparison requires this baseline. Haze detection is inactive until at least the current month's baseline (or flat fallback) is available.
- **Storage location:** `/etc/weewx-clearskies/calibration.json` — v2 format, v1 auto-migrated on load.

## Acceptance criteria

- [ ] 12 per-month baselines computed independently (January through December, station local time)
- [ ] 3-year rolling window: samples older than 3 years pruned from each month bucket
- [ ] 92nd percentile computed correctly per month from qualifying clean-sky samples
- [ ] Month requires >= 30 samples before its learned baseline activates
- [ ] Flat fallback (pooled across all months) used when current month has < 30 samples
- [ ] Progressive activation: each month independently transitions from flat to learned
- [ ] `get_calibration_state()` returns correct schema: `months_calibrated` (0-12), `per_month` (12-element list), `overall_state`, `drift_warnings`, `station_type`
- [ ] State transitions: "no-data" → "bootstrapping" → "partial" → "fully-calibrated"
- [ ] v2 persistence round-trips correctly (month-keyed calibration.json)
- [ ] v1→v2 migration distributes flat samples into month buckets using station timezone
- [ ] `configure()` removed — no operator-tunable calibration parameters
- [ ] `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` removed from `ConditionsSettings`
- [ ] Auto-bootstrap runs at startup when: OpenAQ key present + months_calibrated < 12 + radiation column exists
- [ ] Bootstrap `--years` and `--max-distance-km` CLI flags removed
- [ ] `importer.py` appends to monthly bins, not flat `_samples` list
- [ ] Drift detection: last-10-sample mean vs baseline divergence > 0.05 triggers warning
- [ ] Station type change: logged WARNING on startup if persisted type differs from current
- [ ] `GET /setup/calibration-state` returns per-month data (auth: proxy secret)
- [ ] `POST /setup/calibration-reset` clears all data and triggers re-bootstrap (auth: proxy secret)
- [ ] Missing pyranometer → calibration skipped, haze defers to provider present weather
- [ ] Missing hygrometer → f(RH) correction skipped, fog/mist defers to provider
- [ ] Admin 12-month grid renders with per-month counts, baselines, and status indicators
- [ ] Admin reset button clears data via API endpoint
- [ ] Clean-sample selection criteria unchanged from v1
- [ ] Baseline persists across API restarts
- [ ] maxSolarRad recomputation matches weewx `solar_rad_RS()` for same inputs (unchanged)

## Implementation guidance

- **Sample storage format:** `_monthly_samples: dict[int, list[tuple[float, float]]]` keyed by month 1-12. Each entry is `(unix_timestamp, kcs_value)`. Station timezone determines which month a sample belongs to (a sample at 11 PM Jan 31 local = January).
- **Baselines:** `_monthly_baselines: dict[int, float | None]` — 92nd percentile per month, None if < 30 samples. `_flat_baseline: float | None` — pooled across all months as fallback.
- **Percentile computation:** Pure-Python sorted-list interpolation (existing `_percentile()` helper). Recompute current month's baseline on each new sample.
- **v2 persistence format:**
  ```json
  {
    "version": 2,
    "station_type": "Vantage",
    "monthly_samples": {"1": [[ts, kcs], ...], "12": [...]},
    "monthly_baselines": {"1": 0.912, "2": null, ...},
    "flat_baseline": 0.908
  }
  ```
- **v1 migration:** `load_persisted()` detects v1 (no "version" key). Distributes flat `samples` list into month buckets by converting each timestamp to station-local month. Computes per-month baselines. Persists as v2 immediately.
- **Station timezone:** Module needs station timezone (from StationInfo) to bin samples by local month. `set_timezone(tz_name: str)` called at startup.
- **Pyranometer check:** `_has_radiation: bool` flag. Set at startup. Re-evaluated in `process_packet()` — if `get_current_kcs()` returns non-None, flip to True (sensor added without restart).
- **Auto-bootstrap flow:** (1) API starts, loads persisted state. (2) Checks: OpenAQ key + months_calibrated < 12 + has_radiation. (3) If all true, runs bootstrap synchronously (before packet-tap). (4) Bootstrap queries OpenAQ, matches against archive, appends to monthly bins. (5) Persists and continues startup.
- **Out of scope:** Bootstrap from Aeris historical API. Real-time provider-to-smoother pipeline.

## References

- Research: `docs/reference/haze-physics/clear-sky-baseline-methodology.md` — ARM/BSRN methodology, monthly stratification, no time-of-day bins
- Research: `docs/reference/haze-physics/ryan-stolzenbach-model.md` — R-S formula, atc parameter, low-elevation limitations
- Research: `docs/reference/haze-physics/aqi-historical-data-survey.md` — EPA AQS, OpenAQ, Aeris historical; provider landscape
- Research: `docs/reference/haze-physics/weewx-maxsolarrad-history.md` — weewx 4.0.0+ native archiving, recomputation feasibility
- Research: Correa 2022, Renner 2019, Stein et al. 2012 — seasonal variation in clear-sky transmittance
- Related ADRs: ADR-067 (haze detection — consumes baseline), ADR-066 (AQI providers — PM data source), ADR-071 (nighttime deferral — sensor failover follows same pattern)
- Existing code: `weewx/wxformulas.py` `solar_rad_RS()` (R-S reference implementation), `sse/sky_condition.py` (Kcs computation)
