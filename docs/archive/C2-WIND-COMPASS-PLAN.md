# C2 — "Current Wind" compass card — execution plan

**Status:** ✅ COMPLETE 2026-05-31. Mockup approved, implementation code-complete across all three repos, pending push + deploy. Archived to `docs/archive/`.
**Component:** C2 (⭐ signature Wind Compass) of the UI redesign. Parent roadmap: [UI-REDESIGN-PLAN.md](UI-REDESIGN-PLAN.md) Track C; work-list row [C0-PAGE-INVENTORY.md](../design/C0-PAGE-INVENTORY.md) "C2".
**Per-component workflow this follows:** [UI-REDESIGN-PLAN.md](UI-REDESIGN-PLAN.md) "Per-component workflow" (read-and-LOOK inspiration → data inventory → composition → mockup → ADR → exec plan → code).

---

## 0. Orientation for a fresh session (read first)

- Project rules routing: [../../CLAUDE.md](../../CLAUDE.md). **Load these before acting:** [../../rules/coding.md](../../rules/coding.md) (esp. "Render and LOOK" §after-4, and §5 WCAG), [../../rules/clearskies-process.md](../../rules/clearskies-process.md) (ADR lifecycle, agent prompt requirements, plain-English), [../../rules/github.md](../../rules/github.md).
- **Memory system is OFF** ([../../CLAUDE.md](../../CLAUDE.md)); plans live here in `docs/planning/`.
- **Three sub-repos** under `../../repos/`:
  - `weewx-clearskies-realtime` — the **BFF** (small Python service bridging weewx loop packets → SSE + proxying `/api/v1/*`; computes derived fields). Agent: `clearskies-realtime-dev`.
  - `weewx-clearskies-api` — FastAPI + SQLAlchemy backend (reads the weewx MariaDB). Agent: `clearskies-api-dev`.
  - `weewx-clearskies-dashboard` — React 19 + Vite + Tailwind v4 + shadcn/ui + Recharts SPA. Agent: `clearskies-dashboard-dev`.
- **Data flow the card depends on:** dashboard → BFF `/api/v1/current` (REST baseline) + BFF SSE stream (live). The BFF proxies the API's `/current` and **overlays computed fields** (e.g. `beaufort`, `windDirCardinal`, `barometerTrendDirection`). Our two new fields are produced **in the BFF**, not the API DB.
- **Deploy target:** `weather-dev`. Production Belchertown skin is untouched (cutover is Phase 5 of the master plan).
- **Architecture source of truth:** [../ARCHITECTURE.md](../ARCHITECTURE.md). API/BFF contract: [../contracts/openapi-v1.yaml](../contracts/openapi-v1.yaml).

### Git safety (ALL agents, ALL repos — non-negotiable, from CLAUDE.md)
Implementation agents may ONLY `git add`, `git commit` (local), `git status`, `git log`, `git diff`. **NO `git pull/push/fetch/rebase/merge/remote`, NO checkout of remote branches, NO worktree isolation.** If an agent hits unexpected repo state (diverged remote, unknown commits, conflicts) it **STOPS and reports to the coordinator**. The coordinator pushes **only** when the operator types "push" in chat.

---

## 1. Context — why this exists

C2 is the signature **wind compass**, modeled on **[../design/inspiration/raw/img-17.png](../design/inspiration/raw/img-17.png)** — open it AS AN IMAGE before designing. It is a *cropped* photo of a **tick-rim circular dial used as an information container**: a current-direction marker on the rim, and degree+cardinal ("356° NORTH"), the big speed ("39.8 kts"), and the gust ("Wind Gust 48.3 kts") all stacked *inside* the circle. Inspiration notes: [../design/inspiration/NOTES.md](../design/inspiration/NOTES.md) img-17 section (⭐ LOVED) and element-axis "WIND COMPASS DIAL". The card was built twice before as a generic needle-on-a-rose and **rejected** — do not repeat that; the loved concept is the *info-container dial*, not a compass rose.

This build is **larger than a re-skin** because one required readout — a **10-minute sustained wind average** — does not exist in our data and must be created in the BFF.

### Verified data facts (hardware-independent; do not re-litigate)
- Station hardware = **Ambient Weather**; weewx **5.3.1** ([../../reference/weather-skin.md](../../reference/weather-skin.md) §"Weewx engine"). (A prior agent's "Davis Vantage" claim was **fabricated** — struck.)
- The weewx **archive schema we query has no 10-min sustained-average and no 10-min-gust column** — only `windSpeed`, `windDir`, `windGust`, `windGustDir`, `vecavg`, `vecdir` (verify in `repos/weewx-clearskies-api/weewx_clearskies_api/db/reflection.py` STOCK_COLUMN_MAP).
- The **loop packets reaching the BFF carry only instantaneous `windSpeed` + peak `windGust`** — no 10-min field (`repos/weewx-clearskies-realtime/.../adapters/direct.py`; the only existing wind buffer is `enrichment/input_smoother.py:14-24`, a **5-minute sample-count** buffer used internally for conditions-text stability, never emitted).
- **⇒ The BFF computes the 10-minute sustained average AND the 10-minute max gust.** 5-minute is rejected by the operator as not scientifically valid.

---

## 2. Locked operator directives (2026-05-31)
1. Card must **look like img-17** (tick-rim info-container dial); **not** an old-fashioned compass; **not all caps**; fonts **not tiny**.
2. **Include the `ph:wind` icon** on the card (this **overrides** ADR-050's wind-icon exclusion — see T1.2).
3. **Compute the 10-min sustained average AND the 10-min max gust in the BFF** from a rolling 10-minute window of incoming wind data.
4. The **current-speed numeral is smaller than the C1 Current-Conditions temperature.** 4.75rem (`--text-stat-hero`) is **C1-temperature-only**; the token doc's "every data card" claim was **never operator-approved** and is corrected (T1.3). Wind speed ≈ **3rem** Outfit.
5. Card title text = **"Current Wind"** (normal case, semibold).
6. **Only approved icons** — Phosphor base ([../decisions/ADR-050-utility-stat-nav-icons.md](../decisions/ADR-050-utility-stat-nav-icons.md)) plus the wind override.

---

## 3. Locked constraints (already decided elsewhere — do NOT re-theorize)
- **Footprint = 2×2**, verbatim from the A4 grid mockups: [../design/mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) (the Wind Compass card = `col-span-2 row-span-2`) and [../design/mockups/A4-page-anatomy.html](../design/mockups/A4-page-anatomy.html). On the desktop 4-col grid (`repeat(4,1fr)`, `gap:1rem`, `grid-auto-rows:5.5rem`, container 80rem) a 2×2 renders **landscape ≈ 38rem wide × 25rem tall**; collapses to **1×2** on tablet, **1×auto** on phone. The mockup is built **on the real A4 grid CSS**, never as a standalone box.
- **Type tokens** from [../design/design-tokens-typography.md](../design/design-tokens-typography.md) (LOCKED): Outfit (`--font-display`) for the speed numeral; Manrope (`--font-sans`) for title/labels; card title **600 semibold, not bold, not uppercase**; Lexend (`--font-chart`) is chart-only (N/A here). Self-hosted woff2 in `../design/mockups/fonts/`.
- **Render-and-LOOK is mandatory** ([../../rules/coding.md](../../rules/coding.md) "Render and LOOK"): every UI/mockup change is screenshotted headless and visually inspected before it's called done. Reading markup / `axe` passing is NOT visual verification. **The mockup stays minimal** — one card at locked size; no toggles, ghost/neighbour cards, degrade galleries, or annotation panels.
- **WCAG 2.1 AA** ([../../rules/coding.md](../../rules/coding.md) §5) — load-bearing, release-blocking.

### Headless render command (Windows, from coding.md)
```
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu `
  --screenshot="C:\tmp\render.png" --window-size=1400,900 "file:///<absolute-path-to.html>"
```
Then Read `C:\tmp\render.png` and LOOK.

---

## 4. The spec the tasks implement

### 4.1 Card — data shown (exactly the operator's list, nothing extra)
| Element | Source field | Treatment |
|---|---|---|
| Current-direction rim marker (the dial indicator) | `windDir` | accent/gold marker on the tick rim, pointing to the current bearing |
| Degree bearing + cardinal ("356° N") | `windDir` + `windDirCardinal` (BFF-computed, rendered via i18n `directions.*`) | inside the dial, top of the center stack |
| Current speed (the hero numeral) | `windSpeed` | inside dial center, **Outfit ≈ 3rem** + unit; clearly **smaller** than the C1 temp |
| 10-min sustained average | **`windSpeedAvg10m`** (NEW, BFF) | readout inside the dial; Manrope label + semibold value |
| Maximum gust (10-min) | **`windGustMax10m`** (NEW, BFF) | readout inside the dial; Manrope label + semibold value |
| Card title | — | `ph:wind` + "Current Wind", semibold, normal case |

Unit = operator-configured `group_speed` (kts/mph/km·h⁻¹/m·s⁻¹), rendered from `ConvertedValue.formatted` — **no client-side unit math** (ADR-042). Beaufort is **not** in the operator's list → omit it.

### 4.2 Card — composition
One centered **tick-rim dial** bounded by the card height (~20–22rem diameter); the rim marker at the current bearing; center stack = degree+cardinal (top) → current speed+unit (middle) → the two secondary readouts inside the lower arc — preserving img-17's "everything inside the circle." If the landscape width leaves the dial looking lost, the two readouts may **flank** the dial instead; the implementer renders both, LOOKs, picks one, and shows the operator **one** composition.

### 4.3 Card — accessibility
SVG `role="img"` + `<title>` summarizing speed/direction; live values wrapped in `aria-live="polite"`; the rim marker has **≥ 3:1 contrast** vs the dial in **both** themes and is conveyed by **position + shape** (never color alone); the `ph:wind` title glyph is `aria-hidden="true"` (the text carries meaning). Contrast verified light **and** dark with a real tool.

### 4.4 BFF — the new computation
New module `enrichment/wind_rolling_window.py`:
- **True wall-clock 600-second window**, NOT the sample-count `RingBuffer` (loop cadence isn't guaranteed 5s and the operator requires a scientifically valid 10-min window). Store `(timestamp, value)` pairs keyed on the packet timestamp; evict entries older than 600s.
- `windSpeedAvg10m` = arithmetic mean of `windSpeed` in the window; `windGustMax10m` = max of `windGust` in the window.
- **Min-coverage guard:** emit only once the window spans ≥ 60s of samples; before that, **omit** the fields (do NOT emit null). In-memory; resets on restart (acceptable for a rolling average; document the ~warm-up).
- **Registered two ways** (both read/feed the same module-level window):
  - **packet tap** via `register_processor(...)` so every loop packet feeds the window (runs in the `sse/emitter.py` fanout, before SSE conversion; processor must NOT mutate the packet).
  - **`/current` enrichment** via `register_enrichment("current", ...)` so the REST baseline the dashboard loads also carries the fields.
- **Emit on BOTH paths**, same shape as existing wind fields: SSE via `units/transformer.py` `add_derived_fields()` (ConvertedValue dict, `group_speed` unit/label/format, exactly like `beaufort`); `/current` via the enrichment fn (converted scalar, exactly like `barometerTrend`). Reuse `units/conversion.py` (group_speed conversions) + `units/labels.py` (labels/formats). The enrichment must **never raise** (log + pass through on error).

### 4.5 Contract field names (fixed here so Phase-3 agents parallelize)
`windSpeedAvg10m` and `windGustMax10m` — type `number, nullable`, described "BFF-derived 10-minute sustained average wind speed" / "BFF-derived 10-minute maximum gust". Dashboard TS type: `ConvertedValue | number | null`.

---

## 5. GRANULAR TASK LIST

Each task: **Owner** (agent) · **Dep** · **Files** · **Do** · **Accept** (pass/fail = definition of done) · **QC** (a *different* party verifies acceptance — never owner self-attest).

### PHASE 0 — Mockup (design gate; blocks ALL code)

**T0.1 — Build the C2 mockup**
- Owner: `clearskies-dashboard-dev` · Dep: none
- Files: `../design/mockups/C2-current-wind.html` (new)
- Do: assemble the mockup CSS from the locked sources — **@font-face** block (Manrope/Outfit 400/600/700 from `fonts/*.woff2`) per [../design/design-tokens-typography.md](../design/design-tokens-typography.md) (also present in `../design/mockups/C2pre-type-system.html`); the **type-scale tokens** from that same doc; the **grid + glass-card tokens** (`:root`, `.grid-4col` with `grid-auto-rows:5.5rem`, `.card`) **verbatim from [../design/mockups/A4-page-anatomy.html](../design/mockups/A4-page-anatomy.html)**. Place ONE `.card.col-span-2.row-span-2` titled "Current Wind". Build the tick-rim SVG dial (salvage ONLY the tick-geometry math from the rejected `C2-wind-card.html` / `C2-wind-card-v2.html` / `C2-wind-compass.html`; discard their layouts). Sample data: 305°/NW, speed "12" (Outfit ~3rem) + "mph", readouts "10-min avg 9 mph" + "Max gust 21 mph", `ph:wind` (iconify) in the title.
- Accept: (1) only locked tokens/fonts — no invented `font-size`/`font-family`; (2) card is exactly `col-span-2 row-span-2` inside `.grid-4col`; (3) title is normal-case, not uppercase; (4) speed numeral visibly smaller than a 4.75rem reference glyph; (5) minimal — no extra cards/toggles/galleries.
- QC: **coordinator** renders headless (cmd §3) → Reads the PNG → LOOKs → iterates with owner until the render matches img-17's info-container concept.

**T0.2 — Operator approval gate**
- Owner: coordinator · Dep: T0.1
- Do: present the rendered PNG to the operator.
- Accept: **operator explicitly approves the render.** No Phase-1+ task starts until recorded here.

### PHASE 1 — ADR + doc corrections (Dep: T0.2)

**T1.1 — Author the C2 ADR**
- Owner: `clearskies-docs-author` · Dep: T0.2
- Files: `../decisions/ADR-0NN-wind-compass.md` (new — claim the next free ADR number; check [../decisions/INDEX.md](../decisions/INDEX.md))
- Do: record composition, the 5 readouts, BFF-derived `windSpeedAvg10m`/`windGustMax10m`, speed≈3rem (temp-only 4.75rem), `ph:wind`, link the approved mockup. **Must include an Acceptance-criteria section.** Reference (do not restate) ADR-048/050/051, ADR-041/042 (ConvertedValue/cardinal), ADR-044. Status **Proposed**.
- Accept: file has Status + Acceptance-criteria sections; criteria are pass/fail; cites the mockup; per [../../rules/clearskies-process.md](../../rules/clearskies-process.md) format.
- QC: **coordinator** checks vs clearskies-process; **operator** reviews → flips to Accepted.

**T1.2 — Amend ADR-050 (allow the wind icon on C2)**
- Owner: `clearskies-docs-author` · Dep: T0.2
- Files: [../decisions/ADR-050-utility-stat-nav-icons.md](../decisions/ADR-050-utility-stat-nav-icons.md) (edit in place)
- Do: narrow the "no utility wind icon" Decision line + its acceptance checkbox to **permit `ph:wind` on the C2 card title**; add a dated note; status → Proposed.
- Accept: `git diff` touches only the wind-exclusion lines + checkbox + a note.
- QC: **coordinator** diff; **operator** re-approves → Accepted.

**T1.3 — Correct the typography token doc**
- Owner: `clearskies-docs-author` · Dep: T0.2
- Files: [../design/design-tokens-typography.md](../design/design-tokens-typography.md) (edit in place)
- Do: scope `--text-stat-hero` (4.75rem) to the **C1 Current-Conditions temperature**; delete the "Primary number on every data card" claim; add a wind-speed≈3rem note; dated "operator-authorized 2026-05-31".
- Accept: `git diff` changes only the stat-hero description lines; **no other token values changed**.
- QC: **coordinator** diff; **operator** confirms.

### PHASE 2 — Execution brief (Dep: T1.1)

**T2.1 — Write the C2 brief**
- Owner: `clearskies-docs-author` · Dep: T1.1
- Files: `briefs/C2-wind-compass.md` (new)
- Do: the 6-section template ([UI-REDESIGN-PLAN.md](UI-REDESIGN-PLAN.md) "Execution-plan template"): ADR reference; **exhaustive per-repo scope in/out + "do NOT touch"**; per-deliverable spec; QC gates = T1.1 acceptance criteria as pass/fail; definition of done; agent git-constraints block. Embeds tasks T3a–T3d verbatim.
- Accept: every Phase-3 task + its acceptance criteria appear; exclusions listed per repo; git-constraints block present.
- QC: **coordinator** approves before dispatch.

### PHASE 3 — Implementation (Dep: T2.1; 3a / 3b / 3c+3d run in PARALLEL — field names fixed in §4.5)

**T3a.1 — BFF: time-windowed wind module**
- Owner: `clearskies-realtime-dev` · Dep: T2.1
- Files: `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/enrichment/wind_rolling_window.py` (new)
- Do: `TimeWindowedBuffer` (deque of `(ts,value)`, evict >600s, thread-safe lock like `enrichment/ring_buffer.py`); `process_packet(packet)` feeds windSpeed+windGust (handles both raw floats and `{value,...}` dicts; strips MQTT unit suffix via `mqtt_fields.strip_suffix`; **no packet mutation**); `get_wind_avg()` (mean), `get_gust_max()` (max), `reset()`; min-coverage guard ≥60s else `None`.
- Accept: `ruff` + `mypy` clean; no packet mutation; returns `None` before coverage.
- QC: **auditor** + the T3a.5 tests.

**T3a.2 — BFF: register tap + /current enrichment**
- Owner: `clearskies-realtime-dev` · Dep: T3a.1
- Files: `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/__main__.py` (alongside the existing `register_processor(...)` calls and the `register_enrichment("current", enrich_barometer_trend)` precedent)
- Do: `register_processor(process_packet)`; `register_enrichment("current", enrich_wind_rolling_average)`.
- Accept: service boots; tap invoked per packet (log/test proof).
- QC: auditor.

**T3a.3 — BFF: emit on SSE**
- Owner: `clearskies-realtime-dev` · Dep: T3a.1
- Files: `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/transformer.py` (`add_derived_fields`, beside the `beaufort` injection)
- Do: inject `windSpeedAvg10m` / `windGustMax10m` as ConvertedValue (`group_speed` unit/label/format) when present; lazy-import the getters to avoid a circular import.
- Accept: SSE JSON shows both fields (correct unit) after warm-up; absent before.
- QC: T3a.5 + a manual SSE capture.

**T3a.4 — BFF: emit on /current**
- Owner: `clearskies-realtime-dev` · Dep: T3a.1
- Files: `enrichment/wind_rolling_window.py` (`enrich_wind_rolling_average(data)`); wire via `register_enrichment` (see `proxy.py` `register_enrichment` / `_run_enrichments`, and the `barometer_trend` precedent)
- Do: inject converted scalars into the `/current` envelope (mirror `enrich_barometer_trend`); read the operator target unit the same way the barometer/cardinal code does; **never raise** (log + return data).
- Accept: `/current` carries both after warm-up; omitted before; never 500 on enrichment error.
- QC: T3a.5 + a manual `curl`.

**T3a.5 — BFF: tests**
- Owner: `clearskies-realtime-dev` · Dep: T3a.1–T3a.4
- Files: `repos/weewx-clearskies-realtime/tests/test_wind_rolling_window.py` (new) — pattern from `tests/test_ring_buffer.py`, `tests/test_input_smoother.py`, `tests/test_barometer_trend.py`
- Do: cases — <60s coverage ⇒ fields omitted; mean correctness; max-gust correctness; eviction of entries past 600s; None/non-numeric skipped; `reset()` isolation.
- Accept: **pytest output pasted: N passed / 0 failed**; full realtime suite no new failures.
- QC: **auditor** re-runs pytest independently.

**T3b.1 — Contract: OpenAPI fields**
- Owner: `clearskies-api-dev` · Dep: T2.1
- Files: [../contracts/openapi-v1.yaml](../contracts/openapi-v1.yaml) (authoritative) + `repos/weewx-clearskies-dashboard/src/api/openapi-v1.yaml` (keep in sync). NOTE: per [UI-REDESIGN-PLAN.md](UI-REDESIGN-PLAN.md) the dashboard copy has historically had uncommitted edits — check `git status` and resolve before editing.
- Do: add `windSpeedAvg10m` / `windGustMax10m` to the Observation schema (number, nullable, described per §4.5).
- Accept: yaml valid; openapi/contract test green.
- QC: auditor.

**T3b.2 — Contract: Pydantic parity (only if the test demands it)**
- Owner: `clearskies-api-dev` · Dep: T3b.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py` (Observation, after the `windGustDir` line)
- Do: add the two optional fields **only if** the openapi parity test fails without them (the API itself won't populate them — the BFF does).
- Accept: api pytest **0 new** failures vs the pre-existing baseline (the plan notes ~33 pre-existing unrelated failures — compare the failure *set*, not the count blindly).
- QC: auditor re-runs and diffs the failure set.

**T3c.1 — Card: TS types**
- Owner: `clearskies-dashboard-dev` · Dep: T2.1
- Files: `repos/weewx-clearskies-dashboard/src/api/types.ts` (Observation interface, after the `windGust`/`windGustDir` fields)
- Do: add `windSpeedAvg10m` / `windGustMax10m: ConvertedValue | number | null`.
- Accept: `tsc` 0 errors.
- QC: coordinator.

**T3c.2 — Card: WindCompassCard component**
- Owner: `clearskies-dashboard-dev` · Dep: T0.2, T3c.1
- Files: `repos/weewx-clearskies-dashboard/src/components/WindCompassCard.tsx` (new) — replaces the inline `WindCompass` currently at `src/routes/now.tsx:100-191`
- Do: implement the **approved mockup** as React + SVG; consume `windDir` / `windDirCardinal` / `windSpeed` / `windSpeedAvg10m` / `windGustMax10m` via the existing `useRealtimeObservation` hook (`src/hooks/useRealtimeObservation.ts`); render via `ConvertedValue.formatted` (no client unit math); cardinal via i18n `directions.*` (existing pattern at `now.tsx:128`); `ph:wind` title; a11y per §4.3; missing avg/gust ⇒ "—".
- Accept: visual match to the approved mockup; speed < temp; no client unit arithmetic; null fields handled.
- QC: **coordinator** render-and-LOOK (T3c.5).

**T3c.3 — Card: wire into now.tsx + delete dead code**
- Owner: `clearskies-dashboard-dev` · Dep: T3c.2
- Files: `repos/weewx-clearskies-dashboard/src/routes/now.tsx`
- Do: swap in `<WindCompassCard/>`; **delete the old inline `WindCompass` (100-191) entirely** (no commented-out code, no unused imports — coding.md §"No dead code").
- Accept: `grep` shows the old inline component gone; `tsc` + `vite build` clean.
- QC: coordinator diff.

**T3c.4 — Card: i18n**
- Owner: `clearskies-dashboard-dev` · Dep: T3c.2
- Files: dashboard `common.json` (en) + any `weather`/`now` namespace used
- Do: keys for "Current Wind", "10-min avg", "Max gust", and the SVG `<title>` / aria strings; en seeded; fallback safe.
- Accept: `grep` finds no hardcoded UI strings in the component; en keys present.
- QC: auditor.

**T3c.5 — Card: render-and-LOOK + axe**
- Owner: `clearskies-dashboard-dev` · Dep: T3c.2–T3c.4
- Do: build, screenshot the card in **both themes**, Read the PNGs, fix what's wrong, re-render; run `@axe-core` on the card page.
- Accept: render matches the mockup; speed clearly < temp; readable; **axe 0 violations both themes**; contrast pass light+dark.
- QC: **coordinator** inspects the PNGs (not the markup).

**T3d.1 — Card: Playwright + axe e2e**
- Owner: `clearskies-test-author` · Dep: T3c.2
- Files: dashboard Playwright test for the card
- Do: renders with fields; missing-fields fallback; keyboard focus reachable; `aria-live` present; `@axe-core/playwright` 0 violations.
- Accept: **test output pasted, passing**.
- QC: auditor re-runs.

### PHASE 4 — Audit (Dep: all Phase-3)

**T4.1 — Independent audit**
- Owner: `clearskies-auditor` · Dep: T3a–T3d
- Do: review every diff against the C2 ADR (T1.1), the ADR-050 amendment (T1.2), the token-doc fix (T1.3), [../../rules/coding.md](../../rules/coding.md) §5 a11y + the security baseline; confirm render-and-LOOK evidence exists; **independently re-run the realtime + api + dashboard test suites**; report findings via mailbox. **No implementation, no push.**
- Accept: written report; **0 unresolved high/critical**; attaches test outputs + screenshots as evidence.
- QC: **coordinator** reads the report and routes any finding back to the owning Phase-3 task.

### PHASE 5 — Deploy + live verify (Dep: T4.1; requires operator "push")

**T5.1 — Commit review, push (on operator word), deploy, verify live**
- Owner: coordinator · Dep: T4.1
- Do: review the local commits across the 3 repos; **push only when the operator types "push"**; deploy to weather-dev; after ~1–2 min warm-up verify BFF `/current` + SSE carry `windSpeedAvg10m` / `windGustMax10m` in the configured unit, with values sane vs raw `windSpeed`/`windGust`; card live in both themes.
- Accept: **live evidence pasted** (curl `/current`, an SSE sample, a card screenshot); operator confirms.

---

## 6. Dependency graph
`T0.1 → T0.2 (GATE) → {T1.1, T1.2, T1.3} → T2.1 → { T3a.*, T3b.*, T3c.*+T3d.1 } → T4.1 → T5.1`
- T3a order: `T3a.1 → (T3a.2, T3a.3, T3a.4) → T3a.5`
- T3c order: `T3c.1 → T3c.2 → (T3c.3, T3c.4) → T3c.5`

## 7. QC ownership at a glance
- Every task = **owner self-check** + a **separate QC verifier**. No self-attested completion.
- **Coordinator:** design/render-and-LOOK gates, diff reviews, operator liaison, the only party who pushes.
- **clearskies-auditor:** independent re-run of all three suites + ADR/rules/a11y/security conformance before "done".
- **Operator:** approves the mockup (T0.2) and the ADRs (T1.1/T1.2), authorizes push (T5.1).

## 8. Verification (end-to-end, the bar for "C2 done")
- **BFF:** `pytest` in `repos/weewx-clearskies-realtime` — new `test_wind_rolling_window.py` green + full suite no regressions; exercise the function directly (≥60s ⇒ avg/max emit; <60s ⇒ omitted; eviction past 600s).
- **API:** `pytest` in `repos/weewx-clearskies-api` — openapi/contract test green; 0 new failures vs baseline.
- **Dashboard:** `tsc` 0 errors + `vite build` + `@axe-core/playwright` 0 violations in **both** themes + Playwright render.
- **Render-and-LOOK:** headless screenshots of BOTH the mockup and the built card; Read each PNG and confirm — tick-rim dial, current-direction rim marker, "356° N" + speed (clearly smaller than the C1 temp), 10-min avg + max-gust readouts, `ph:wind` + "Current Wind" title, no all-caps, readable fonts.
- **Live (weather-dev):** after warm-up, `/current` + SSE carry both new fields in the configured unit with sane values.

## 9. Implementation reference — verified file:line (so agents don't re-discover)

**BFF (`repos/weewx-clearskies-realtime/weewx_clearskies_realtime/`):**
- Packet-tap registration: `enrichment/packet_tap.py:30-35` (`register_processor`; processors must NOT mutate the packet). Invoked in the fanout at `sse/emitter.py:138-142` (before broadcast).
- Startup registrations (where to add ours): `__main__.py:260-275` (existing `register_processor` calls) and `__main__.py:277-280` (`register_enrichment("current", enrich_barometer_trend)` precedent).
- **/current enrichment precedent** (our template, async, injects into the envelope): `enrichment/barometer_trend.py:182-322`; `register_enrichment` defined `proxy.py:296-305`; enrichments run via `_run_enrichments` at `proxy.py:109-136` (called `proxy.py:187`); endpoint key = `path.split("/")[0]`.
- **/current emission + flatten + cardinal injection** (where scalars land): `proxy.py:410-505`; cardinal at `proxy.py:475-482`; helper `_cardinal_for_degrees` `proxy.py:392-407`.
- **SSE derived-field injection** (our template, ConvertedValue): `units/transformer.py` `add_derived_fields()` (beaufort block ~`207-252`); REST beaufort `123-144`; `beaufort()` in `units/derived.py:34-60`; `_degrees_to_index` `units/transformer.py:38-52`.
- SSE pipeline: `app.py:106-174` (unit conversion `:148`, scene inject `:159`, JSON `:163`).
- Unit conversion registry (group_speed): `units/conversion.py` (~`47-59`); labels/formats `units/labels.py:9-128`.
- Existing buffers (pattern only — we use a time-window instead): `enrichment/ring_buffer.py:17-102`, `enrichment/input_smoother.py:14-91`.
- MQTT suffix strip: `mqtt_fields.py` `strip_suffix`; SSE cardinal injection precedent `mqtt_fields.py:202-214`.
- Config/settings (if a window setting is wanted): `config/settings.py`.

**API (`repos/weewx-clearskies-api/weewx_clearskies_api/`):**
- Observation Pydantic model: `models/responses.py:36-145`; wind fields `:56-59` (add after `:59`).
- Canonical column map (proof there's no 10-min column): `db/reflection.py` STOCK_COLUMN_MAP (~`62-167`).

**Dashboard (`repos/weewx-clearskies-dashboard/src/`):**
- Existing inline wind compass (to replace): `routes/now.tsx:100-191`; `windDirCardinal` read at `now.tsx:356`; cardinal i18n render at `now.tsx:128` (`tCommon(\`directions.${windDirCardinal}\`)`).
- Data hook: `hooks/useRealtimeObservation.ts:241-296` (merges REST `/current` baseline + SSE; exposes `Observation | null`).
- TS Observation type: `api/types.ts:139-201`; wind fields `:147-150`; `beaufort` `:173-177`; `windDirCardinal` `:187-192`; add the two new fields after `:150`. `ConvertedValue` = `{value,label,formatted}`.

**Mockups / tokens:**
- Grid + glass tokens to copy: `../design/mockups/A4-page-anatomy.html` (`:root` `:9-79`, `.grid-4col` `:195-204`, `.card` `:206-219`).
- @font-face + type tokens: `../design/design-tokens-typography.md` (and the live specimen `../design/mockups/C2pre-type-system.html`). Fonts: `../design/mockups/fonts/` (manrope/outfit/lexend, 400/600/700).
- Rejected prior mockups (salvage tick-math only): `../design/mockups/C2-wind-card.html`, `C2-wind-card-v2.html`, `C2-wind-compass.html`.

## 10. Out of scope
No new weewx columns; no data-fetch/conversion changes beyond the two BFF-derived fields; no other Now-page cards; no operator drag-grid engine.

---
*Authored from the operator-approved plan `~/.claude/plans/i-said-fucking-include-sparkling-whistle.md`. On C2 close, capture rule-shaped lessons into the relevant `rules/<domain>.md` and decision-log facts into [UI-REDESIGN-PLAN.md](UI-REDESIGN-PLAN.md) per [../../CLAUDE.md](../../CLAUDE.md) "Capture lessons in the right place".*
