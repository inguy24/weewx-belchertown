# Haze Detection Threshold Corrections — Execution Plan

**Status:** COMPLETE — All three fixes deployed: clean-sky sample filter corrected to exact match, PM thresholds updated to meteorological haze values, haze coherence window reduced to 5 min. Archived 2026-06-27.  
**Created:** 2026-06-24  
**Components:** API (`weewx-clearskies-api`), Dashboard (`weewx-clearskies-dashboard`)

---

## Context

Live testing on 2026-06-24 revealed the haze detection engine falsely reporting "Hazy" under clear SoCal skies with PM2.5 = 11-12 µg/m³ and AQI = 46 ("Good"). Root cause analysis uncovered three bugs:

1. **Auto-calibration clean-sky sample filter uses substring matching.** `_CLEAN_SKY_SUBSTRINGS = ("Clear", "Sunny")` matches "Mostly Clear" because it contains "Clear". Cloud-enhancement-adjacent readings (Kcs 1.0–1.06) under "Mostly Clear" skies leak into the clean-sky pool, inflating the June baseline to **1.035** — physically impossible for a clean sky (Kcs = GHI/maxSolarRad should not routinely exceed 1.0). The docs and ADR said "clear days only" but the code used substring matching.

2. **PM confirmation thresholds are EPA health standards, not meteorological haze thresholds.** PM2.5 > 12 µg/m³ is the EPA AQI "Good/Moderate" breakpoint — a health standard with zero relationship to visible haze. No meteorological service worldwide uses 12 µg/m³ for haze observation. PM10 > 50 µg/m³ is treated as a fallback instead of an independent first-class indicator.

3. **Haze coherence window is still 15 minutes (900s).** Was supposed to be reduced to 5 minutes (300s) to match the sky classifier coherence, but the change was never made.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — coding standards
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates

**Repos:**
- `weewx-clearskies-api` — local clone at `repos/weewx-clearskies-api` (branch: `main`).
- `weewx-clearskies-dashboard` — local clone at `repos/weewx-clearskies-dashboard` (branch: `main`). Build: `npm run build` (= `tsc -b && vite build`).

**Testing runs on the weewx container, NOT weather-dev.** The API is installed natively on the weewx LXD container. Tests run there:
```bash
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py --tb=short -q"
```
Do NOT install the API or run API tests on weather-dev. weather-dev is for dashboard and config UI only.

**Deploy after code changes:**
1. Push to GitHub from DILBERT
2. `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && git pull --ff-only"`
3. `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm)

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase. No phase advances until coordinator signs off.

---

## 1. Research Summary — PM Thresholds for Visible Haze

### The problem with our current thresholds

| Channel | Current threshold | Source of threshold | Problem |
|---------|------------------|--------------------|---------| 
| PM2.5 dry haze | > 12 µg/m³ | EPA AQI "Good/Moderate" breakpoint | Health standard, not haze observation. No meteorological service uses this. |
| PM2.5 humid disambig | > 35 µg/m³ (T-Td ≤ 4°F only) | Correct value, wrong gate — only fires in near-saturated conditions | Too restrictive — only applies at T-Td ≤ 4°F |
| PM10 coarse dust | > 50 µg/m³ | EPA daily / EEA daily standard | Treated as last-resort fallback; should be independent channel |

### Research findings — multi-source, multi-tradition

**US — IMPROVE network and EPA Regional Haze:**
The IMPROVE reconstructed extinction equation (Malm et al. 1994, revised Pitchford et al. 2007) provides the physics-based framework for PM-to-visibility conversion:
- `bext ≈ 3×f(RH)×[Ammonium Sulfate] + 3×f(RH)×[Ammonium Nitrate] + 4×[Organic Mass] + 10×[Elemental Carbon] + 1×[Fine Soil] + 0.6×[Coarse Mass]`
- Fine particles (PM2.5 components): mass extinction efficiency 3–10 m²/g depending on species
- Coarse particles (PM10 minus PM2.5): mass extinction efficiency **0.6 m²/g** — roughly 5–17x LESS light scattering per gram than fine particles
- Coarse mass carries mass but scatters light inefficiently compared to fine particles
- **Both PM2.5 and PM10 contribute to extinction** — PM2.5 is more efficient per gram, but PM10 can dominate when coarse loading is high (dust storms, construction, wildfire ash)

**US — NWS/ASOS:**
ASOS reports haze (HZ) when visibility < 7 statute miles (~11.3 km). No PM concentration threshold — uses visibility sensor only. Haze is distinguished from fog/mist by RH (haze occurs at lower humidity).

**China — CMA operational guidance:**
- Haze: visibility < 10 km AND RH < 90%
- PM2.5 threshold for vis < 10 km: **54 µg/m³** (recommended hourly minimum, dry conditions)
- At RH 70–80%: threshold drops to **~40 µg/m³** (hygroscopic aerosol swelling)
- PM10 "dusty air": **50–200 µg/m³**
- China secondary air quality standard: **35 µg/m³** PM2.5 (used as haze breakpoint in many studies)

**Korea — KMA:**
- Haze: visibility < 10 km AND RH < 75%
- No specific PM concentration threshold in KMA criteria

**Europe — EEA:**
- PM10 daily standard: **50 µg/m³**
- PM2.5 annual standard: **25 µg/m³** (health, not haze)
- No specific haze observation PM threshold

**Australia — BOM:**
- Follows WMO protocols
- PM10 24-hour standard: **50 µg/m³**
- Dust haze: visibility < 10 km

**India — CPCB:**
- PM10 24-hour standard: **100 µg/m³**
- PM2.5 24-hour standard: **60 µg/m³**

**WMO — International:**
- Dust haze: visibility < 10 km, "dusty air" = PM10 50–200 µg/m³
- Haze (code 05): visibility < 1 km with suspended particles
- WMO distinguishes haze from fog by RH (haze at lower humidity)

**Wildfire smoke research:**
- Ground-level PM2.5 during wildfire events: **35+ µg/m³** (research baseline)
- Visibility impairment during smoke events correlates strongly with PM2.5 > 35

### Key insight: PM2.5 vs PM10 are independent indicators, not alternatives

PM2.5 and PM10 measure different aerosol populations:
- **PM2.5**: combustion byproducts, photochemical smog, secondary organic aerosol — high extinction efficiency (3–10 m²/g)
- **PM10 (coarse fraction)**: mineral dust, sea salt, pollen, construction dust, wildfire ash — lower extinction efficiency (0.6 m²/g) but can reach very high mass concentrations

In our two-channel algorithm, PM confirmation is not detecting haze by itself — it confirms that a Kcs deficit observed by the pyranometer is likely aerosol-caused rather than cloud-caused. Either PM species elevated above background confirms aerosol loading.

### Corrected thresholds — RH-graduated, both species independent

Channel 1 (Kcs deficit) and Channel 2 (PM confirmation) both involve humidity but correct for **different physical phenomena**. Channel 1's f(RH) adjusts the deficit threshold because humidity inflates the Kcs gap even in clean air — that's the optical effect on the pyranometer. Channel 2's RH graduation adjusts how much particulate mass it takes to cause visible haze — at high humidity, aerosol particles absorb water and swell (hygroscopic growth), scattering more light per gram of dry mass. These are independent corrections for independent physics.

PM10 thresholds scale at roughly the extinction efficiency ratio from the IMPROVE equation: coarse mass (0.6 m²/g) vs fine mass (3–4 m²/g) — coarse particles need ~5–6x more mass to produce equivalent extinction.

| RH range | PM2.5 threshold | PM10 threshold | Basis |
|----------|----------------|----------------|-------|
| **< 60%** (dry) | > 50 µg/m³ | > 100 µg/m³ | CMA dry haze threshold (~54 µg/m³ PM2.5 for vis < 10 km). Coarse mass scaled by extinction ratio. |
| **60–80%** (moderate) | > 35 µg/m³ | > 75 µg/m³ | CMA moderate humidity, EPA 24-hr NAAQS (35), WMO dusty-air midpoint, China secondary standard. |
| **80–90%** (humid) | > 25 µg/m³ | > 50 µg/m³ | Hygroscopic swelling — less mass produces same extinction. EEA annual standard (25), WMO/Australia lower bound (50). |

**Structure:** Both PM2.5 and PM10 are independent first-class indicators evaluated in parallel. Either alone confirms Channel 2. PM10 is NOT a fallback.

**Removed:** The humid disambiguation check (T-Td ≤ 4°F + PM2.5 > 35) is eliminated. That gate belongs in fog_condition (which already has it at Gate 5). In the haze module, if T-Td ≤ 4°F, the fog module fires first and fog_condition returns "Hazy" when PM2.5 > 35 (its Gate 5). The haze module should not duplicate that logic.

### Sources

- [IMPROVE Algorithm — extinction reconstruction](https://vista.cira.colostate.edu/Improve/the-improve-algorithm/)
- [Pitchford & Malm (2007) — Revised IMPROVE equation](https://www.tandfonline.com/doi/full/10.1080/10962247.2016.1178187)
- [PM2.5 threshold 54 µg/m³ for vis < 10 km — north China](https://www.sciencedirect.com/science/article/abs/pii/S0169809520303574)
- [Consistency between visibility and PM2.5 measurements](https://pmc.ncbi.nlm.nih.gov/articles/PMC9861879/)
- [Aerosol extinction reconstruction and haze identification — China](https://aaqr.org/articles/aaqr-20-07-oa-0386)
- [Sensitivity of visibility to PM2.5 and RH by aerosol type](https://www.mdpi.com/2073-4433/13/3/471)
- [PM2.5/PM10 ratio and aerosol type characterization](https://www.sciencedirect.com/science/article/abs/pii/S2212095523003577)
- [PM10 and visibility during Middle Eastern dust storms](https://pmc.ncbi.nlm.nih.gov/articles/PMC9163216/)
- [WMO dust haze definition — UNDRR](https://www.undrr.org/understanding-disaster-risk/terminology/hips/mh0203)
- [Hygroscopic particle growth and visibility](https://www.nature.com/articles/s41598-021-95834-6)
- [PM2.5 and visibility in Beijing (Wang 2019)](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2018JD029269)
- [Koschmieder equation — compact visibility prediction algorithms](https://aaqr.org/articles/aaqr-19-06-opaa-0286)
- [NWS Observing Handbook No. 8 — ASOS haze criteria](https://www.weather.gov/media/surface/WSOH8.pdf)
- [ASOS User's Guide](https://www.weather.gov/media/asos/aum-toc.pdf)
- [EPA IMPROVE visibility analysis](https://www.epa.gov/sites/default/files/2015-05/documents/chap01.pdf)
- [India CPCB NAAQS](https://cpcb.nic.in/air-quality-standard/)
- [EEA air quality status 2026](https://www.eea.europa.eu/en/analysis/publications/air-quality-status-report-2026/particulate-matter-pm10)
- [Australia dust storm PM10 impacts](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9107411/)

---

## 2. Implementation Phases

### PHASE 1 — Documentation Updates (agents depend on manuals for guidance)

**T1.1 — Update API-MANUAL.md haze detection section**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/API-MANUAL.md` — §8 Haze detection (~lines 795–930)
- Changes:
  - PM thresholds: replace 12 µg/m³ with RH-graduated values — PM2.5: 50/35/25, PM10: 100/75/50 (dry/moderate/humid)
  - Remove humid disambiguation description (T-Td ≤ 4°F path)
  - Document PM10 as independent first-class channel, not fallback
  - Coherence window: replace "15-minute" with "5-minute" and "900 s" with "300 s" throughout
  - Auto-calibration section: replace "contains Clear or Sunny" with "exactly Clear or Sunny"
  - Add research citations for threshold selection (IMPROVE, CMA, WMO, EPA NAAQS)
- Accept: All threshold values in §8 reflect the corrected design. No references to 12 µg/m³, 900s, or substring matching.

**T1.2 — Update ARCHITECTURE.md conditions text engine section**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/ARCHITECTURE.md` — "Conditions text engine" section (~lines 273–302)
- Changes:
  - Haze condition module description (line 284): update "two-channel (Kcs deficit + PM)" to include the corrected thresholds
  - Auto-calibration module description (line 285): clarify "clean-sky" means exact "Clear"/"Sunny" labels only
- Accept: ARCHITECTURE.md matches the corrected design.

**T1.3 — Save research reference document**
- Owner: `clearskies-docs-author` (Sonnet)
- File: New `docs/reference/haze-detection-research.md`
- Content: Full research summary from §1 of this plan — IMPROVE equation, multi-tradition threshold survey, PM2.5 vs PM10 extinction physics, source citations. This is the reference backing the threshold choices; the manuals cite it.
- Accept: Document exists with all sources from §1. Cited by API-MANUAL §8.

**T1.4 — Update rules/clearskies-process.md with lessons**
- Owner: Coordinator (Opus) — direct
- Add rule under "Belchertown reference discipline" or as new section:
  - "Verify external thresholds against primary meteorological research before coding. EPA AQI breakpoints are health standards, not meteorological observation thresholds. Use IMPROVE, WMO, NWS, CMA, and peer-reviewed atmospheric science as sources for visibility and haze parameters."
  - "Exact label matching for sample filters. When a filter says 'clear days,' use `label in {"Clear", "Sunny"}`, not substring matching on 'Clear'. Substring matching is a category error."

**T1.5 — Update reference/clearskies-dev.md testing section**
- Owner: Coordinator (Opus) — direct
- Add/correct in the "Common commands" section:
  - **API tests run on the weewx container**, not weather-dev. The API is installed on weewx. weather-dev is for dashboard and config UI only.
  - Add targeted test commands for condition modules:
    ```bash
    # Haze + calibration tests only (~145 tests, ~15 seconds)
    ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py --tb=short -q"

    # All four condition modules (~260 tests, ~30 seconds)
    ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py tests/test_sky_condition.py tests/test_fog_condition.py --tb=short -q"

    # Full suite (only when needed, ~3600 tests)
    ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q"
    ```

**QC (Opus) — after Phase 1:** Read API-MANUAL §8 and ARCHITECTURE.md conditions section. Verify all threshold values, coherence windows, and sample filter descriptions match the corrected design. Check research doc exists with multi-tradition sources. Check clearskies-dev.md has correct test commands pointing to weewx.

---

### PHASE 2 — API Code Fixes (3 bugs)

**T2.1 — Fix clean-sky sample filter: exact label match, not substring**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/sse/auto_calibration.py`
- Line 67: Change `_CLEAN_SKY_SUBSTRINGS` to `_CLEAN_SKY_LABELS`
- Line 242: Change `any(sub in sky_label for sub in _CLEAN_SKY_SUBSTRINGS)` to `sky_label in _CLEAN_SKY_LABELS`
- New value: `_CLEAN_SKY_LABELS: frozenset[str] = frozenset({"Clear", "Sunny"})`
- Do NOT accept "Mostly Clear", "Mostly Sunny", or any other label. Only exact "Clear" or "Sunny" qualify as clean-sky samples.
- Accept: Only exact matches pass Gate 3. `"Mostly Clear"` is rejected. `"Clear"` and `"Sunny"` pass.

**T2.2 — Fix PM confirmation thresholds and structure**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/sse/haze_condition.py`
- Changes:
  - `_DEFICIT_THRESHOLD` comment: update to cite research, not EPA
  - PM confirmation section (~lines 228–260): Replace three-step fallback with RH-graduated independent checks. RH is already computed earlier in the function. Structure:
    ```python
    # Determine RH-graduated thresholds
    if rh is not None and rh >= 80.0:
        pm25_threshold, pm10_threshold = 25.0, 50.0
    elif rh is not None and rh >= 60.0:
        pm25_threshold, pm10_threshold = 35.0, 75.0
    else:  # RH < 60% or RH unknown (conservative)
        pm25_threshold, pm10_threshold = 50.0, 100.0

    # Either species alone confirms Channel 2
    if pm25 is not None and pm25 > pm25_threshold:
        pm_confirmed = True
    if not pm_confirmed and pm10 is not None and pm10 > pm10_threshold:
        pm_confirmed = True
    ```
  - Remove the humid disambiguation block (T-Td ≤ 4°F + PM2.5 > 35) — that logic belongs in fog_condition, which already handles it
  - Update module docstring to cite research sources, not EPA breakpoints
  - Add constants at module level for the three RH tiers (dry/moderate/humid thresholds) with research citations in comments
- Accept: At RH 50%: PM2.5=49 → not confirmed, PM2.5=51 → confirmed. At RH 70%: PM2.5=34 → not confirmed, PM2.5=36 → confirmed. At RH 85%: PM2.5=24 → not confirmed, PM2.5=26 → confirmed. PM10 follows same pattern at its thresholds. Either species alone suffices. Both None → not confirmed.

**T2.3 — Fix haze coherence window: 900s → 300s**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/sse/haze_condition.py`
- Line 73: Change `cutoff = now - 900.0` to `cutoff = now - 300.0`
- Line 355: Change `cutoff = now - 900.0` to `cutoff = now - 300.0`
- Update docstring (lines 23–25): "15-minute" → "5-minute", "900 s" → "300 s"
- Update `_record_history` docstring (line 353): "15 min" → "5 min"
- Update `_evaluate_coherence` docstring (line 361): "15-minute" → "5-minute"
- Accept: History entries older than 300s are pruned. Coherence evaluates over 5-minute window.

**QC (Opus) — after Phase 2:** Read all three modified files. Verify: (a) `auto_calibration.py` Gate 3 uses `sky_label in _CLEAN_SKY_LABELS` with a frozenset, not substring. (b) `haze_condition.py` PM section has RH-graduated independent checks, no fallback structure, no T-Td disambiguation. (c) All `900` references in haze_condition.py are now `300`. No other files modified. Cross-check code against the updated API-MANUAL §8 from Phase 1.

---

### PHASE 3 — Test Updates

**T3.1 — Update haze_condition tests for new thresholds and coherence window**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_haze_condition.py` (783 lines, 54 tests)
- Changes:
  - PM threshold tests (lines ~215–280): Replace all boundary-value tests with RH-graduated tests across three tiers:
    - Dry (RH < 60%): PM2.5 boundary at 50, PM10 boundary at 100
    - Moderate (RH 60–80%): PM2.5 boundary at 35, PM10 boundary at 75
    - Humid (RH 80–90%): PM2.5 boundary at 25, PM10 boundary at 50
    - RH unknown: uses dry (conservative) thresholds
  - Remove humid disambiguation tests (T-Td ≤ 4°F path) — that logic is removed
  - Add test: PM10 alone (no PM2.5 data) confirms Channel 2 at each RH tier
  - Add test: PM2.5 alone (no PM10 data) confirms Channel 2 at each RH tier
  - Coherence window tests (lines ~328–512): Update all timing from 900s to 300s
  - Ensure existing gate tests (solar elevation, sky label, wet deposition, RH) are unchanged
- Accept: All haze tests pass with new thresholds. No test references 12.0 or 900.

**T3.2 — Update auto_calibration tests for exact label matching**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_auto_calibration.py` (1328 lines, 91 tests)
- Changes:
  - Gate 3 tests (process_packet sky label filtering, lines ~470–645): Update to verify "Mostly Clear" is REJECTED, "Clear" and "Sunny" are accepted
  - Add test: "Mostly Sunny" is rejected (previously passed via substring)
  - Verify existing tests for "Overcast", "Partly Cloudy" still rejected
- Accept: All calibration tests pass. Test explicitly asserts "Mostly Clear" → sample rejected.

**Testing command (run on weewx):**
```bash
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py --tb=short -q"
```

**QC (Opus) — after Phase 3:** Run the targeted test command above. Verify pass count. Spot-check one PM boundary test and one sky-label-rejection test in the code.

---

### PHASE 4 — Deploy + Reset Calibration Data

**T4.1 — Delete poisoned calibration data and restart API**
- Owner: Coordinator (Opus) — direct, no agent needed
- Do:
  1. After code is deployed to weewx (push + pull + restart), delete the calibration file:
     `ssh -F .local/ssh/config weewx "sudo rm /etc/weewx-clearskies/calibration.json"`
  2. Restart the API:
     `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"`
  3. Wait 2 minutes for cache warm, then verify:
     `ssh -F .local/ssh/config weewx "sudo journalctl -u weewx-clearskies-api -n 20 --no-pager"` — should show no calibration restore message
  4. Verify haze is no longer firing:
     `ssh -F .local/ssh/config weewx "curl -sk https://localhost:8765/api/v1/current"` — weatherText should not contain "Hazy"
- Accept: calibration.json deleted. API starts fresh with default baseline (0.90). "Hazy" no longer appears under current conditions (PM2.5 = 11, well below 35 threshold).

---

### PHASE 5 — Haze Hero Icons (Dashboard)

Two new weather icon glyphs: `GlyphHazy` (day) and `GlyphHazyNight` (night). Mapped to WMO code 5 (haze). Composition: sun or moon clipped at y=16.5, fog-style horizontal stripes below in a brown haze gradient. The sun/moon is terminated cleanly above the haze lines — no bleed-through between stripes (same occlusion pattern as partly cloudy cloud over sun).

**Approved prototype:** `scratchpad/haze-icon-prototype.html` — **Option B (Amber)** selected: `#CDAA6D` (top) → `#A07840` (bottom).

**T5.1 — Add haze gradient and two glyph functions to weather-icon-glyphs.tsx**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/weather-icon-glyphs.tsx`
- Changes:
  - Add `hazeGrad` to `GradientDefs`: brown linear gradient (top → bottom), chosen option from prototype
  - Add `GlyphHazy({ size })`: SVG with `<clipPath>` rect (x=0 y=0 w=24 h=16.5) applied to the GlyphSunny path (gold gradient, clipped), then fog-stripe subpaths (bars + dots from foggy.svg bottom portion, absolute coordinates) filled with `hazeGrad`. Layer order: clipped sun first, haze stripes on top.
  - Add `GlyphHazyNight({ size })`: Same structure but with GlyphBedtime moon path (moon gradient, clipped) instead of sun.
  - ClipPath IDs scoped with `useId()` prefix, same pattern as existing glyphs.
  - Haze stripe paths (extracted from foggy.svg, absolute coords):
    ```
    M6 19q-.425 0-.712-.288T5 18t.288-.712T6 17h9q.425 0 .713.288T16 18t-.288.713T15 19z
    M18 19q-.425 0-.712-.288T17 18t.288-.712T18 17t.713.288T19 18t-.288.713T18 19
    M10 22q-.425 0-.712-.288T9 21t.288-.712T10 20h7q.425 0 .713.288T18 21t-.288.713T17 22z
    M7 22q-.425 0-.712-.288T6 21t.288-.712T7 20t.713.288T8 21t-.288.713T7 22
    ```
- Accept: Both glyphs render at 96px on dark and light backgrounds. Sun/moon cleanly terminated above stripes. Brown stripes visually distinct from grey fog stripes. No sun/moon showing between stripes.

**T5.2 — Wire WMO code 5 into weather-icon.tsx and add mist code 10**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/weather-icon.tsx`
- Changes:
  - Import `GlyphHazy` and `GlyphHazyNight` from `./weather-icon-glyphs`
  - Add to `WMO_MAP`:
    ```
    5:  { day: GlyphHazy, night: GlyphHazyNight, descriptionKey: 'wmo.5' },
    10: { day: GlyphFoggy,                       descriptionKey: 'wmo.10' },
    ```
  - WMO code 5 = haze, code 10 = mist (both emitted by the API's `_derive_weather_code()` in weather_text.py)
- Accept: `<WeatherIcon code={5} />` renders haze day glyph. `<WeatherIcon code={5} isNight />` renders haze night glyph. `<WeatherIcon code={10} />` renders foggy glyph (mist).

**T5.3 — Add i18n description keys for WMO codes 5 and 10**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `repos/weewx-clearskies-dashboard/public/locales/en/weather.json` + 12 other locale files
- Changes: Add `"wmo.5": "Haze"` and `"wmo.10": "Mist"` (translated per locale)
- Accept: Screen reader sr-only span announces "Haze" / "Mist" in the correct language.

**Testing:** `tsc --noEmit` passes. `npm run build` clean. Visual verification of both glyphs at hero size on dark and light backgrounds on weather-test.shaneburkhardt.com after deploy.

**QC (Opus) — after Phase 5:** Open the built dashboard. Verify WMO code 5 renders the haze day icon (gold clipped sun + brown stripes). Verify `isNight` variant renders moon + brown stripes. Compare against the approved prototype HTML. Verify brown stripes are visually distinct from grey fog stripes. Verify WMO code 10 (mist) renders the existing foggy glyph. Check all 13 locale files have `wmo.5` and `wmo.10` keys. `tsc --noEmit` + `vite build` clean.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 1 | T1.1 API-MANUAL update | `clearskies-docs-author` | Sonnet | After Phase 1 |
| 1 | T1.2 ARCHITECTURE.md update | `clearskies-docs-author` | Sonnet | After Phase 1 |
| 1 | T1.3 Research reference doc | `clearskies-docs-author` | Sonnet | After Phase 1 |
| 1 | T1.4 Process rules update | Coordinator (Opus) | — | Inline |
| 1 | T1.5 Dev reference update | Coordinator (Opus) | — | Inline |
| 2 | T2.1 Clean-sky filter fix | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 2 | T2.2 PM threshold fix | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 2 | T2.3 Coherence window fix | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 3 | T3.1 Haze tests update | `clearskies-test-author` | Sonnet | After Phase 3 |
| 3 | T3.2 Calibration tests update | `clearskies-test-author` | Sonnet | After Phase 3 |
| 4 | T4.1 Deploy + reset calibration | Coordinator (Opus) | — | Inline |
| 5 | T5.1 Haze glyph components | `clearskies-dashboard-dev` | Sonnet | After Phase 5 |
| 5 | T5.2 WMO code mapping | `clearskies-dashboard-dev` | Sonnet | After Phase 5 |
| 5 | T5.3 i18n description keys | `clearskies-dashboard-dev` | Sonnet | After Phase 5 |

**Sequencing:** Phase 1 (docs first — agents read manuals for guidance) → Phase 2 (API code, depends on updated manuals) → Phase 3 (API tests, depends on code changes) → Phase 4 (deploy + reset, depends on tests passing) → Phase 5 (dashboard icons, independent of API phases — can run in parallel with Phases 2–4)

**Phase 2 can be a single agent** doing all three API fixes in one file-editing session — the changes are small, focused, and in two files. **Phase 5 can be a single agent** doing all three dashboard tasks in one session — they're in the same repo and closely related.

---

## 4. Verification

**After Phase 1 (doc-code sync):**
- grep API-MANUAL.md for "12" in the haze section — should find zero matches for the old PM threshold
- grep API-MANUAL.md for "900" — should find zero matches for the old coherence window
- grep ARCHITECTURE.md for "substring" — should find zero matches

**After Phase 3 (targeted tests on weewx):**
```bash
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py --tb=short -q"
```
Expected: all tests pass, 0 failures.

**After Phase 4 (live verification):**
1. `curl -sk https://localhost:8765/api/v1/current` — weatherText should NOT contain "Hazy" (PM2.5 = 11, well below 35)
2. `journalctl` — no calibration file loaded message
3. `curl -sk https://localhost:8765/api/v1/aqi/current` — confirm PM2.5 and PM10 values are below new thresholds

**After Phase 5 (dashboard verification):**
- `tsc --noEmit` passes, `npm run build` clean
- Visual verification of haze day/night icons at weather-test.shaneburkhardt.com

---

## 5. Files Modified

**Docs (Phase 1):**
- `docs/manuals/API-MANUAL.md` — §8 haze detection
- `docs/ARCHITECTURE.md` — conditions text engine section
- `docs/reference/haze-detection-research.md` — new research reference
- `rules/clearskies-process.md` — new rule about threshold research
- `reference/clearskies-dev.md` — testing commands corrected

**API Code (Phase 2):**
- `weewx_clearskies_api/sse/auto_calibration.py` — line 67 (constant), line 242 (filter)
- `weewx_clearskies_api/sse/haze_condition.py` — PM section (~lines 228–260), coherence window (lines 73, 355), docstrings

**API Tests (Phase 3):**
- `tests/test_haze_condition.py` — PM threshold tests, coherence timing tests, remove humid disambig tests
- `tests/test_auto_calibration.py` — Gate 3 sky label tests

**Data (Phase 4):**
- `/etc/weewx-clearskies/calibration.json` on weewx — deleted (reset)

**Dashboard (Phase 5):**
- `src/components/weather-icon-glyphs.tsx` — new `hazeGrad` gradient, new `GlyphHazy` and `GlyphHazyNight` functions
- `src/components/weather-icon.tsx` — WMO codes 5 (haze) and 10 (mist) added to `WMO_MAP`
- `public/locales/*/weather.json` — 13 locale files, add `wmo.5` and `wmo.10` keys
