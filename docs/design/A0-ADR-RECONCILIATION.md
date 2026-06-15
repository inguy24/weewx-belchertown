# A0 — ADR Reconciliation Report (UI-impacting ADRs vs as-built code)

**Status:** Synthesis for user review (2026-05-29). Produced by Track A0 of the UI redesign
([UI-REDESIGN-PLAN.md](../planning/UI-REDESIGN-PLAN.md)). **No ADR edits have been applied yet** —
this report presents proposed edits for user approval. On approval, edits land as `Proposed`; the user
re-approves → `Accepted`, per [rules/clearskies-process.md](../../rules/clearskies-process.md).

**Method:** 16 Sonnet auditors (one per UI-impacting ADR) read each ADR cold and audited it against the
local repos (`repos/weewx-clearskies-{dashboard,api,realtime,stack}`), citing file:line evidence and
classifying every divergence as **intentional** (deliberate departure → edit the ADR), **code-bug**
(code violates a still-valid decision → fix the *code*, not the ADR), or **unclear** (needs a user call).

**Headline:** all 16 ADRs drifted, but almost all drift is **documentation lag** — the ADR text
describes an *intended* state the implementation deliberately moved past. The reconciliation is mostly
pure accuracy edits. The audit also surfaced **~10 genuine code-bugs** as a bonus (code that violates a
still-valid ADR), which are NOT ADR edits — they go to a code-fix backlog for a separate decision.

---

## Summary table

| ADR | Title | Verdict | Intentional → ADR edits | Code-bugs (fix code) | User decision? |
|---|---|---|---|---|---|
| 002 | Tech stack | DRIFTED | react-is guidance + 2 NOTES.md prose | — | minor |
| 046 | GEM faults | DRIFTED (Proposed) | (depends on decision) | — | **YES — accept vs trim** |
| 024 | Page taxonomy | DRIFTED | records model, webcam/radar, inside-temp/custom, +ARCH /seismic | — | **YES — lock vs defer** |
| 013 | AQI handling | DRIFTED | canonical fields, scale, self-hide | — | minor |
| 014 | Almanac source | DRIFTED | shipped-not-Phase6, caching | — | minor |
| 015 | Radar tiles | DRIFTED | context, single-route, JMA/Mapbox | — | minor |
| 016 | Severe alerts | DRIFTED | empty-banner mechanism | docstring (secondary) | minor |
| 020 | Time zone | DRIFTED | priority list, phase, violations note | **3 TZ display bugs** | yes |
| 021 | i18n | DRIFTED | locale path | **weather ns + footer aria; radar/weather coverage** | yes |
| 022 | Theming/branding | DRIFTED | var names, hook, siteTitle/favicon | **logo alt not enforced; inversion warning** | yes |
| 023 | Light/dark | DRIFTED | tailwind v4, nav-rail, no-flash, 3-state, midnight | — | minor |
| 026 | Accessibility | DRIFTED (ADR accurate) | **none** | **sr-only chart unit** | no |
| 040 | Earthquake providers | DRIFTED | MMI/flynn_region canonical | — | no |
| 041 | Realtime service (formerly BFF) | DRIFTED | proxy-optional, direct-mode, LOC | — | **YES — Caddy routing intent** |
| 042 | Unit system | DRIFTED | beaufort, group_uv, derived.py, comfortIndex, config | **barometerTrend; windDirLabel** | yes |
| 044 | Sky condition | DRIFTED | casing, startup ~3min, §8 360 | — | **YES — gusty/noise/rain boundary** |

---

## Part A — Decisions required from the user (these gate finalizing A0)

### A1. ADR-046 — accept the popups, or trim the code? *(the headline decision)*
- **Built but scoped out:** clicking a fault line opens a Leaflet popup showing fault **name + slip_type**
  (`seismic.tsx:339`). ADR-046 line 40 scopes out "fault metadata popups."
- **NOT built (genuinely out of scope, correctly):** per-slip-type **colour** differentiation — all faults
  share one amber style (`FAULT_STYLE`). So only the *popups* exceed scope, not the styling.
- **Also built, unmentioned:** a show/hide fault toggle (default on); a secondary below-map attribution caption.
- **Option A (accept-with-popups):** flip ADR-046 → Accepted, remove "fault metadata popups" from out-of-scope,
  document the popup content + toggle + dual attribution. Keep "per-type colour differentiation" out of scope.
- **Option B (trim code):** remove the `onEachFeature`/`bindPopup` block (`seismic.tsx:330-339`) + 3 i18n keys; ADR stays as-is.
- **Lead recommendation: Option A.** The popup is a small, useful, low-risk feature that's already built, tested,
  and i18n'd; trimming it deletes working UX to satisfy a scoping line. Also align the secondary caption wording to
  the canonical attribution string.

### A2. ADR-024 — lock the as-built Records/Webcam model, or document-and-defer to Track C?
Three as-built departures from ADR-024:
- **Records:** per-section cards + single-period toggle (YTD/All-Time) + columns `Record | Today | Value | Date`,
  **not sortable, no year selector**, plus a **"Today" column** the ADR never named.
- **Webcam/Radar:** ships as **two separate cards**, not one 3-tab tile.
- **Inside-temp + custom records:** **removed** — this was **user-ordered**, so it's unambiguously intentional → drop from ADR.
- **Lead recommendation:** amend ADR-024 to (a) **drop inside-temp/custom** (final), and (b) **document the records
  and webcam/radar as-built** while adding an explicit note that the *final* design (sortable? year selector? Today
  column? merge webcam+radar?) is **revisited in Track C (C8 records, C1/C6 webcam-radar)**. This keeps the ADR
  accurate today without prematurely locking design choices that belong to the component cycles. Open sub-calls for you:
  **keep or drop the "Today" column?** and **lock sorting/year-selector as dropped, or defer as enhancements?**

### A3. ADR-041 — was the Caddy routing left direct-to-API on purpose?
The realtime service proxy is fully built and tested, but all three Caddyfiles in `weewx-clearskies-stack` still route
`/api/v1/*` **directly to the API**, not through `realtime:8766` (only `/sse` goes to the realtime service). So the ADR's
"dashboard has one connection point / API stays internal" is **not true yet**.
- **If staged-rollout (intentional):** ADR consequences get reworded to "API routing is opt-in via `[api] upstream_url`; Caddy bypasses the realtime service by default."
- **If unfinished step:** the Caddyfiles need updating (a stack-repo code change), and the ADR stays aspirational with a "pending" note.
- **Lead recommendation:** treat as **pending/unfinished** and add a "not yet applied" note to the ADR now (the proposed edit
  does this); decide separately whether to actually flip the Caddy routing. I don't want to bless a half-done topology as "done."

### A4. ADR-044 — three classification-boundary calls (code vs ADR authoritative)
- **Gusty qualifier:** ADR §4 mandates appending "and Gusty" under NWS thresholds; **no gusty logic exists** in the code.
  → defer (add "not implemented" note + backlog) **or** implement (code fix). **Lead rec: defer + backlog** unless you want it now.
- **Solar noise floor:** ADR §1c says skip GHI < 10 W/m²; code uses 0 (`_NOISE_FLOOR = 0.0`). The `maxSolarRad < 50 W/m²`
  guard likely makes the 10-floor redundant. **Lead rec: update ADR to reflect 0 + note the maxSolarRad guard.**
- **Rain rate 0.30 in/hr:** ADR implies 0.30 = top of Moderate; code returns Heavy at exactly 0.30. Practically negligible.
  **Lead rec: update ADR to "< 0.30 Moderate / ≥ 0.30 Heavy"** (match code; the test asserts it).

### A5. ADR-020 / ADR-042 / ADR-013 / ADR-022 / ADR-021 — confirm a few code-bug intents
These are code-bugs (Part C) but each has a "is this actually intentional?" question:
- **ADR-020 records date in UTC** and **radar frame time in browser-TZ** — accept as simplifications, or fix to station-TZ?
  (**Lead rec:** records date → fix to station TZ; radar frame time → acceptable, add an ADR carve-out for "currently overhead" timestamps.)
- **ADR-013 OWM gauge** sweeps only 0.6% because a 1–5 value is divided by 500 — normalize for display? (**Lead rec: yes, code fix.**)
- **ADR-022 logo alt** not enforced + single-logo inversion warning never built — fix/defer? (**Lead rec:** add alt field (code fix); the inversion warning is a wizard-UI item → defer with a note.)
- **ADR-021 radar/weather translations** missing in 12 locales — require now, or soften ADR to "en seed, translations later"?
  (**Lead rec:** soften the scaffold wording to en-seed + register the `weather` namespace (code bug, fix); full translation pass is a later task.)

---

## Part B — ADR accuracy edits ready to apply on approval (intentional divergences)

These are pure "make the ADR match the as-built code" edits. Each flips its ADR `Accepted → Proposed` (then you
re-approve). Verbatim old/new text is drafted and staged (from the audit run); summaries below.

- **ADR-002:** charting table already correct (Recharts; ECharts/Tremor dropped). Edit the **react-is** guidance to the
  Recharts-v3 peer-dependency model (the `overrides` workaround was v2). **+ NOTES.md** items #3b and img-27 → "Recharts" not "ECharts/Tremor."
- **ADR-013:** add `aqiScale`/`observedAt`/`source` to canonical AQI fields; replace "EPA 0–500" with the `aqiScale`
  discriminator design (`epa` vs `owm` 1–5, no ingest conversion); correct the self-hide claim (tile shows a "no data" placeholder; AQI not in Charts/Records).
- **ADR-014:** planets/eclipses/meteor/special-names **shipped** (per ADR-024 2026-05-27 amendment), not Phase 6+; conjunctions remain deferred; note ADR-045 warmer-cache tier (the "no caching" line is now wrong).
- **ADR-015:** Context → as-built split Radar/Webcam cards; "one route per keyed module" → single parameterized
  `/radar/providers/{id}/tiles/...` route; remove **JMA/Mapbox** from the attribution list (dropped 2026-05-11).
- **ADR-016:** empty-banner mechanism is a direct null-return in `AlertBanner` (not the cat-10 system). (ADR otherwise accurate.)
- **ADR-020:** TZ source priority 3 → OS timezone (not lat/lon); lat/lon derivation → **Phase 4** (was Phase 2); add a
  "known violations to fix" note pointing at the 3 code-bugs (Part C).
- **ADR-021:** locale files live at `public/locales/<lang>/<ns>.json` via i18next-http-backend (not `src/i18n/locales/`).
- **ADR-022:** CSS vars are `--brand-primary-{light,dark,fg-light,fg-dark}` (not `--accent`); logo via `useBranding()` hook
  (not props) + dark-mode CSS invert; add `siteTitle` + `faviconUrl` + URL-based `customCssUrl` to operator inputs.
- **ADR-023:** Tailwind **v4 `@custom-variant`** (no `darkMode` config); toggle lives in **nav-rail** (not footer/settings);
  no-flash via **inline `index.html` script** + provider `useEffect`; document the **3-state** cycle (system→light→dark)
  and the **midnight re-fetch** + polar clamp for auto-sunrise-sunset.
- **ADR-040:** GeoNet **MMI** → canonical `mmi` field (not extras); EMSC **flynn_region** → canonical `place` (not extras);
  document actual per-provider extras keys.
- **ADR-041:** proxy is **optional** (503 when `upstream_url` absent); **direct mode now implemented** (strike the out-of-scope
  line); LOC grew to ~4,800 (post-ADR features); Caddy routing note per **Decision A3**.
- **ADR-042:** remove `beaufort` from group_speed units (it's a derived field, not a display unit); add **group_uv** row;
  add **derived.py** to file layout; rewrite **comfortIndex** as a plain-string selector (value/label live in windchill/heatindex);
  mark `[[time_formats]]/[[degree_days]]/[[trend]]` config as not-implemented.
- **ADR-044:** Beaufort labels → sentence-case + "Hurricane" (code authoritative per its test comment); startup is **~3 min
  (36 samples)** not 30 min; §8 smoothing table 400 → **~360**. (Plus the §1c/§3/§4 boundary calls in **Decision A4**.)
- **ADR-024:** per **Decision A2** — records model, webcam/radar split, drop inside-temp/custom, + **ARCHITECTURE.md** route
  table `/earthquakes` → `/seismic` (API path `/api/v1/earthquakes` unchanged; verified ARCH:149/291, App.tsx:114).

---

## Part C — Code-bugs found (NOT ADR edits — code-fix backlog)

The audit checked ADR→code *and* code→ADR; these are places the **code violates a still-valid ADR**. They are
**not** reconciled by editing the ADR — the fix is in the code. Surfaced for a fix-now-vs-track decision.

| # | ADR | Bug | Evidence |
|---|---|---|---|
| 1 | 026 | Homepage sr-only chart table omits temp unit (a11y/WCAG; Monthly/Annual tabs already correct) | `charts.tsx:1090` vs `:390/:610/:1009` |
| 2 | 020 | Seismic map popup `toLocaleString()` with no `timeZone` → browser TZ | `seismic.tsx:317` (list panel `:421` is correct) |
| 3 | 020 | Records "Date Observed" `formatDate` hardcodes `'UTC'` | `records.tsx:48-56, :201` |
| 4 | 020 | Radar frame time `Intl.DateTimeFormat` with no `timeZone` → browser TZ | `radar-map.tsx:205-215` |
| 5 | 021 | `weather` namespace used but not registered + `weather.json` missing in 12 locales | `weather-icon.tsx:97`, `i18n/index.ts:37-49` |
| 6 | 021 | 5 hardcoded English aria-labels in footer ShareRow | `footer.tsx:82,91,100,109,117` |
| 7 | 022 | Logo alt text not required/enforced (ADR + coding §5.5 mandate it) | `responses.py:950`, `setup.py:239-251` |
| 8 | 042 | `barometerTrend` raw float + dashboard hardcodes ±0.01 inHg threshold (client unit knowledge) | `barometer_trend.py:162`, `barometer.ts:11-18` |
| 9 | 042 | `windDirLabel()` recomputes compass client-side, disagrees with API `windDir.label` at sector boundaries | `now.tsx:49-52`, `forecast.tsx:16-19` vs `transformer.py:302-307` |

**Secondary doc bugs (trivial):** `generated-types.ts:67` stale comment still mentions InsideTemp+custom;
`providers/alerts/__init__.py:3-4` docstring still calls aeris/owm "future rounds."

---

## Part D — Proposed process rule (surface for approval; not yet applied)

To be added to [rules/clearskies-process.md](../../rules/clearskies-process.md) under **ADR discipline**:

> **A directive that contradicts an Accepted ADR includes updating that ADR.** When the user orders a change that
> runs counter to an Accepted ADR, editing that ADR in place (→ `Proposed` → user re-approval) is **part of executing
> the change**, not optional follow-up. Never silently implement code that diverges from an Accepted ADR and leave the
> ADR stale. If the divergence is a genuine decision change, it edits in place; if it's a fundamentally distinct
> decision, it supersedes. Either way the record moves in the same work item as the code.
>
> **Why (2026-05-29):** The A0 reconciliation gate found that **all 16 UI-impacting ADRs had drifted** from the
> as-built code — overwhelmingly because user-ordered changes (Records model, webcam/radar split, inside-temp removal,
> 3-state theme toggle, Skyfield almanac promotions, etc.) were implemented without updating the ADR that described the
> old behavior. The records accumulated a 16-ADR debt that took a full audit to detect. Folding the ADR edit into the
> change that causes it prevents the debt from forming.

---

## Verification evidence — A0

- Workflow run: `wf_f7e83891-6c2`, 16 agents, 0 failures, ~1.11M subagent tokens, 564 tool uses.
- Lead independent spot-checks (decision-critical claims):
  - ADR-046 `status: Proposed` + out-of-scope line 40 "fault metadata popups, fault-type styling differentiation" — confirmed.
  - `seismic.tsx:330-339` `onEachFeature`+`bindPopup(name + slip_type)` — confirmed popups built; `FAULT_STYLE` uniform → per-type colour NOT built.
  - `ARCHITECTURE.md:291` `| /earthquakes | Earthquakes | Yes |`; `:149` API path `/api/v1/earthquakes` unchanged — confirmed.
- Full verbatim old/new edit text for every ADR is staged from the audit run and will be applied exactly on approval.
