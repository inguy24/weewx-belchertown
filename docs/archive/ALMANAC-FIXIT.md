# Almanac Page Fix-It Tracker

**Status:** COMPLETE — All items (ALM-001 through ALM-004) resolved. Archived 2026-06-27.

Tracks UI bugs and issues discovered on the almanac page during review.

Last updated: 2026-06-27

---

## Open Items

### ALM-001: Moon arc marker — shadow circle separates from main circle

**Problem:** The moon position marker on the sun/moon arc (`SunMoonDetailCard.tsx`) is drawn as two overlapping SVG circles: a filled moon-colored circle (the illuminated disc) and a smaller offset circle (the crescent shadow). At certain arc positions, the two circles visually separate into distinct shapes instead of compositing into a single crescent moon.

Two bugs cause the separation:

1. **Vertical offset on shadow circle.** Line 558: `cy={moonMarker.y - (isMobile ? 2.5 : 1.5)}` — the shadow is shifted 1.5px (desktop) or 2.5px (mobile) above the main circle's center. Should be `cy={moonMarker.y}` (same center).

2. **Shadow radius smaller than main circle.** Line 559: shadow `r={isMobile ? 9.5 : 5.5}` vs main circle `r={isMobile ? 12 : 7}`. The shadow doesn't fully cover the disc, leaving a visible sliver. Should match: `r={isMobile ? 12 : 7}`.

The phase visualization below the arc (lines 657–662) does it correctly: same `cy` for both circles, same radius. The arc marker should match that pattern.

**Fix:** Set shadow circle `cy={moonMarker.y}` and `r` to match the main circle (7 desktop, 12 mobile).

**File:** `repos/weewx-clearskies-dashboard/src/components/almanac/SunMoonDetailCard.tsx` — lines 556–562

---

### ALM-002: Planet outlook top icons too small and uniformly sized

**Problem:** In the PlanetTimelineCard top section (the planet info row above the Gantt chart), all planet images render at a uniform 56×56px maximum (`maxHeight: '56px', maxWidth: '56px'` at line 373, inside a 60×60px container at line 367). Jupiter looks the same size as Mercury, which is visually misleading.

The Gantt chart below already has correct proportional sizing via `PLANET_CHART_IMG_SIZE` (lines 72–80): Saturn 60, Jupiter 40, Mars 32, Venus/Uranus/Neptune 28, Mercury 22. The top section needs a similar size-differentiation map, scaled up for the larger display context.

**Fix:** Add a `PLANET_TOP_IMG_SIZE` map with proportionally larger values (e.g. Saturn ~100, Jupiter ~80, Mars ~56, Venus ~52, Mercury ~44). Replace the uniform 56×56 `maxHeight`/`maxWidth` in `PlanetColumn` with per-planet sizes from this map. Update the container `div` dimensions to accommodate the largest size.

**File:** `repos/weewx-clearskies-dashboard/src/components/almanac/PlanetTimelineCard.tsx` — lines 364–379 (PlanetColumn image rendering), lines 72–84 (existing chart size map for reference)

---

### ALM-003: Solar eclipse card footer note — wrong surface treatment

**Problem:** The SolarEclipseCard uses `<CardFooter>` (line 602) for its info note ("Visibility can vary based on cloud cover…"). `CardFooter` renders with `bg-muted/50` and `border-t` — an opaque muted strip that doesn't match the card's glass surface treatment over the sky background. The footer looks flat and disconnected from the rest of the card.

The LunarEclipseCard (line 660–668) and PlanetTimelineCard (line 998–1001) both place their equivalent footer notes inside `<CardContent>` as a simple `<p>` element — they sit within the card's glass surface and look correct.

**Fix:** Replace `<CardFooter>` with a `<p>` inside `<CardContent>`, matching the pattern used by LunarEclipseCard and PlanetTimelineCard. Keep the `<Info>` icon and text styling.

**File:** `repos/weewx-clearskies-dashboard/src/components/almanac/SolarEclipseCard.tsx` — lines 601–614

---

### ALM-004: Meteor showers lists showers that cannot be seen from operator's latitude

**Problem:** The meteor shower card displays all showers from the catalog regardless of whether they're geometrically visible from the operator's location. The API (`services/almanac.py:1378`) computes `radiantAltitudeDeg` at local midnight from the operator's latitude and tags showers below the horizon as `viewingQuality: "Not Visible"`, but still includes them in the response. The dashboard (`MeteorShowerCard.tsx:186`) renders them with a red "Not Visible" label. Showing showers that can never be seen from the operator's geography is confusing — it clutters the card with irrelevant entries.

**Root cause path:**
- Catalog: `data/meteor_showers.py` — 12 showers with `radiant_dec_deg` values ranging from -16.4° (Southern Delta Aquariids) to +76° (Ursids).
- API: `services/almanac.py:1280-1407` — `compute_meteor_showers()` receives `lat`, computes radiant altitude via Skyfield at local midnight. Lines 1378-1379: `if radiant_alt < 0: viewing_quality = "Not Visible"` — tagged but not filtered.
- Dashboard: `MeteorShowerCard.tsx:186` — `isNotVisible = shower.viewingQuality === 'Not Visible'` — renders with red text, no exclusion.

**Fix:** Add a `min_radiant_alt` query parameter to `GET /api/v1/almanac/meteor-showers`. The API already computes `radiantAltitudeDeg` per shower — this parameter tells it to exclude showers below the threshold. The API does the filtering work; the dashboard chooses the policy by passing `min_radiant_alt=0` in its request.

This keeps the API general-purpose (a different consumer could pass `-10` to include showers just below the horizon) while letting the card designer decide what's worth showing.

**Files:**
- API endpoint: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/almanac.py` — add `min_radiant_alt` query param, pass to service
- API service: `repos/weewx-clearskies-api/weewx_clearskies_api/services/almanac.py` — lines 1378-1402, `continue` when `radiant_alt < min_radiant_alt`
- Dashboard: `repos/weewx-clearskies-dashboard/src/components/almanac/MeteorShowerCard.tsx` or `src/api/client.ts` — pass `min_radiant_alt=0` in the fetch call
