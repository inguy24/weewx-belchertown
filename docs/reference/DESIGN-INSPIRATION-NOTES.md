# Design Inspiration Review Notes

Source material for [ADR-009 — Design direction](../decisions/INDEX.md). Process: user reviews each reference and captures reactions; Claude does an independent analysis pass after all four refs are reviewed; the combined notes feed the ADR-009 draft.

## Process limitation

These references are static design shots, not live sites — review is from images alone. No interaction model can be evaluated; no responsive behavior is shown for any of them. Mobile/tablet behavior is inferred or marked as "not shown."

---

## Ref 1 — Dribbble shot 20030403 ("Weather Forecasting Website")

**URL:** https://dribbble.com/shots/20030403-Weather-Forecasting-Website

**User reaction (reviewed 2026-05-01):**

- **Left nav menu:** OK, not strong feelings. Not bad, not exciting. Items in the menu (Home / Forecast / Locations / Analytics / Calendar / Settings) are not the right *contents*, but the **principle of having more in-depth areas so each screen is not cluttered** is **good** — splitting content across pages instead of cramming one page is the right direction.
- **Overall feel:** clean, not overbearing — positive.
- **Mobile:** not shown, would need a mobile version. Open question.
- **Hero photo graphic (Golden Gate bridge with weather overlay):** **like.** Idea: ship some generic stock photos, but **also let the user drop in their own** (within constraints — aspect ratio, file size, format, etc.).
- **Purple color scheme:** not thrilled. Easily swappable to blue or similar — palette is not load-bearing here.

---

## Ref 2 — Dribbble shot 14096604 ("Weather dashboard")

**URL:** https://dribbble.com/shots/14096604-Weather-dashboard

**User reaction (reviewed 2026-05-01):**

- **Overall:** pretty cool and clean.
- **Left "hero" panel format:** kind of likes it — vertical column with location → big current temp → condition, city illustration as backdrop. (Distinct from ref 1's left *nav* — this is a left *current-conditions* hero.)
- **Navigation is a problem:** no easy way to page through different screens. Whatever nav exists is not visible enough.
- **Page taxonomy speculation:** "this is a bit more traditional with current observations on one page, I am assuming that forecast would be on another? Maybe graphs on a third?" — confirms preference for multi-page split (already signalled in ref 1).

---

## Ref 3 — Dribbble shot 26311559 ("Weather Website Design")

**URL:** https://dribbble.com/shots/26311559-Weather-Website-Design

**User reaction (reviewed 2026-05-01):**

- **Thumbs down.** Too plain. Excluded from the synthesis.

---

## Ref 4 — Pinterest UISupply / Mindinventory Weather Forecast Dashboard

**URL:** https://www.pinterest.com/pin/uisupply-on-instagram-weather-forecast-dashboard-by-mindinventory-use-hashtag-uisupply-or-tag-uisupply-for-sharing-your-work-design-dribbble--563018697934321/

**User reaction (reviewed 2026-05-01):**

- **Simplified left menu (icon-only nav rail) — really like.** "Slick and cool."
- **Card-based architecture plays well with the design** Claude has been describing (the canonical data model from [ADR-010](../decisions/ADR-010-canonical-data-model.md) maps naturally to cards).
- **Local customization wanted:** ability to drop in locally-shot background images behind the main current-observations card. (Same theme as ref 1 — user-uploadable imagery is recurring signal.)
- **Multi-page assumption:** "I would assume there are other pages, but I cannot explore them." (Third reinforcement of multi-page taxonomy preference, after refs 1 and 2.)

---

## Critique of current Belchertown deployment (weather.shaneburkhardt.com)

**User reaction (reviewed 2026-05-01):**

### Big picture — load-bearing strategic guidance

**"Do not throw the baby out with the bathwater."** Belchertown's *baby* is that it shows a TON of information. **That is the reason weewx users like Belchertown** — they ran their own station to get rich data, and they want it surfaced. The other reference designs (refs 1, 2, 4) are visually appealing but **dumbed down for the masses** — they would miss the mark with the weewx crowd.

**Posture for Clear Skies:** retain all of the information Belchertown shows. Just give it better homes and stop cramming it on one page. Multi-page taxonomy is the answer; the answer is **not** to drop information types.

### What's wrong (current site)

- **SUPER BUSY.** The home page reads like an early-2000s Geocities site. Too much crammed onto one screen.
- **Live updates stop after a short period of time.** Banner says "Live updates have stopped. [CONTINUE LIVE UPDATES]." This is annoying — the data load is small; pausing makes no sense. Clear Skies realtime should not auto-pause, or if it must (e.g., browser-tab-hidden), the threshold should be much longer or driven by `document.visibilityState`.

### What's right (keep these)

- **Real anemometer graphic** (animated wind direction dial with cardinal markings).
- **Webcam / Webcam Timelapse / Radar selector** — three views of "what does it look like outside" in one switchable panel.
- **Sun & Moon panel** (sunrise/sunset, moon phase, % visible).
- **Weather alert banner** — only present when there's an active alert, not a permanent slot.
- **Forecast for the day** belongs on the main page.
- **Charts with adjustable time period** (1h / 3h / 24h / week / month) — like a lot, want to retain the time-period selector pattern.
- **Records and reports** as their own pages "to satisfy the geeks" — extended statistics, history, etc.
- **Recent Local Earthquake** widget. (Open question: where does this data come from? Belchertown skin pulls from USGS GeoJSON feed; crawl should confirm the exact source and refresh policy.)

### Information types observed on home page (from screenshot)

Will be expanded by the crawl. From the screenshot alone:

- Header with site name + top nav (Home, Graphs, Marine Forecast, Records, Reports, About) + units toggle
- Current conditions card: condition icon, temp, feels-like, AQI, hi/low, dew point, humidity, rain, heat index, wind chill, radiation, UV index
- Wind block: cardinal direction, degrees, speed, gust
- Sun & Moon block: sunrise, sunset, phase, % visible, "More Almanac Information" link
- Radar / Webcam / Webcam Timelapse switchable panel with intensity scale
- 7-day Forecast strip: per-day icon, condition text, hi/low, precip prob, wind speed/gust, with 1h / 3h / 24h interval selector
- Weather Record Snapshots: today's hi/low/avg-wind/highest-wind/today's-rain/highest-rate; same for current month
- Recent Local Earthquake widget: timestamp, location, magnitude, distance from station
- "Last 24 Hours / Week / Month" charts (off-screen — present per "View more here" link)

### Idea — customizable page names

User idea: **let the operator define their own page names** for additional information they want to surface (e.g., "Earthquakes", "Extended Forecast", "Marine"). Some pages would be built-in (Home, Records, Reports), but the operator could add named pages and choose which information lives on each. Feeds [ADR-024](../decisions/INDEX.md) (page taxonomy) and [ADR-022](../decisions/INDEX.md) (theming/branding/customization).

### Action item — full content crawl of weather.shaneburkhardt.com

User asked: "I want you to do a full crawl of weather.shaneburkhardt.com so you really understand the full information shown, as I do not want to blow all of this out."

Output: `docs/reference/BELCHERTOWN-CONTENT-INVENTORY.md` — comprehensive enumeration of every information type, widget, chart, configurable interaction, and data source on every page of the live deployment. Becomes the "must retain" checklist for Clear Skies.

### Custom chart capability — must preserve (added 2026-05-01)

User direction: **"We need to make sure we preserve the ability to create custom charts."** Belchertown supports operator-defined custom charts via configuration (the `graphs.conf` file in the skin); documentation exists in the Belchertown github repo (https://github.com/poblabs/weewx-belchertown). This is a power-user feature, but a real one — losing it would alienate the weewx audience that values data control.

User open question: **GUI-managed or config-file-only?** "I know that is more advanced, and that might not all be able to be done in a GUI management, we need to figure that out." Likely answer: tier the surface — basic chart definitions (which fields, what time period, line vs bar) feasible in the configuration UI ([ADR-027](../decisions/ADR-027-config-and-setup-wizard.md)); advanced features (multi-axis, custom aggregations, conditional formatting) remain config-file with the GUI offering "edit raw config" as an escape hatch. Final call deferred to ADR-009 synthesis and follow-up Phase-3 ADRs.

Implications cascade through:
- **API:** must expose fields generically enough to support arbitrary client-defined chart queries (broad observation field access, time-window queries, aggregation parameters).
- **Dashboard:** chart components must accept user-defined chart specs at runtime, not just hardcoded charts.
- **Config system ([ADR-027](../decisions/ADR-027-config-and-setup-wizard.md)):** must persist chart definitions in a stable schema.
- **Configuration UI:** scope decision per above.

---

## Claude independent analysis

*To be filled after all four references have user notes. Single pass, same dimensions: mood, palette, typography, density, info hierarchy, iconography, charts, layout, motion (where evident), specific things to embrace or avoid.*

---

## Combined recommendation

*To be drafted into ADR-009 (Proposed) after the analysis pass.*
