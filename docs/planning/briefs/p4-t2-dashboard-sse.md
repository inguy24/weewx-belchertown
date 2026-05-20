# P4-T2 Brief — Wire Dashboard to Live SSE Updates

**Teammate:** dashboard-dev (Sonnet)
**Repo:** `weewx-clearskies-dashboard` (branch: `main`, HEAD: `7a582f5`)
**Deliverable:** EventSource client that receives real-time weewx loop packets and updates the Now page without full-page refresh.

---

## 1. What to build

Add an SSE (Server-Sent Events) client to the dashboard that connects to the clearskies-realtime service's `GET /sse` endpoint. When a `loop` event arrives, update the current-conditions state on the Now page in real time.

Keep all existing data-fetching hooks unchanged — SSE supplements them, it does not replace them.

## 2. SSE contract (from clearskies-realtime)

| Property | Value |
|---|---|
| Endpoint | `GET /sse` (on the realtime service, separate from the API) |
| Event type | `loop` (named event — use `addEventListener("loop", ...)`, NOT `onmessage`) |
| Data | JSON-serialized weewx loop packet, raw pass-through |
| Field names | weewx observation names: `outTemp`, `windSpeed`, `windDir`, `barometer`, `outHumidity`, `dewpoint`, `rainRate`, `dayRain`, `windGust`, `heatindex`, `windchill`, `UV`, `radiation`, `dateTime`, etc. |
| Reconnect | No `retry:` field — browser EventSource default backoff (~3s) |
| Replay | None — new connections get the next packet, not the most recent |
| Auth | None (reverse proxy handles per ADR-008/037) |

**Critical:** The event type is `loop`, a named event. `EventSource.onmessage` only fires for unnamed events. You MUST use `addEventListener("loop", handler)`.

## 3. Files to create

### `src/hooks/useSSE.ts` — SSE connection hook

Responsibilities:
- Accept the SSE URL (from config/env)
- Open a native `EventSource` connection (no new npm dependencies)
- Listen for `"loop"` events, parse JSON data
- Expose the latest parsed packet as state
- Skip connection entirely when mock mode is active (`isMockMode()`)
- Clean up (close EventSource) on unmount
- Expose a connection status (connected / connecting / disconnected) for optional UI indicator

### `src/hooks/useRealtimeObservation.ts` — merged observation hook

Responsibilities:
- Call `useObservation()` internally for initial load from `GET /current`
- Call `useSSE()` for real-time updates
- When an SSE packet arrives, map weewx field names to the `Observation` type fields and merge into the current observation state
- Return the same `{ data, loading, error }` shape as `useObservation` so the Now page swap is seamless
- The merge is a shallow overlay: SSE fields overwrite matching Observation fields; fields not in the SSE packet stay unchanged

**Field mapping:** Read `src/api/types.ts` to find the `Observation` interface. Then read the API's `/current` endpoint handler (or the types) to understand what canonical names map to which weewx names. Build a `WEEWX_TO_OBSERVATION` mapping object. Common mappings:
- `outTemp` → temperature field
- `windSpeed` → wind speed field
- `windDir` → wind direction field
- `barometer` → barometer/pressure field
- `outHumidity` → humidity field
- `dewpoint` → dewpoint field
- `heatindex` → heat index field
- `windchill` → wind chill field
- `rainRate` → rain rate field
- `dayRain` → day rain field
- `UV` → UV field
- `radiation` → solar radiation field
- `dateTime` → timestamp field

Derive the EXACT field names from the `Observation` type. Do not guess.

## 4. Files to modify

### `src/routes/now.tsx`

- Replace `useObservation()` call with `useRealtimeObservation()`
- No other changes needed if the return shape matches

### `src/config/` or env setup

- Add `VITE_SSE_URL` env var — the base URL for the realtime SSE endpoint
- Default value: empty string (SSE disabled when not configured)
- When set, value should be the full URL to the SSE stream, e.g. `http://192.168.2.113:8765/sse`

### `vite.config.ts`

- Add a dev proxy rule for the SSE path. Read the existing proxy config to find what port the API uses, then add a SEPARATE proxy entry for `/sse` pointing to the realtime service. The realtime service runs on a **different port** than the API — check the realtime service's default (8765) vs whatever the API proxy currently targets. If both point to 8765, investigate which is correct.
- Keep existing `/api` proxy unchanged

### `.env.example` (or equivalent)

- Document the new `VITE_SSE_URL` variable

## 5. What NOT to change

- `useApiQuery.ts` — leave the generic fetch hook alone
- `useWeatherData.ts` — don't modify existing domain hooks
- Mock data files — SSE is simply skipped in mock mode
- Any non-Now pages
- No new npm dependencies — use native `EventSource` API

## 6. Edge cases to handle

- **SSE URL not configured:** Don't attempt connection. `useRealtimeObservation` falls back to pure `useObservation` behavior.
- **Connection drops:** EventSource auto-reconnects. No manual retry logic needed.
- **No initial data from /current:** Show loading skeleton as today. SSE updates apply once first observation loads.
- **Unknown fields in SSE packet:** Ignore fields not in the mapping. weewx packets carry many fields the dashboard doesn't display.
- **dateTime handling:** weewx `dateTime` is a Unix epoch integer (seconds). Convert to match whatever timestamp format the Observation type uses.
- **Unit mismatch (IMPORTANT):** SSE sends raw weewx loop packet data with NO transformation. The API's `/current` endpoint likely applies field renaming AND unit conversion before returning an `Observation`. Before building the mapping, compare a sample raw loop packet's field names and values against the `Observation` type. If the API normalizes units (e.g., weewx sends °F but Observation expects °C), the SSE mapping must apply the same conversion. If you cannot determine the conversion, document the gap and use SSE data only for fields where units are known to match (timestamps, dimensionless values like humidity percentages).

## 7. Testing expectations

Write tests in the dashboard's existing test framework for:
- `useSSE`: mocks `EventSource`, verifies it listens for `"loop"` events, parses JSON, cleans up on unmount, skips in mock mode
- `useRealtimeObservation`: verifies initial data from useObservation, verifies SSE overlay merges correctly, verifies field mapping
- No E2E/browser tests needed — those come in T6 polish

## 8. Constraints

- **Bundle budget:** Currently 96 KB / 200 KB. No new dependencies, so impact should be minimal. Report the new bundle size after build.
- **DCO:** Sign all commits with `-s`. Use `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`.
- **Branch:** Work on `main` directly (single-dev repo, no PR workflow yet).

## 9. Verification

After implementation:
1. `npm run build` succeeds with no errors
2. `npm run lint` passes (if configured)
3. Tests pass
4. Report new bundle size (gzipped)
