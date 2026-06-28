---
status: Archived — consolidated into DASHBOARD-MANUAL.md + API-MANUAL.md + ARCHITECTURE.md
date: 2026-06-27
deciders: shane
supersedes: ADR-020
---

# ADR-075: Temporal consistency model

## Context

Clear Skies needs a complete temporal model — from how timestamps are stored and transmitted, through how the station's timezone is determined, to how each card knows when to refresh and what "today" means.

ADR-020 (2026-05-02) established the wire format (UTC ISO-8601 Z) and display rule (station-local time via IANA timezone). Those rules are sound but only cover the rendering layer. Three harder problems were left unaddressed, all of which have caused recurring production bugs:

1. **No station clock contract.** The dashboard has no reliable way to answer "what date/time is it at the station right now?" Components use `new Date()` (browser-local time), `Date.now()` (UTC epoch — correct for elapsed-time math but wrong for date-boundary logic), or `index === 0` as a proxy for "today." All three have produced bugs:
   - `useSmartAlmanac.ts` computes "tomorrow" using browser-local `new Date()` — wrong for any visitor not in the station timezone.
   - `DailyColumns.tsx` labels the first forecast entry as "Today" via `index === 0` — wrong when the provider has already rolled to tomorrow's forecast.
   - On Friday 2026-06-27, the forecast card showed "Today, Sunday, Monday" — Saturday was missing because Aeris had rolled to Saturday's data and `index === 0` labeled it "Today."

2. **No data freshness contract.** The API caches provider data with internal TTLs (forecast 30 min, alerts 5 min, AQI 15 min, almanac 24 hr) but these are implementation details invisible to the dashboard. Cards either don't auto-refresh (almanac, forecast), poll on hardcoded intervals (radar: 1 hour), or rely on SSE (current observation). The result: stale forecasts after provider updates, cards that don't refresh until the visitor manually reloads, and inconsistent refresh behavior across the site.

3. **No per-domain temporal window definition.** Different data types have different "day" concepts: forecast days follow station-local midnight; sun rise/set is sunrise-to-sunrise; moon rise/set follows a ~24.8h cycle unaligned to calendar days; planet visibility spans astronomical night (sunset to sunrise). The dashboard currently applies calendar-day logic to all domains, producing wrong results for astronomical data that crosses midnight.

These problems are systemic. Individual fixes get reverted because agents don't understand the temporal model — they see `new Date()` as idiomatic JavaScript and reintroduce it, or they assume `index === 0` is "Today" because it usually is during testing. The fix is an explicit model with mechanical rules.

This ADR supersedes ADR-020 by absorbing its rules and extending them into a complete temporal model. All of ADR-020's decisions are preserved; nothing is reversed.

### weewx temporal model (for reference)

weewx stores all data as UTC epoch seconds. It has no timezone configuration in core `[Station]`. Local-time conversions use the OS timezone of the host machine. From the weewx 5.3 devnotes: "WeeWX stores all data in UTC... To avoid tripping up over time zones and daylight savings time, WeeWX generally uses Python routines to do this conversion. Nowhere in the code base is there any explicit recognition of DST." weewx also warns: "If [the station] location does not correspond to the computer's local time, reports with astronomical times will probably be incorrect."

weewx is therefore a UTC data store, not a timezone authority. The API must be the timezone authority for all downstream consumers.

## Decision

### Principle: station-centric temporal frame

Clear Skies is a station-centric weather site. The station's location and timezone are the fixed reference frame. All temporal logic — date boundaries, "today" determination, forecast day labeling, astronomical windows, refresh timing — uses the station's timezone, not the visitor's browser timezone or UTC. A visitor in Tokyo viewing a New England station sees Eastern times — they're looking at the station, not their location. Same precedent as every weewx skin.

This principle governs not just how times are rendered, but how temporal logic is computed throughout the entire stack.

### 1. Wire format: UTC

Every timestamp on the API wire ends in `Z` (UTC ISO-8601). No local-time strings in API responses. Python `datetime` objects in API-layer code must carry `tzinfo=UTC` — naive datetimes are forbidden.

The single exception is `stationClock.time` (§3), which carries a UTC offset so the dashboard can interpret it without a timezone library. This is metadata about the station's clock, not observation data.

### 2. Display: station-local

The dashboard renders all timestamps in the **station's local time zone**, not the visitor's browser-local zone. Use `Intl.DateTimeFormat` with the station IANA timezone and the active locale (ADR-021). No JavaScript date library is required.

Never call `toLocaleString()` or `Intl.DateTimeFormat()` without an explicit `timeZone` option. Always supply the station IANA identifier.

NOAA-report rendering, Records-page year boundaries, Charts-page x-axes, and all other time-axis displays use station timezone.

**No per-user timezone override at v0.1.** No per-user identity to attach a preference to. Phase 6+ enhancement: localStorage override that re-formats client-side using `Intl.DateTimeFormat` — no server change. Same precedent as units (ADR-019).

### 3. API as station clock authority

The API is the sole source of "what time is it at the station." The timezone authority chain is:

| Priority | Source | When used |
|----------|--------|-----------|
| 1 | Operator setting in `api.conf` or wizard | Always preferred when set |
| 2 | weewx.conf `[Station] timezone` | Auto-detected at startup |
| 3 | OS timezone of the weewx host | Fallback when weewx.conf has no timezone |
| 4 | UTC + startup warning | Last resort; operator must configure |

The wizard auto-populates the timezone from the OS timezone during setup. The operator can change it in the admin UI.

**StationMetadata fields.** The `GET /api/v1/station` response includes:
- `timezone` — IANA identifier string (e.g., `"America/New_York"`).
- `timezoneOffsetMinutes` — current UTC offset in minutes (e.g., `-240` for EDT). Useful as a fallback for clients that don't ship full IANA timezone data. Computed at station startup from the IANA identifier; reflects the offset at startup time.

Daylight saving transitions are handled by the browser's IANA timezone data when rendering. No server-side DST logic.

**Station clock response field.** Every API response includes the station's current local date and time in the response envelope:

```json
{
  "data": { ... },
  "stationClock": {
    "date": "2026-06-27",
    "time": "2026-06-27T22:30:00-04:00",
    "timezone": "America/New_York"
  }
}
```

- `date` — station-local date as YYYY-MM-DD. This is the canonical answer to "what day is it at the station?" The dashboard uses this for all date-boundary logic.
- `time` — station-local time as ISO-8601 with UTC offset. Useful for "is it daytime?" or position-on-arc calculations. The offset is included so the dashboard can convert to UTC epoch for elapsed-time math without a timezone library.
- `timezone` — IANA identifier (redundant with `StationMetadata.timezone` but included for self-contained responses).

The `stationClock` block is computed at response time from the station's configured timezone. It does not require a database query or any external call.

### 4. Data freshness envelope

Every cacheable API response includes a `freshness` block:

```json
{
  "data": { ... },
  "freshness": {
    "generatedAt": "2026-06-27T22:30:00Z",
    "validUntil": "2026-06-27T23:00:00Z",
    "refreshInterval": 1800
  }
}
```

| Field | Type | Meaning |
|-------|------|---------|
| `generatedAt` | UTC ISO-8601 Z | When the API produced this response |
| `validUntil` | UTC ISO-8601 Z | When the data should be considered stale. After this time, the dashboard should refetch. |
| `refreshInterval` | integer (seconds) | How often this data type typically updates at the source. A card that wants "refresh as fast as the data updates" uses this as its poll interval. |

**Per-domain defaults** (API-side, configurable in `api.conf`):

| Domain | `refreshInterval` | `validUntil` | Rationale |
|--------|-------------------|-------------|-----------|
| Current observation (REST) | `archiveIntervalSeconds` (from weewx.conf) | generatedAt + archiveInterval | Matches weewx archive write cadence; a 60s station refreshes at 60s, a 900s station at 900s |
| SSE loop packets | — (push) | — | Real-time; no polling needed |
| Forecast | 1800 (30 min) | generatedAt + 30 min | Provider update cadence |
| Alerts | 300 (5 min) | generatedAt + 5 min | Safety-critical; frequent checks |
| AQI | 900 (15 min) | generatedAt + 15 min | Provider update cadence |
| Almanac (daily) | 86400 (24 hr) | station-local next midnight | Changes once per calendar day |
| Almanac (positions) | 60 (1 min) | generatedAt + 1 min | Continuously changing |
| Radar frames | 300 (5 min) | generatedAt + 5 min | Frame metadata cadence |
| Earthquakes | 300 (5 min) | generatedAt + 5 min | USGS update cadence |
| Records | `archiveIntervalSeconds` (from weewx.conf) | generatedAt + archiveInterval | New records appear at archive write cadence |
| Charts config | 86400 (24 hr) | generatedAt + 24 hr | Static unless operator edits |
| Station metadata | 86400 (24 hr) | generatedAt + 24 hr | Static unless operator edits |

**weewx-derived defaults.** The `current_observation` and `records` domains derive their `refreshInterval` from the station's `archive_interval` (read from weewx.conf `[StdArchive] archive_interval`, already loaded by the API at startup via `StationInfo`). This ensures the dashboard polls at the cadence data actually arrives — not faster (wasted requests) or slower (stale data). The `[freshness]` section in `api.conf` allows operator override of any domain's interval.

**The dashboard uses `validUntil` to schedule refetches, not hardcoded intervals.** When `Date.now() > validUntilMs`, the card triggers a background refetch. Cards may use `refreshInterval` to set a proactive poll timer so they don't have to wait until the response expires.

**Responses that are not cacheable** (SSE events, setup endpoints) do not carry a `freshness` block.

### 5. Per-domain temporal windows

Different data types operate on different temporal cycles. The API defines the observation window for each domain; the dashboard does not compute its own windows.

| Domain | "Day" means | Boundary | API responsibility | Dashboard responsibility |
|--------|------------|----------|-------------------|-------------------------|
| **Forecast** | Calendar day in station-local time | Station-local midnight | Return `validDate` as station-local YYYY-MM-DD | Compare `validDate` against `stationClock.date` to determine which entry is "Today" |
| **Sun rise/set** | Sunrise-to-sunrise | Station-local sunrise | Compute using Skyfield with station-local day window (midnight to midnight) | Display the rise/set pair; use `stationClock.time` for arc position |
| **Moon rise/set** | ~24.8h lunar cycle, not calendar-aligned | Moonrise to moonrise | Return rise/set for the station-local calendar day; indicate via null when the moon doesn't rise/set that day | Display the pair; handle cross-midnight transit via the existing `setMs <= riseMs` guard |
| **Planet visibility** | Astronomical night (sunset to sunrise) | Station-local sunset/sunrise | Return visibility windows with rise/set times and period labels (evening, morning, all-night) | Render visibility relative to the current night window |
| **Observation "today"** | Station-local calendar day | Station-local midnight | Return observation timestamps as UTC ISO-8601 Z | Use `stationClock.date` for "today's high/low" logic |
| **Observation "current"** | Instantaneous | N/A (most recent loop packet) | Return the latest observation with its timestamp | Display the value; use SSE for real-time updates |

**Almanac smart switching.** The `useSmartAlmanac` hook's "show next rise/set" logic must use `stationClock.time` (converted to epoch ms) for all comparisons, not `Date.now()`. The "tomorrow" date must be computed from `stationClock.date` (increment by one day), not from `new Date()`.

**Forecast "Today" labeling.** The dashboard compares each daily forecast entry's `validDate` against `stationClock.date`:
- Match → label "Today"
- `stationClock.date` + 1 day → label "Tomorrow"
- All others → weekday name from `validDate`
- No match for today → no "Today" label (the forecast has already rolled; show weekday names for all entries)

### 6. Dashboard temporal rules

**Approved patterns:**

| Need | Pattern | Source |
|------|---------|--------|
| "What date is it at the station?" | Read `stationClock.date` from the most recent API response | API |
| "What time is it at the station?" | Read `stationClock.time` from the most recent API response, or convert `Date.now()` using station IANA TZ via `Intl.DateTimeFormat` | API or `Intl.DateTimeFormat` |
| "Is this forecast entry today?" | Compare `entry.validDate === stationClock.date` | API |
| "Format a timestamp for display" | `formatLocalTime(iso, stationTz, locale)` from `utils/time.ts` | Existing utility |
| "Has enough time elapsed since X?" | `Date.now() - new Date(iso).getTime() > thresholdMs` | Native (UTC epoch math) |
| "Should I refetch?" | `Date.now() > new Date(freshness.validUntil).getTime()` | API freshness envelope |
| "Tomorrow's date at the station" | Increment `stationClock.date` by one day (parse as date, add 1, format YYYY-MM-DD) | Derived from API |

**Banned patterns (grep-checkable FAIL conditions):**

```
FAIL: new Date() used to determine station-local date or time
      (Date.now() is OK for UTC epoch elapsed-time math)
FAIL: .toISOString().split('T')[0] used to derive a station-local date
      (this gives a UTC date, not station-local)
FAIL: index === 0 as a proxy for "today" in forecast or any date-ordered list
FAIL: Hardcoded setInterval for data refresh without reference to freshness.validUntil
      or freshness.refreshInterval
FAIL: toLocaleString() or Intl.DateTimeFormat() without explicit timeZone option
FAIL: Any "is it daytime?" check that doesn't use station timezone or stationClock
```

**Station clock utility.** A new `utils/station-clock.ts` module provides:

```typescript
/** Parse stationClock.date from an API response. */
export function getStationDate(response: { stationClock?: StationClock }): string;

/** Increment a YYYY-MM-DD date by n days. */
export function addDays(dateStr: string, n: number): string;

/** Is the given validDate "today" at the station? */
export function isStationToday(validDate: string, stationDate: string): boolean;

/** Convert stationClock.time to epoch ms for elapsed-time comparisons. */
export function stationTimeMs(stationClock: StationClock): number;
```

All components that need station-date logic import from this module. No component computes station dates ad-hoc.

### 7. Operator idle configuration

A new `idleTimeout` setting in the operator config (via wizard/admin), served to the dashboard as part of station metadata or branding:

| Setting | Type | Default | Meaning |
|---------|------|---------|---------|
| `idleTimeout` | integer (minutes) | 30 | After this many minutes of no user interaction (mouse move, keypress, scroll, touch), cards reduce their refresh rate |
| `idleRefreshFactor` | integer | 10 | Divisor applied to `refreshInterval` during idle. Factor 10 means a card that normally refreshes every 30s refreshes every 300s (5 min) when idle |

**Idle behavior:**
- After `idleTimeout` minutes of no interaction, all polling cards multiply their `refreshInterval` by `idleRefreshFactor`.
- SSE connection stays open (it's push-based; no cost to keeping it alive).
- Any user interaction (mouse move, keypress, scroll, touch) resets the idle timer and immediately restores normal refresh rates.
- Setting `idleTimeout` to 0 disables idle detection (wall-display / kiosk mode — refresh forever at full rate).

**Implementation:** A single `useIdleDetector()` hook in the dashboard maintains the idle state. Cards read the idle state and adjust their poll interval accordingly. The idle detector is a top-level provider, not per-card.

### 8. SSE and current observation

SSE loop packets continue to use UTC epoch seconds for `dateTime` (matching weewx's wire format). The dashboard's `useRealtimeObservation` hook converts to ISO-8601 Z on receipt. No change from current behavior — SSE is real-time push and doesn't have freshness or date-boundary concerns.

The REST `GET /api/v1/current` response carries the `stationClock` and `freshness` blocks like all other responses. The `freshness.refreshInterval` for current observation matches the archive interval (default 300s / 5 min) since that's how often the underlying archive data changes. SSE provides real-time updates between archive records.

## Options considered

| Option | Verdict |
|--------|---------|
| A. Complete temporal model: station clock, freshness, per-domain windows (this ADR) | **Selected** — centralizes temporal authority, gives cards the metadata they need, prevents recurring date-boundary bugs |
| B. Station-local display with browser-local logic (ADR-020 status quo) | Rejected — display rule is correct but insufficient; date-boundary and freshness bugs recur without the full model |
| C. Browser-local display (visitor sees their own timezone) | Rejected — surprises visitors who think they're seeing the station's clock |
| D. UTC display | Rejected — readable for ops, hostile for everyone else |
| E. Dashboard-side timezone library (e.g., date-fns-tz or luxon) | Rejected — adds bundle weight, moves timezone authority to the client, doesn't solve the "what day is it?" problem since the dashboard still needs the API to tell it |
| F. All timestamps in station-local time on the wire | Rejected — makes caching harder, creates ambiguity during DST transitions |

## Consequences

### API changes
- Add `stationClock` block to all API response envelopes (computed at response time; no DB query)
- Add `freshness` block to all cacheable API responses
- Per-domain `refreshInterval` defaults configured in `api.conf [freshness]` section
- `idleTimeout` and `idleRefreshFactor` added to operator config (wizard/admin)

### Dashboard changes
- New `utils/station-clock.ts` module with station-date utilities
- `useSmartAlmanac.ts` rewritten to use `stationClock.date` instead of `new Date()`
- `DailyColumns.tsx` rewritten to compare `validDate` against `stationClock.date` instead of `index === 0`
- New `useIdleDetector()` hook for idle timeout management
- `useApiQuery` extended to respect `freshness.validUntil` for auto-refetch scheduling
- All cards audited for banned temporal patterns

### Manual updates required
- **API-MANUAL.md** — new §"Temporal model" covering stationClock, freshness envelope, per-domain windows
- **DASHBOARD-MANUAL.md** — update §"Time Zones" to reference this ADR; add §"Temporal rules" covering approved/banned patterns, station-clock utility, idle detection
- **ARCHITECTURE.md** — response shape examples updated to show stationClock and freshness blocks

### Acceptance criteria

1. Every cacheable API response includes `stationClock` and `freshness` blocks
2. The forecast card labels "Today" by comparing `validDate` against `stationClock.date`, not by array index
3. `useSmartAlmanac` computes "tomorrow" from `stationClock.date`, not `new Date()`
4. No dashboard source file outside `utils/time.ts` and `utils/station-clock.ts` uses `new Date()` for station-date logic (grep-verifiable)
5. The idle detector pauses non-SSE polling after operator-configured timeout
6. All per-domain `refreshInterval` values match the table in §4
7. `Intl.DateTimeFormat` calls always include an explicit `timeZone` option set to the station IANA identifier

## Out of scope

- Per-user timezone override — Phase 6+ enhancement (localStorage override, client-side only, no server change)
- TZ lookup library choice for the wizard (e.g., `timezonefinder`) — wizard scope, not this ADR
- Historical timezone changes for stations that have moved — v0.1 assumes a stable station timezone
- Provider-specific update schedule discovery (API uses static defaults; future enhancement could auto-detect from provider response headers)

## References

- ADR-020: Time zone handling (superseded by this ADR)
- ADR-010: Canonical data model (locks UTC ISO-8601 Z wire format)
- ADR-019: Units handling (parallel precedent for station-centric defaults, no per-user override)
- ADR-021: i18n strategy (locale sourcing for `Intl.DateTimeFormat`)
- ADR-027: Config and setup wizard (timezone configuration path)
- ADR-042: Unit conversion authority (parallel pattern — API as single conversion authority)
- ADR-058: Fold realtime into API (SSE on the API)
- ADR-064: Card plugin contract (`stationTz` prop)
- weewx 5.3 devnotes §Time: UTC storage, OS timezone dependency
- IANA TZ database: https://www.iana.org/time-zones
- `Intl.DateTimeFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat
