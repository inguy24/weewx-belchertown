# UI Inspiration — Notes & Analysis

Source: Pinterest board `burkhardt0989/current-conditions` (28 pins, pulled 2026-05-28) +
operator-added references.
Raw images live in [raw/](raw/) as `img-00.jpg` … `img-28.*`.

## How this doc works

We walk the images **one at a time**. For each: Claude Reads the file (loads the actual
pixels fresh), we discuss it, and the conclusions get written into that image's section
below. The image itself does not need to survive in context — the file on disk is
re-readable anytime, and the written notes are the permanent record.

**Status legend:** ☐ not yet discussed · ◐ in progress · ☑ done

**⚠️ Guiding caution:** These pins are **inspiration, not templates to copy verbatim** — extract
the *elements/principles*, don't clone any single design (esp. branded ones like AccuWeather/BBC).
Some things the current site already does fine; only change what's actually weak.

---

## SYNTHESIS (post-walk, 2026-05-28)

### Locked design direction (consistent across many pins)
1. **Full-bleed condition-keyed background** behind everything; refined to a **layered** base
   atmosphere + crisp foreground weather-effect (rain-on-glass, etc.). Operator-replaceable for
   sense of place.
2. **Translucent (never opaque) cards/tiles** floating over that background.
3. **Modular, uniform tiles on a fixed grid** (NOT organic blobs) — see MAJOR DIRECTION.
4. **Two coordinated icon families:** bold/illustrative for hero weather; thin/demure for stats.
   **Every stat gets an icon.**
5. **Oversized temperature + plain-language conditions sentence** (and per-stat context sentences).
6. **Gauges where they earn it:** ⭐ wind compass (loved, signature), radial dials for bounded
   stats (humidity/pressure), per a metric-by-metric audit.
7. **Temperature trend line** — today's-curve along the bottom of current conditions (model=img-23)
   AND a connecting line through the forecast columns/weekly.
8. **Forecast = icon-rich columns**, time-range tabs, (data-permitting) expandable columns.
9. **Sun + Moon arcs** (moon gets its own arch) + moon phase → almanac/front page.
10. Quick wins on the current site: **radar legend/key**, **per-stat icons**, **better wind viz**.

### FORKS — RESOLVED (2026-05-28)
- **Theme:** ✅ **Support dark mode** (light + dark). Implication: condition backgrounds need a
  **dark-mode variant set** — e.g. clear sky = Milky Way / starry night instead of blue-sky cumulus.
  So backgrounds are keyed by **condition × theme**.
- **Backgrounds:** ✅ **Photographic** (not illustrated). Committed.
- **Per-metric treatment:** ✅ **Mixed by metric** — "doesn't have to be one answer." Some stats
  text, some dial/gauge, some curve. Decide via the per-metric audit (#5).

### Card sizing now (grid-forward, but NOT building the grid yet)
- For NOW: **fixed cards**, but **design each card to sizes compatible with the future 4-col grid**
  (1/2/3/4-col-wide footprints, sensible row heights) so cards DON'T need redesign when the
  customizable grid lands later. No grid engine / drag-resize / persistence work now.

### Self-audit — tensions & risks to manage
- **Density tension:** user loves rich gauges/curves but also flagged "too much info" (img-18).
  Mitigate via per-metric audit + progressive disclosure (expandable columns), not maximal everything.
- **Customizable grid is a large build** (layout engine + per-operator persistence + responsive
  collapse). Real scope; needs its own ADR(s) and probably a phased rollout (static grid first,
  drag/resize later).
- **Provider data gates features:** expandable forecast columns + per-pollutant AQI depend on what
  providers actually return — verify before designing.
- **Legibility/perf:** layered photos + translucent cards + chart backgrounds risk text-contrast
  and performance problems. Need contrast floors (accessibility) and image-weight budget.
- **Two icon families** must stay visually coherent — mismatch risk; pick them together.
- **Don't clone verbatim** (IP + originality) — extract principles.

---

## Element-axis summary (filled in as we go)

Each line tracks an element and which images reinforced it. When the same move recurs
across several liked pins, it's a real signal — not a one-off. `[imgs: …]` lists the
images that voted for it.

- **Iconography** — **BLEND TWO ICON STYLES BY CONTEXT** (key refinement):
  - **Hero weather icons** (current conditions + forecast condition icons) → **bolder/illustrative** style.
  - **Stats / text blocks** (wind/pressure/humidity/dew point/etc.) → **demure, thinner line icons** (cf. img-10, img-11).
  → icon-set hunt = find **two coordinated families** (bold weather + thin utility) that pair well.
  - **An icon for EVERY stat** to break up text & make detail blocks digestible — current site lacks this (img-10).
  - Likes **thicker/filled, illustrative** icons + their hierarchy for the hero set (imgs 01, 02)
  over thin line-art (img-00). DECISION DEFERRED: don't pick style pin-by-pin — Claude will
  assemble candidate **icon sets** for side-by-side comparison after the walk.
  `[imgs: 00 (thin), 01 (thicker, preferred), 02 (icons+hierarchy liked), 04 (thin line-art — disliked)]`
- **Backgrounds** — **full-scene image behind everything** is strongly liked. Plan:
  **condition-keyed stock backgrounds** — "clear skies" (likely reuse the one already on the
  site), "cloudy", "rainy", "stormy", etc. — swapped to match current conditions. `[imgs: 00, 01, 02]`
  - **STANDOUT (img-02):** *two layered backgrounds* — a base cloud/sky layer (can be soft)
    **plus a sharp, un-blurred foreground "weather effect" layer on top** (raindrops-on-glass).
    Generalize: each condition = base atmosphere + crisp foreground effect (rain, snow, etc.).
  - **FEATURE (img-05):** background images should be **operator-replaceable**. Ship a
    **generic default set** (generic storm = plain sky shot) that anyone can use, but let the
    operator override each condition with **their own local imagery** (e.g. iconic pier in a
    storm) for a **sense of place**. → graduate to plan/ADR (config + asset handling). See deferred items.
- **Data-viz / charts** — likes **precip rendered as droplet icon + % chance** (imgs 01, 02).
  **Hourly forecast row** (per-hour column: icon/temp/precip%/wind) liked as the **forecast
  screen** layout (img-02). **Wind = a circle with a direction arrow + speed number inside**
  (liked). **Temperature-range gradient bar** (low→high w/ dot marker, yellow→orange) liked
  for the **daily** forecast — BUT only works in a **vertical** row layout, not horizontal (img-04).
  **"Today's temperature curve"** — likes the *idea* of a horizontal temp trend curve (img-05)
  but NOT that execution; wants a curve chart of the **current day's temperature** built into the
  **current-conditions** view (today's trend), not a decorative line through a daily strip.
  ⭐ **MODEL = img-23**: temp day-curve w/ gradient fill (teal→orange), dashed-past/solid-future
  + "now" divider, H/L markers, Actual/Feels-Like toggle. Placement: **along the bottom of the
  current-conditions area**. (Resolves the img-05 want — liked the idea, this is the execution.) `[imgs: 01, 02, 04, 05, 23]`
  **Temp trend LINE through the forecast columns** — endorsed (img-15): a line connecting the
  actual forecast-column temps reads as "neat & helpful" (vs. img-05's decorative wavy line,
  which was disliked). Two homes: today's-trend in current conditions + connecting line across
  forecast columns. img-24 reinforces: weekly forecast as a connected dot-line trend (dot at temp
  height + connecting line + day + icon). Reinforced again by img-26 (subtle trend line through
  the hourly row). `[imgs: 15, 24, 26]` (3 votes; locked.)
  **Radar tile needs a KEY/legend** — img-15's radar has a color-scale legend; **our current
  site's radar lacks one** — add it. `[imgs: 15]`
  **Air Quality card** — detailed AQI with **per-pollutant breakdown** + colored severity scale,
  liked (img-15). CAVEAT: verify provider AQI data depth (see deferred item). `[imgs: 15]`
  **Background images behind CHARTS** — likes the idea of a scenic image behind plotted chart
  data (img-27). Charts = **Recharts** (per ARCHITECTURE.md); verify Recharts can render an
  image behind the plot area — VERIFY (deferred). `[imgs: 27]`
  **Sun & Moon arc** — sunrise→sunset arc w/ sun position marker; want a **matching moon arch**
  (moonrise/moonset) + moon phase, for the almanac/front page (img-11, img-14). `[imgs: 11, 14]`
  **Radial dial / ring gauge** for bounded 0–100 stats (esp. humidity) — liked (img-14). OPEN
  PRINCIPLE: decide per-metric whether a value is better as **plain text** or a **dial/gauge**;
  a dial conveys bounded values at a glance, text is cleaner for unbounded/precise ones.
  Dials confirmed to "really help" when applied across stats (img-15). `[imgs: 14, 15]`
  **WIND COMPASS DIAL — ⭐ HIGH PRIORITY / LOVED** (img-17): full circular compass w/ tick rim,
  cardinal labels, direction indicator, big speed (kts), degree+cardinal ("356° NORTH"), gust
  callout. User "LOVES everything about this card"; current site's wind looks "old-fashioned &
  too simplistic." KEY: the dial is an **information container** — degree, cardinal, speed AND
  gust all live INSIDE the circle, making it a prominent feature element, not a bare gauge.
  TWO wind treatments: this **prominent compass** (current/marquee) + the small
  **wind-circle-with-arrow** (compact forecast rows). `[imgs: 17]`
- **Layout & cards** — **translucent card** holding the data over the background image,
  confirmed liked. KEY: cards must be **translucent, NOT fully opaque** (img-04). Cards also
  work for **forecast sections** (hourly card + daily card), not just current conditions. `[imgs: 00, 04]`
  **Card header = simple title + thin underline rule** — clean, liked (imgs 04, 11). `[imgs: 04, 11]`
  **Clean UNIFORM translucent tiles in a grid** — preferred model (img-21), opposite of img-19's
  organic blobs. Each tile = icon + title + value (+ gauge where useful). See MAJOR DIRECTION (grid). `[imgs: 21]`
  **Plain-language context sentence on each stat tile** — "Wind is making it feel colder," "It's
  perfectly clear right now" — turns numbers into meaning (img-21). Liked. `[imgs: 21]`
- **Typography** — **oversized temperature** + tiny qualifier label; bold/large place &
  headline; plain-language conditions sentence. `[imgs: 00, 01]`
- **Color** — muted atmospheric palette behind; light accent for temp; thin colored
  accent bars on the multi-day strip (img-01). `[imgs: 00, 01]`
- **Depth/effects** — optional **subtle drop-shadow on icons** for lift (img-16) — nice-to-have, low priority.
- **Motion** (inferred, since stills) —

### Screens / targets (which screen each element informs)
- **Current-conditions card** — model is img-00 (line-art) refined w/ img-01 icon weight.
- **Almanac** (front page or dedicated almanac screen) — **Sun & Moon arc** viz: sunrise→sunset
  sun arc with current-position marker (img-11), **enhanced so the moon gets its own matching
  arch** (moonrise/moonset). Moon phase display alongside.
- **Forecast screen** — model is the **hourly forecast row** from img-02 (per-hour column:
  icon / temp / precip% / wind). Use as the layout example for the forecast card.
  **img-07 reinforces the forecast-card layout** (clean per-hour columns: time/icon/temp/wind)
  — user wants "something similar to this" structurally, but with nicer graphics/icons swapped in.
  **img-09 reinforces: forecast columns with WIDE use of iconography** (each column stacks
  condition icon + precip droplet + wind circle so data reads visually, not just as numbers).
  **img-12: simplify the forecast page with time-range TABS** (Today / Tomorrow / Week / 2wk / Month),
  and **expandable columns** — click a column to reveal more detail. CAVEAT: verify our data
  **providers** actually return that depth (see deferred item).

### Anti-patterns (explicitly disliked — do NOT do)
- **Simple multi-day "extended forecast" strip** (img-01, img-02 bottom rows) — "too simple."
- **Organic / scalloped / blob tile shapes** (img-19, Material-You style) — prefers cleaner, uniform tiles.

### Carry-through shortlist (the elements that survive across many pins)
_Promote an element here once it's appeared in ~3+ liked images, OR on a strong single love._
- ⭐ **Wind compass dial** (img-17) — LOVED; signature element. Replaces the "old-fashioned" current wind display.
- **Full-scene image behind everything** — imgs 00, 01, 02 (3 votes; locked). Refined to
  *layered* base + crisp foreground effect (img-02).
- **Oversized temperature number** — imgs 00, 01, 02.
- **Plain-language conditions sentence** — imgs 00, 01, 02.
- **Thicker/illustrative icons + clear hierarchy** — imgs 01, 02 (promoted; final set TBD).
- **Translucent (not opaque) data card** — imgs 00, 04; reaffirmed at img-01. Extends to forecast cards.
- **Precip as droplet icon + %** — imgs 01, 02.
- **Wind as circle w/ direction arrow + speed inside** — imgs 01, 02, 07 (3 votes; locked).
- **Icon-rich per-hour forecast columns** (each column stacks condition/precip/wind icons) — imgs 02, 07, 09 (3 votes; locked, for forecast screen).
- **An icon for every stat** in detail blocks (humidity/pressure/wind/dew point/UV/etc.) — img-10; current site gap. Ties to icon-rich theme.
- **Card header: simple title + thin underline rule** — imgs 04, 11 (clean).

### ⭐ MAJOR DIRECTION (think now, build later) — Customizable card GRID home page
Not to be solved during this walk, but it reframes how every card is designed:
- Home page = a **fixed-column grid (4 columns)** with set rows.
- **Cards span 1 / 2 / 3 / 4 columns wide**, and can be **multiple rows tall**.
- **Operator can move & resize cards** to customize their own home page (customizable dashboard;
  implies layout persistence per operator).
- Must define **responsive collapse to mobile** (how 4 cols → fewer/stacked).
- Replaces today's "cram multiple data types into one fixed card" with **modular single-purpose
  tiles** on a grid (img-21 previews what grid cards look like).
- → graduate to Clear Skies plan + ADR(s): grid/layout engine, card size model, operator
  customization + persistence, responsive strategy. HIGH priority among deferred items.

### Deferred action items (do AFTER the image walk)
1. **Icon-set: CONFIRM existing stack choice** — ARCHITECTURE.md already specifies **Weather
   Icons** (bold weather/hero set) + **Lucide** (thin utility set for stats) — which matches the
   two-family insight exactly. So this is largely DECIDED. Remaining work: confirm Weather Icons'
   style/weight satisfies the "thicker/illustrative" preference (it's a line font — may or may not
   feel bold enough); if not, evaluate a richer hero weather set. Verify Lucide covers all stat icons.
2. **Condition-keyed background images** — source stock backgrounds per condition
   (clear / cloudy / rainy / stormy / etc.); check whether the current site's clear-sky
   image can be reused. Present for comparison.
3b. **Verify chart-background support** — confirm Recharts in clearskies-dashboard can
   render a scenic image behind plotted chart data (img-27). Likely yes; verify before relying on it.
5. **Per-metric treatment audit** — for each stat (humidity, UV, pressure, wind, dew point,
   visibility, precip%, temp, etc.) decide its best representation: **plain text vs. radial
   dial/gauge vs. icon+number vs. sparkline**. Dials suit bounded 0–100 values (humidity, UV);
   text suits unbounded/precise ones. Produce a small table during synthesis. Also EXPLORE a
   **"gauge-heavy card" concept** (open question from img-19: if many stats became gauges, what
   would the card look like?) — img-19 only partially gestures at it; most of its tiles disliked.
   Liked the **pressure radial gauge** specifically. INCLUDE UV: user
   likes the bell-curve-w/-severity-gradient direction (img-18) but finds the full version too
   dense, and dislikes the current site's UV line indicator — find a simplified middle ground.
4. **Verify provider data depth** — confirm whether the weather data providers (per-provider
   plugins) actually return enough per-hour / per-day detail to support **expandable forecast
   columns** (img-12). Don't design the expansion UI until data availability is confirmed.
   ALSO: confirm **AQI / air-quality per-pollutant** data depth (img-15) before designing the
   detailed air-quality card.
3. **FEATURE → plan/ADR: operator-replaceable backgrounds.** Generic default image set +
   per-condition operator override (upload/point to custom local imagery for sense of place).
   Needs config UI + asset storage/serving decisions. Graduate from these notes into the
   Clear Skies plan and an ADR when the walk is done.

---

## Per-image notes

### img-00 ☑
_What it is:_ AccuWeather "Toronto Tonight" overnight card — twilight sky photo, frosted
light panel, bold MONDAY / MARCH 21 header, thin line-art moon+cloud+sparkle icon, big
light-blue "-2° Low Temp" with blue underline, plain-language "Partly to mostly cloudy."
_What you like:_ Endorsed as a **model for the Clear Skies current-conditions card** overall.
The combination works: line-art icon + frosted panel over sky photo + oversized temp.
_Steal / skip:_ Steal the whole treatment. (No skips noted.)

### img-01 ☑
_What it is:_ BBC Weather mobile app, Oxford "Next Hour." Full-bleed grey overcast sky,
filled white cloud icon, bold "12°" with stacked secondary stats (3% precip w/ droplet
icon, wind "3"), big plain-language "Light cloud and light winds," green "L" pollution
badge, bottom multi-day strip (Tonight/Sat/Sun/Mon) with thin colored accent bars.
_What you like:_ Icon **thickness** here > img-00's thin line-art (but real choice deferred
to icon-set comparison). The **rain droplet icon + % chance** treatment. Reaffirmed the
**translucent card** + **background image behind everything** ideas.
_Steal / skip:_ Steal: thicker icon weight (pending set comparison), precip droplet+%,
background-image concept. Note: this pin is full-bleed, but user still prefers a card.
### img-02 ☑
_What it is:_ BBC Weather tablet/landscape, Standish. Rain-on-glass background, multi-color
filled icons (cloud+sun+lightning), big 22°/11°, plain-language "Thundery showers and a
gentle breeze," dense hourly row (time/icon/temp/precip%/wind) on the right, multi-day strip
w/ colored bars at bottom, UV badge.
_What you like:_ The **icons + hierarchy**. The **hourly forecast row** as a layout example
for the **forecast screen** (not current conditions). STANDOUT: the **two-layer background** —
soft clouds underneath + a **sharp, un-blurred raindrops-on-glass layer on top**.
_Steal / skip:_ Steal: icon style/hierarchy, hourly-row layout (forecast screen), layered
crisp-foreground background. SKIP: the bottom multi-day extended strip — "too simple."
### img-03 ☑
_What it is:_ Minimal iOS-style "Sunny" screen. Bright blue sky + sun-flare gradient
(full-bleed, no card), yellow filled sun icon, huge "86°", "Sunny / Feels Like 86°",
"Day 87° • Night 56°" footer.
_What you like:_ Reinforces **current-conditions hierarchy + general layout** (no major new
signal — existing card notes already cover it). Also a good **"clear skies" background** ref.
_Steal / skip:_ Reinforcement vote for oversized-temp hierarchy, plain-language, feels-like /
day•night secondary temps, clear-sky background.
### img-04 ☑
_What it is:_ Mobile, Walnut. Partly-cloudy sky background (full-bleed) + two translucent
blue rounded cards: hourly card (plain-language header, thin line-art icons, temps) and
daily card (day · icon+precip% · low · temp-range gradient bar w/ dot · high).
_What you like:_ The **background**. **Translucent cards** (explicitly: translucent NOT
opaque). The **temp-range gradient bar** for daily — but notes it only works **vertically**,
not in a horizontal layout. This daily card is the "richer" answer to the earlier "too simple" gripe.
_Steal / skip:_ Steal: translucent forecast cards, vertical temp-gradient daily rows,
plain-language card headers. SKIP/miss: the thin line-art icons (prefers thicker).
### img-05 ☑
_What it is:_ Desktop glassmorphism dashboard (Dribbble). Full-bleed storm scene (clouds+
lightning over fields), frosted translucent panel, left icon nav rail, "Storm with Heavy Rain"
headline + plain-language paragraph, horizontal daily forecast with a wavy temp trend line,
right column of stacked translucent location cards w/ stat rows (wind/precip/humidity icons).
_What you like:_ Full-bleed background, **translucent tiles**, good hierarchy. The horizontal
temp curve **concept** (not this execution). FEATURE insight: background = sense of **place**,
not just weather → wants operator-replaceable custom imagery over generic defaults.
_Steal / skip:_ Steal: glass/translucent tiles, hierarchy, full-bleed background, the
temp-curve concept (rework it). Want: a **"today's temperature curve" chart inside current
conditions**. SKIP: the specific wavy-line execution here.
### img-06 ☑ — DUPLICATE of img-02
Exact duplicate of img-02 (BBC Weather, Standish, rain-on-glass tablet). No new signal;
not counted again in carry-through tallies.
### img-07 ☑
_What it is:_ Light/flat "Hourly Forecast / Today" widget. Per-hour columns: time · line-art
icon (moon/sun) · temp °F · wind circle (arrow + mph). "MORE" link. No background photo.
_What you like:_ **Layout reference for the forecast cards** — the clean per-hour column
structure. Wants "something similar to this" but with nicer graphics/icons swapped in.
Reinforces the wind circle.
_Steal / skip:_ Steal: per-hour column layout (forecast cards), wind circle. Swap out: these
specific line-art icons (prefers better graphics).
### img-08 ☑ — SKIPPED
Stock vector "Weather Forecast" broadcast graphic (illustrative filled icons + vertical day
cards). User chose to skip — no signal recorded.
### img-09 ☑
_What it is:_ BBC Weather tablet, Romsey, sunny/blue-sky variant. Hourly column row
(time/icon/temp/precip%/wind), multi-day strip, plain language, UV/Pollen/Pollution badges.
_What you like:_ The **forecast layout** — the **column structure with wide/heavy use of
iconography** (each hour column stacks condition icon + precip droplet + wind circle, so the
data reads visually, not just as numbers). Reinforces the icon-rich forecast-card direction.
_Steal / skip:_ Steal: icon-rich per-hour column forecast layout. (Background = clear/blue-sky
reference; UV/Pollen/Pollution badges noted but not pursued.)
### img-10 ☑
_What it is:_ Desktop dashboard over a real LA sunset cityscape photo. Dark translucent glass
panels: location/temp (top-left), time/date (top-right), tabbed forecast + detail stats grid
w/ line icons (humidity/visibility/UV/pressure/wind/dew point), Morning/Afternoon/Evening cards.
_What you like:_ **An icon for every stat** — breaks up text, makes the detail block
digestible (current site lacks this). Good **text hierarchy** (current site already decent here).
Also another real-place photo (reinforces sense-of-place background idea).
_Steal / skip:_ Steal: per-stat icons in the detail block, strong text hierarchy. (Dark-theme
glass + real-place photo also reinforce earlier notes; dark-vs-light theme not yet decided.)
### img-11 ☑
_What it is:_ Dark mobile screen (NY) over blurred dusk-city photo. Sectioned cards: Wind &
Pressure (thin windmill icon, barometer trend), Sun & Moon (sunrise→sunset arc w/ sun position
marker + moon-phase glyph), Precipitation by time-of-day (droplet-fill gauge per %).
_What you like:_ The **wind (windmill) icon**. **Partially** likes the sun arc — wants it
better: **moon should get its own matching arch** (moon rise/set), alongside moon phase.
Placement: **front page or (definitely) the almanac**.
_Steal / skip:_ Steal: windmill wind icon; sun arc + ADD a parallel moon arc for the almanac.
Also liked the **simple card titles with a thin line underneath** — "very clean" (header+rule).
(Droplet-fill precip gauge noted, not emphasized.)
### img-12 ☑
_What it is:_ UNIAN (Poltava) green monochrome site. Big temp + filled rain-cloud icon + time,
full detail stats list (feels-like/min-max/humidity/pressure/wind/precip/sunrise/sunset/
visibility/moon), time-range tabs (Today/Tomorrow/Week/2wk/Month), multi-day columns, hourly
rows w/ thin per-stat icons.
_What you like:_ The **forecast layout**. Idea: **simplify our forecast page with time-range
tabs**. The **expandable columns** (click → more detail). CAVEAT: unsure providers supply that depth.
_Steal / skip:_ Steal: time-range tab navigation, expandable forecast columns (pending data
check). (Monochrome no-photo theme not endorsed; user still in full-bleed-photo camp.)
### img-13 ☑ — DUPLICATE of img-12
Same UNIAN (Poltava) layout as img-12, different data/day. No new signal; not re-counted.
### img-14 ☑
_What it is:_ Huawei weather detail screen, dark blue. COMFORT LEVEL (humidity ring gauge 82%
+ feels-like + UV), WIND (windmill icon + direction/speed), WAXING CRESCENT (moon phase +
sunrise/sunset dashed arc).
_What you like:_ Particularly the **dial/ring gauge for humidity**. Surfaced principle: decide
**per metric** whether text or a dial conveys it better. Reinforces windmill icon + sun arc
(and the "moon needs its own arch" upgrade).
_Steal / skip:_ Steal: radial dial for bounded stats (humidity/UV). Reinforces windmill icon,
sun arc. TODO: per-metric text-vs-dial audit (deferred item #5).
### img-15 ☑
_What it is:_ Dark glassmorphism "bento" dashboard. Many tiles: today/pressure, temp trend
curve, stat dials (wind/feels-like/visibility/precip), AQI card w/ colored scale, hourly row,
widget tile, radar map tile (with legend).
_What you like:_ (1) **Temp trend LINE through the forecast columns** — neat & helpful.
(2) **Dials really help** here. (3) **Air Quality card** — more info, per-pollutant breakdown
(caveat: provider data unknown). (4) **Radar has a KEY/legend** — ours doesn't; add it.
_Steal / skip:_ Steal: temp trend line across forecast columns, stat dials, detailed AQI card
(pending data), radar legend. Provider-data caveats on AQI + forecast depth.
### img-16 ☑
_What it is:_ Minimal frosted-glass widget over raindrops-on-glass bg. "Egypt, Cairo," big 18°,
soft cloud-rain icon, three-stat icon row (wind/humidity/thermometer w/ thin line icons).
_What you like:_ The **subtle drop-shadow on the icons** (adds depth) — but "not necessary,"
a nice-to-have. Otherwise reinforces frosted card + rain-on-glass bg + thin stat icons.
_Steal / skip:_ Optional: icon drop-shadow (low priority). Reinforcement of locked elements.
### img-17 ☑ — ⭐ LOVED
_What it is:_ "Current Wind" compass card, dark blue. Circular compass dial (tick rim, N/W/E
labels, yellow direction indicator), center "356° NORTH," huge "39.8 kts," "Wind Gust 48.3 kts."
_What you like:_ **LOVES everything about this card.** Current site's wind = "old-fashioned &
too simplistic." High-priority signature wind visualization. KEY: lots of info lives INSIDE
the dial (degree, cardinal, speed, gust) — makes it more prominent than a typical gauge.
_Steal / skip:_ Steal the whole card as the marquee wind display. Keep small wind-circle for
compact forecast rows.
### img-18 ☑ — AMBIVALENT (route to per-metric audit)
_What it is:_ Detailed UV Index drill-down (dark). Week date selector, "14 Extreme" (WHO UVI),
gradient-fill bell curve of UV across the day w/ severity bands (green→purple), hourly values,
plain-language "Sun protection recommended 9AM–6PM," explainer section.
_What you like:_ Likes the **bell curve** (UV day arc w/ severity gradient). BUT it's **a LOT
of information** — maybe too dense. ALSO **not enamored with the current site's UV line
indicator** — worth replacing. Net: bell-curve gradient is the right *direction*, but find a
**simplified middle ground**, not this maximal version.
_Steal / skip:_ Steal (simplified): UV day-curve w/ severity gradient + plain-language guidance.
SKIP: the full information density here. Current UV line indicator = replace. → per-metric audit (#5).
### img-19 ☑ — mostly a MISS (one keeper)
_What it is:_ Google/Pixel Material-You weather detail grid (dark). Bento of varied organic
tile shapes (scalloped circles, blobs, rounded squares): rain, wind, sunrise/sunset horizon
arc, UV ring, AQI scale, visibility, humidity+dew point, pressure radial gauge.
_What you like:_ Mostly **does NOT like these** (organic blob/scalloped shapes not for him →
prefers cleaner uniform tiles). KEEPER: the **pressure radial gauge**. Surfaced question: what
would a **gauge-heavy card** look like? (this only partially gestures at it.)
_Steal / skip:_ Steal: pressure radial gauge. SKIP: organic tile shapes (anti-pattern). Route
the gauge-heavy-card exploration to per-metric audit (#5).
### img-20 ☑ — SKIPPED
AccuWeather AQI tick-ring gauge (value on 0–250+ scale, content in center, excellent→dangerous
gradient legend). User: skip — takeaway is just "gauge with color gradient built in," which the
current site already does OK ("ours is not bad"). Caution noted: don't rip off verbatim.
### img-21 ☑ — strong GRID model
_What it is:_ Apple-Weather-style detail grid (Toronto). 2-col grid of clean uniform translucent
tiles, each: icon + caps title · big value · plain-language context sentence. UV, sunrise/sunset,
wind compass, precipitation, feels-like, humidity, visibility, pressure radial gauge.
_What you like:_ Got to the **GRID idea** + a major direction: **4-column customizable card grid
home page** (cards span 1–4 cols, multi-row, operator-movable; mobile collapse TBD) — see MAJOR
DIRECTION. The **uniform tiles** (vs img-19 blobs). Wind compass here cool but **img-17 preferred**.
_Steal / skip:_ Steal: uniform tile grid, plain-language context per stat, gauges where useful.
Wind = use img-17 style. SKIP cloning verbatim.
### img-22 ☑ — SKIPPED
Plume-style air-quality app (Paris): tick-ring gauge w/ emotive face icon, scrubbable trend
line, activity/sensitivity guidance icons (run/bike/pregnant-sensitive-groups/outdoor). User
skipped — just reinforces the gauge style. (Activity-guidance + emotive-face concepts noted, not pursued.)
### img-23 ☑ — MODEL for today's temp curve
_What it is:_ Dark "Conditions" temp drill-down. Week date selector, 34°/H35/L18, temperature
day-curve w/ gradient area fill (teal→orange), dashed-past/solid-future + now-divider, H/L
markers, hourly icons across top, Actual/Feels-Like toggle, Chance-of-Precipitation bar chart.
_What you like:_ This is the **today's-temperature curve** you wanted — tie it into current
conditions **along the bottom**. The execution here is what you pictured (vs img-05's miss).
_Steal / skip:_ Steal: temp day-curve w/ gradient + dashed-past/solid-future + H/L markers +
Actual/Feels-Like toggle, placed along bottom of current conditions.
### img-24 ☑
_What it is:_ Weather app (Haifa), warm gradient bg. Big thin 28° + line-art sunset icon, weekly
forecast as a connected temp line graph (dots at temp height + connecting line + day labels +
thin line-art icons), safety tips / friends sections.
_What you like:_ Just the **trend line** (weekly temp trend connecting the forecast points).
"That was it."
_Steal / skip:_ Steal: connected temp trend line for the multi-day forecast.
### img-25 ☑
_What it is:_ Glassmorphism weather widget UI kit (card catalog) over blurred blue sky:
current/hourly/today-tomorrow/morning-afternoon-evening/weekly cards, translucent blue glass,
filled colorful icons.
_What you like:_ Just the **icon set** (filled colorful weather icons).
_Steal / skip:_ Candidate reference for the **bold/illustrative hero weather icon set** (icon-set
comparison, deferred #1).
### img-26 ☑
_What it is:_ Google-Weather-style (Rapid City) with an illustrated lake scene (figure dressed
for cold) reflecting conditions. Big 11°/Cloudy, plain-language summary, hourly row w/ subtle
temp trend line + precip droplet%, weather alert card ("it may be slippery").
_What you like:_ Just another example of the **forecast temp trend line**.
_Steal / skip:_ Reinforcement of temp trend line. (Illustrated-vs-photo background fork NOT
resolved here — user didn't bite on the illustration; still in photo camp by default.)
### img-27 ☑
_What it is:_ Low-res AI-mockup dark dashboard (placeholder text): scenic mountain-sunset hero,
trend charts, stat cards w/ photo thumbnails, circular gauge, sidebar nav. Read as vibe reference.
_What you like:_ The possibility of **adding backgrounds (scenic images) behind charts**.
Questioned whether our chart app supports it.
_Steal / skip:_ Steal (pending verify): image backgrounds behind charts. Charts = Recharts;
likely supported — verify (deferred #3b).
### img-28 ☑
_What it is:_ Lightning detection time-vs-distance scatter chart (from a Backyard Station lightning
detector page). X-axis = time (station local), Y-axis = distance (mi), blue rectangles = detected
strikes plotted as semi-transparent blocks. Shows the classic **approach/recede V-shape** — storm
distance decreases as it approaches, hits a minimum, then increases as it moves away. Scrollbar for
time navigation, zoom +/− controls, "now" marker (orange vertical line), legend.
_What you like:_ The **time-vs-distance lightning scatter concept** — it tells the storm story
(approaching? receding? how close did it get?) in a way raw strike counts can't. The V-shape is
immediately readable. Operator wants this general concept for the Lightning tile, improved with
our design system (better typography, glass surface, cleaner rendering).
_Steal / skip:_ Steal: **time-vs-distance strike scatter/heatmap** for the Lightning card (C4
surface E). The current Lightning tile shows only count + nearest distance text — this adds the
visual dimension. Improvement opportunities over img-28: use Recharts (not a raw canvas), apply
our type tokens, make it compact enough for a 1×1 tile (simplified — fewer gridlines, tighter
axes, maybe last-3h window instead of the full scrollable range).
