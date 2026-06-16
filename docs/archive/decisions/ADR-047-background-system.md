---
status: Archived — consolidated into DESIGN-MANUAL.md
date: 2026-05-30
deciders: shane
supersedes:
superseded-by:
---

# ADR-047: Background system — condition-keyed photo backgrounds + precipitation glass overlays (A2)

## Context

Track A2 of the UI redesign ([UI-REDESIGN-PLAN.md](../planning/UI-REDESIGN-PLAN.md)). Directional
decisions (2026-05-28): backgrounds are **photographic** (not illustrated), **layered** (soft base +
crisp foreground effect), **operator-replaceable** over a shipped default set, and keyed by
**condition × time-of-day** (night = real night imagery, e.g. Milky Way, not a darkened blue sky).

The approach was validated in a working browser prototype the operator reviewed and accepted:
[docs/design/mockups/background-prototype.html](../design/mockups/background-prototype.html). This ADR
records what that prototype settled, plus the data-mapping and server/client split needed to drive it
from live conditions.

**Assets (in `Graphics/Backgrounds/`, plus the wizard's `sky.jpg`):** 5 scene photos (clear/cloudy/
storm × day/night where the blue-sky `sky.jpg` is clear-day) + 2 real "on glass" photos
(`rain_on_glass.jpg`, `snow_on_glass_transparent.png`).

**Reconciles ADR-009 §Hero tension** (flagged in plan A0): ADR-009 specified a *Now-page-only* hero
image (default in-house SVG, operator-uploadable, event-triggered). This ADR makes the background a
**global, condition-keyed photographic layer behind every page**. For the background role it
supersedes ADR-009's Now-only SVG-default approach; ADR-009's event-trigger richness (alert/season/
date-range overrides) folds into the operator-replaceable set as future config scope.

## Options considered

| Option | Verdict |
|---|---|
| Animated CSS/canvas rain drops over the scene | Rejected — operator found it distracting and fake; drops aren't perfectly spherical. |
| WebGL/PixiJS displacement (per a Gemini suggestion) | Rejected — heavy dependency for decoration; contradicts the tight bundle budget (ADR-033); unnecessary. |
| **Static: blurred scene photo + real "on-glass" photo blended on top** | **Selected.** Real droplets/frost, no animation, no dependencies, cheap. |
| Background keyed by **theme** (light/dark) | Rejected — a user can force dark mode at noon; background must match reality. |
| Background keyed by **actual sun position** (sunrise/sunset) | **Selected.** Background reflects what's actually outside, independent of the theme toggle. |
| Client computes "is it raining + for how long" | Rejected — page reload loses the timer; viewers disagree. |
| **Server (realtime) computes the scene + precip linger** | **Selected.** Survives reloads; consistent for all viewers; weather logic stays server-side. |

## Decision

1. **Two static layers.** Base = the scene photo, **blurred 3px** while a precipitation overlay is
   active (enough to sell "looking through glass" while the scene stays readable). Overlay = a real
   on-glass photo. **Blend mode is per-overlay: rain = `overlay`** (flat-field photo, keeps the field
   neutral) **; snow = `screen`** (transparent frost cutout). Overlay opacity **75% day / 25% night**.

2. **Background photo = sky bucket × day/night.** The conditions engine's 5 sky labels bucket as:

   | Sky label(s) | Bucket | Day | Night |
   |---|---|---|---|
   | Clear, Mostly Clear, Partly Cloudy | clear | `sky.jpg` | clear_night |
   | Mostly Cloudy, Overcast | cloudy | cloudy_day | cloudy_night |
   | (provider) Thunderstorm | storm | storm_day | storm_night |
   | Foggy | → **cloudy** (no fog photo) | cloudy_day | cloudy_night |
   | none / unknown / startup | → **clear** (fallback) | `sky.jpg` | clear_night |

3. **Snow and storm come from the forecast provider's current conditions**, not local gauges — a PWS
   can't gauge snow, and local storm classification is harder than this ADR's scope. Snow = provider
   `precipType` ∈ {snow, sleet, freezing-rain}; storm = provider current-conditions text = thunderstorm.

4. **Precipitation overlay = rain | snow | none**, independent of the background bucket (rain can ride
   on a cloudy *or* storm photo). It turns on the moment precip is detected and **lingers for 15
   minutes after the last detection** (wet/frosted glass doesn't vanish instantly), computed in the
   **API**. Snow wins over rain when both qualify.

5. **Day/night = real sun position** (almanac sunrise/sunset — the same signal the dashboard already
   computes for auto-sunrise-sunset theming), NOT the theme toggle.

   **Amendment (2026-06-03):** When the user explicitly selects Light or Dark mode (not System),
   the background's daytime flag follows the theme toggle (Light → day variant, Dark → night
   variant). System mode follows almanac as before. Sky and overlay fields always reflect actual
   weather conditions regardless of theme choice. This override is applied client-side in
   `AppLayout` — the API still emits the almanac-based `scene.daytime` unchanged.

6. **Server emits a small structured `scene` descriptor; the dashboard just maps it to assets.** No
   client-side string-parsing of the conditions sentence, no weather logic in the dashboard. Shape:
   `scene: { sky: "clear"|"cloudy"|"storm", daytime: bool, overlay: "rain"|"snow"|null }`. **All three
   fields are computed server-side** — `daytime` from almanac sunrise/sunset (§5), not recomputed on
   the client.

7. **Operator-replaceable** over the shipped default set. Each asset carries an **optional attribution
   string**, rendered small and unobtrusive in a screen corner when present (shipped scene photos
   credit their photographers; the blue-sky default and any un-credited asset show nothing). The
   operator **upload/storage/serving mechanism is a separate config ADR** (deferred here).

## Consequences

- **API** grows: a `scene` builder (sky-bucket + provider snow/storm + sun day/night),
  the 15-minute precip-linger timer (server state), and new `scene` fields on the `/current` payload
  + SSE stream.
- **Dashboard** grows: a global background layer (blurred base + screen-blended overlay) behind the
  existing translucent cards, an asset map (scene tag → image + attribution), and the corner
  attribution element. No animation; nothing for `prefers-reduced-motion` to disable.
- **Assets** must be downscaled (~2400px) + compressed before shipping — the operator's transparent
  frost PNG is 16 MB; full-res decorative art would blow the page-weight budget (ADR-033).
- **ADR-009 §Hero** must be edited (after this ADR is Accepted) to point its background role here.
- Trade-off: storm/snow accuracy is only as good as the provider's current-conditions feed; stations
  with no forecast provider configured degrade gracefully to clear/cloudy with no storm/snow scenes.

## Acceptance criteria

- [ ] Every one of the 5 sky labels, plus Foggy and the none/unknown case, maps to a defined
      background per the table; no condition produces a blank background.
- [ ] Snow and storm scenes are driven by provider current-conditions fields (verified the fields are
      actually populated at runtime, not just modeled).
- [ ] Rain/snow overlay appears on detection and is still present 14:59 after the last detection and
      gone by 15:01 (server-side timer; survives a dashboard reload).
- [ ] Day/night follows almanac sunrise/sunset and is correct when the theme is manually overridden
      to disagree with the time of day.
- [ ] `/current` and the SSE stream carry the `scene` descriptor; the dashboard selects assets from
      it without parsing the conditions text.
- [ ] Visual params match the locked values: 3px base blur under an active overlay, per-overlay blend
      (rain = `overlay`, snow = `screen`), 75% day / 25% night overlay opacity.
- [ ] Body/card text meets WCAG AA contrast over **every** shipped background in both themes
      (B3 gate, [ADR-026](ADR-026-accessibility-commitments.md)); a darken-scrim is applied where needed.
- [ ] Each shipped background + overlay is **≤ 300 KB** (~2560px longest edge, WebP) after downscale.
- [ ] Attribution renders for the 5 credited scene photos and is **absent** (not an empty box) for the
      blue-sky default and both on-glass overlays (which carry no credit).

## Out of scope
- Operator upload / storage / serving mechanism for replacement backgrounds → **separate config ADR**.
- ADR-009 event-trigger overrides (alert/season/date-range/time-of-day hero binding) → future.
- Lightning-sensor-assisted storm detection → conditions-engine improvement, tracked in
  [CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md) backlog.

## References
- Plan: [UI-REDESIGN-PLAN.md](../planning/UI-REDESIGN-PLAN.md) A2.
- **Implementation recipe + preserved code:**
  [background-system-implementation-notes.md](../design/background-system-implementation-notes.md)
  (exact CSS values, asset→slot map, asset-prep scripts).
- Prototype: [docs/design/mockups/background-prototype.html](../design/mockups/background-prototype.html).
- Asset-prep scripts: [scripts/asset-prep/](../../scripts/asset-prep/).
- Reconciles: [ADR-009 §Hero/§Color](ADR-009-design-direction.md).
- Inputs/honors: [ADR-044](ADR-044-sky-condition-classification.md) (sky labels, precip),
  [ADR-041](ADR-041-realtime-bff.md) (API computes, dashboard renders),
  [ADR-023](ADR-023-light-dark-mode-mechanism.md) (almanac day/night),
  [ADR-033](ADR-033-performance-budget.md) (image weight), [ADR-026](ADR-026-accessibility-commitments.md).
