---
status: Accepted
date: 2026-06-10
deciders: shane
supersedes:
superseded-by:
amends: ADR-033, ADR-047
---

# ADR-055: Client data refresh policy — stale-while-revalidate, no visual disruption

## Context

The dashboard polls `/current` (and other endpoints) every 60 seconds to pick up envelope fields not available via SSE (wind averages, barometer trend, scene descriptor). The polling mechanism uses a custom `useApiQuery` hook that sets `loading=true` on every refetch — including background refetches where valid data is already displayed.

~20 card components gate their rendering on `if (loading) return <Skeleton/>`. When a background refetch fires, every affected card blanks out for 1-1.5 seconds while the network request completes, then redraws. This creates a visible "seizure" across 2/3 of the dashboard every 60 seconds — unacceptable for a production weather station display that may run unattended on a wall-mounted screen.

Separately, the scene system (ADR-047) defaults to `daytime: false` before the first `/current` response arrives. This default is pushed into the theme system immediately, causing a flash of dark mode on page load even when the correct theme is light. The real scene data arrives 3-5 seconds later and flips the theme again.

Both problems share a root cause: the UI treats "fetching new data" the same as "no data yet." They require the same policy: **keep showing stale data while fresh data is in flight.**

ADR-033's CLS target (≤ 0.1) is violated by the 60-second blanking. ADR-047's `visible={sceneLoaded}` correctly prevents wrong background photos but did not extend to the theme system.

## Options considered

| Option | Verdict |
|---|---|
| A. Stale-while-revalidate in `useApiQuery` (this ADR) | **Selected.** One hook fix, all consumers benefit. No card changes needed. |
| B. Replace `useApiQuery` with TanStack Query | Over-engineered. Adds a dependency for one behavioral change. TanStack Query's `keepPreviousData` does exactly what option A implements in 5 lines. |
| C. Per-card `data && !loading` checks | Fragile. Every new card must remember the pattern. One missed card = one flickering card. |
| D. Increase polling interval to hide the problem | Doesn't fix it, just makes it less frequent. Still visible on wall displays. |

## Decision

**Stale-while-revalidate is the default behavior for all data fetching in the dashboard.** `useApiQuery` distinguishes between initial load (no prior data) and background refetch (prior data exists):

- **Initial load:** `loading=true`, cards show skeletons. This is the first page load experience.
- **Background refetch:** `loading=false`, `refreshing=true`, cards keep showing stale data. When the fetch completes, data updates in place with no visual disruption.
- **Refetch error:** stale data stays displayed; `error` is set but does not blank the UI. Cards may optionally show a subtle error indicator. The user sees the last-known-good data rather than nothing.

**Theme initialization does not use default scene data.** The theme system (`setDaytime`) is only called when `sceneLoaded=true` (real API data has arrived). Before that, the theme stays as determined by the `index.html` inline script (localStorage preference or OS `prefers-color-scheme`). This eliminates the dark-flash-then-correct-theme sequence on page load.

**Amends ADR-033:** The CLS ≤ 0.1 target now has a concrete enforcement mechanism — the stale-while-revalidate pattern prevents layout shifts from skeleton swaps during background refetches.

**Amends ADR-047:** The scene system's `daytime` default (`false`) is explicitly scoped to the background photo layer only. It must not propagate to the theme system until real scene data arrives.

## Consequences

- **All existing cards benefit automatically.** The `{loading ? <Skeleton/> : <Content/>}` pattern in ~20 components now only triggers skeletons on genuine first load, not on background refetches.
- **New `refreshing` boolean available.** Cards that want a subtle "updating..." indicator can destructure `refreshing` from `useApiQuery`. No card is required to use it.
- **Error during refetch is non-destructive.** Failed background refetches leave stale data visible. This is the correct behavior for a weather dashboard — showing 60-second-old data is better than showing nothing.
- **Theme flash eliminated.** First-time visitors see OS-preference-based theme instantly (from `index.html` inline script), then the correct scene-based theme once the API responds. No intermediate dark-mode flash from `SCENE_DEFAULT`.
- **Wall-display use case supported.** Unattended displays no longer flash every 60 seconds.

## Acceptance criteria

- [ ] `useApiQuery` returns `loading=true` only when `data` has never been populated. On background refetches with existing data, `loading` stays `false`.
- [ ] `useApiQuery` exposes a `refreshing: boolean` field that is `true` during any in-flight request (initial or background).
- [ ] No card component shows a skeleton during a background refetch (verified by watching the dashboard for 2+ minutes after initial load).
- [ ] On page load, the theme does not flash between dark and light modes before the first API response arrives (verified by loading the page in a browser with OS preference set to light).
- [ ] TypeScript compiles cleanly (`tsc --noEmit` passes).
- [ ] CLS measured via Lighthouse on the Now page stays ≤ 0.1 during a 2-minute observation window.

## Implementation guidance

### `useApiQuery.ts` — stale-while-revalidate

Track whether data has been received at least once via a ref. Only set `loading=true` on the initial fetch (when the ref is false). On subsequent fetches, set `refreshing=true` instead. Return both `loading` and `refreshing` in the result.

### `app-layout.tsx` — theme flash prevention

Gate `setDaytime(scene.daytime)` on `sceneLoaded`:

```tsx
useEffect(() => {
  if (sceneLoaded) {
    setDaytime(scene.daytime);
  }
}, [scene.daytime, sceneLoaded, setDaytime]);
```

### Files affected

- `src/hooks/useApiQuery.ts` — add `hasDataRef`, `refreshing` state, conditional loading logic.
- `src/components/layout/app-layout.tsx` — gate `setDaytime` on `sceneLoaded`.

### Out of scope

- SSE reconnection behavior (already handled by `useSSE` with auto-reconnect).
- Per-card "last updated" timestamps (future enhancement, not required for this fix).
- Replacing `useApiQuery` with TanStack Query (not justified for this change alone).

## References

- Amends: [ADR-033](ADR-033-performance-budget.md) (CLS enforcement), [ADR-047](ADR-047-background-system.md) (scene default scoping)
- Related: [ADR-023](ADR-023-light-dark-mode-mechanism.md) (theme mechanism), [ADR-041](ADR-041-realtime-bff.md) (unit conversion / SSE)
