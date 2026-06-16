today# UI Polish, Wizard Gaps & Privacy/Legal Compliance — Execution Plan

**Status:** ACTIVE  
**Created:** 2026-06-10  
**Components:** Dashboard SPA (`weewx-clearskies-dashboard`), Config Wizard (`weewx-clearskies-stack`), API (`weewx-clearskies-api`)

---

## Context

During live testing of the dashboard, the operator identified visual polish issues (forecast header freshness text, moon phase label overlapping other elements, "AQI" abbreviation, underlined provider links) and a systemic gap: the setup wizard doesn't expose several operator-configurable fields that the API already supports (accent color, theme mode, social URLs, etc.). Additionally, the project needs:

- A proper EULA (operator license agreement, adapted from the Numisync Wizard EULA)
- Default Terms of Use and Privacy Policy documents for end-user website visitors
- An Accessibility Statement
- A cookie consent banner for GDPR/CCPA compliance when operators enable Google Analytics
- Google Analytics integration (page view tracking, conditional on visitor consent)
- Continent-based jurisdiction filtering so the Legal page only shows relevant privacy/accessibility laws

Four dashboard UI tweaks were already implemented and committed (`dc2fb0a` on dashboard `main`). This plan covers the remaining tweaks, wizard gaps, and the full privacy/legal infrastructure.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §5 WCAG accessibility, §6 Recharts, §7 build verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind + shadcn/ui). Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `weewx-clearskies-stack` — Config wizard (Jinja2 + HTMX + Pico CSS). No build step. Branch: `main`.
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. Lint: `ruff check`, `mypy`.

**Deploy (from any machine with replicated project files):**
- SSH config: `.local/ssh/config` (project-local, replicated via Nextcloud)
- Dashboard: `bash scripts/redeploy-weather-dev.sh` (pulls, restarts services, builds, publishes to web root)
- Wizard: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm cache)
- Direct SSH: `ssh -F .local/ssh/config weather-dev`, `ssh -F .local/ssh/config weewx`, `ssh -F .local/ssh/config ratbert`

**Key ADRs:**
- ADR-022 — Theming/branding: 6 curated accents, logo upload + alt text, custom CSS slot, default theme mode
- ADR-023 — Light/dark mode: data-theme attribute, 4 modes (light/dark/auto-os/auto-sunrise-sunset)
- ADR-024 — Page taxonomy: About page = operator-authored markdown; Legal page = privacy + attribution + open source
- ADR-026 — Accessibility: WCAG 2.1 AA floor, release-blocking, per-change audit checklist
- ADR-027 — Config wizard: 6-step flow, branding/theme marked "NOT collected" for v0.1 but API already supports it
- ADR-043 — skin.conf compliance: import carries social URLs into wizard state
- ADR-055 — Client data refresh: stale-while-revalidate (already implemented, verify no regression)

**Numisync EULA reference:** Full text captured from `https://github.com/inguy24/Numisync-Wizard/EULA.txt` via `gh api`. 24 sections covering acceptance, license grant, restrictions, third-party services, privacy, California law, IP, warranties, liability, indemnification, arbitration, class action waiver, force majeure, severability, termination. Adapt for GPL v3 weather dashboard — remove proprietary license tiers, Polar.sh, device fingerprints; add operator responsibility for legal compliance.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** The coordinator performs QC after EVERY phase completes — not batched at the end. No phase advances until the coordinator signs off. QC evidence is recorded in the scratchpad before the next phase begins.

---

## 1. Gap Inventory

### A. Dashboard UI Polish

| # | Item | Status | Fix |
|---|------|--------|-----|
| A1 | Forecast page header shows "Updated X minutes ago · aeris" | **DONE** (committed `dc2fb0a`) | Removed `info` prop and dead helper from `forecast.tsx` |
| A2 | Moon phase label overlaps moon sprite and other text | **DONE** (committed `dc2fb0a`) | Centered in arc at (CX, CY-22) in `sun-moon-card.tsx` |
| A3 | AQI card title says "AQI" instead of "Air Quality" | **DONE** (committed `dc2fb0a`) | Changed in `public/locales/en/now.json` |
| A4 | About page provider links have underlines | **DONE** (committed `dc2fb0a`) | Removed `underline underline-offset-4` from `about.tsx` |
| A5 | Reports page header has generic intro text | TODO | Remove `info={t('intro')}` from `reports.tsx` line 696 |
| A6 | Non-English locales missing `aqiCard.title` | TODO | Add `aqiCard` section to 12 locale `now.json` files, copying existing `airQuality` value |

### B. Wizard Configuration Gaps

| # | Field | API Support | Wizard UI | Fix |
|---|-------|-------------|-----------|-----|
| B1 | Accent color | `BrandingApplyConfig.accent` (6 options) | Missing | Add `<select>` to appearance step |
| B2 | Default theme mode | `BrandingApplyConfig.default_theme_mode` (4 options) | Missing | Add `<select>` to appearance step |
| B3 | Logo alt text | `BrandingApplyConfig.logo_alt` | Missing | Add `<input>` to appearance step (WCAG §5.5) |
| B4 | Custom CSS URL | `BrandingApplyConfig.custom_css_url` | Missing | Add `<input>` to appearance step |
| B5 | Social media URLs | `SocialApplyConfig` (4 fields) | Missing | Add fieldset to appearance step |
| B6 | Google Analytics tracking ID | Not in API yet | Missing | Needs API field + wizard field + consent banner trigger |

### C. Privacy, Legal & Cookie Consent

| # | Item | Status | Fix |
|---|------|--------|-----|
| C1 | EULA (operator license) | Missing | Author GPL v3 EULA adapted from Numisync; wizard Step 1 acceptance gate |
| C2 | Terms of Use (visitor-facing) | Missing | Author default template for Legal page |
| C3 | Privacy Policy gaps | Partial (has CCPA, GDPR, Quebec) | Add LGPD, UK GDPR, APPI, Australia Privacy Act, India DPDP, South Africa POPIA; continent-based filtering |
| C4 | Accessibility statement | Missing | Author default statement with continent-specific accessibility laws |
| C5 | Cookie consent banner | Missing | GDPR-compliant opt-in banner; blocks GA until consent |
| C6 | GA page view tracking | Missing | Dynamic gtag.js loader + React Router page view tracking |
| C7 | Wizard: GA tracking ID | Missing | Appearance step field + setup instructions |
| C8 | Wizard: policy override | Missing | Textarea fields for custom Terms/Privacy markdown |
| C9 | Multi-language legal content | Partial (en only) | Translate legal.json + EULA to all 13 locales |

### D. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred | Prerequisite |
|---------|-------------|-------------|
| Station photo upload | No API upload/storage endpoint | New API endpoint + ADR |
| About station text editing in wizard | No API write endpoint for `/content/{slug}` | New API endpoint |
| Hardware override field | No `hardware_override` in API `StationApplyConfig` | API schema change |

---

## 2. Implementation Phases

### PHASE 0 — EULA

**T0.1 — Author Clear Skies EULA (Operator License Agreement)**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: New `repos/weewx-clearskies-stack/weewx_clearskies_config/static/EULA.txt`, new `templates/wizard/step_eula.html`
- **Contract between the developer and the operator (not website visitors).** Adapted from the Numisync Wizard EULA with these changes:
  - GPL v3 license (not proprietary). No tiers, no keys, no activation.
  - **Operator responsibility** — solely responsible for: legal compliance in their jurisdiction and where their visitors are located; configuring privacy policies, cookie consent, and legal notices; complying with third-party service terms (Aeris, NWS, GA, map providers, etc.); any data their station collects/stores/transmits.
  - **We provide a tool, not legal advice.** Default legal templates are templates, not legal instruments.
  - **No warranty on legal compliance** — no guarantees the software or its default templates comply with any specific law.
  - Sections: (1) Acceptance, (2) License Grant (GPL v3), (3) Third-Party Services, (4) Data Collection/Privacy, (5) California Privacy Rights, (6) IP, (7) Disclaimer of Warranties (AS-IS, weather data not for safety-critical decisions), (8) Limitation of Liability, (9) Operator Responsibilities, (10) Indemnification, (11) No Obligation to Support, (12) Governing Law (California), (13) Arbitration, (14) Class Action Waiver, (15) Force Majeure/Severability/Waiver/Entire Agreement, (16) Termination, (17) Changes, (18) Contact.
- **Wizard integration:** Step 1 (before database config). Scrollable panel + checkbox. Acceptance timestamp in `WizardState.eula_accepted_at` → `api.conf [meta] eula_accepted_at`. Auto-advances on re-run if version unchanged; re-accept required on version change.
- Accept: EULA renders in Step 1. Cannot proceed without acceptance. Timestamp persisted. All 18 sections present.
- **QC (Opus):** Review content against GPL v3 §15-16, California law requirements, Numisync precedent. Verify wizard gate blocks progression.

### PHASE 1 — Remaining Dashboard UI Tweaks

**T1.1 — Remove Reports page header intro text**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/routes/reports.tsx` line 696
- Do: Remove `info={t('intro')}` from PageHeaderCard
- Accept: Reports header shows only title + icon. `tsc --noEmit` passes.

**T1.2 — Add `aqiCard` to non-English locale files**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: 12 files in `repos/weewx-clearskies-dashboard/public/locales/{de,es,fil,fr,it,ja,nl,pt-BR,pt-PT,ru,zh-CN,zh-TW}/now.json`
- Do: Add `"aqiCard": { "title": "<value>" }` using each file's existing `"airQuality"` value. Values: de=Luftqualität, es=Calidad del aire, fil=Kalidad ng Hangin, fr=Qualité de l'air, it=Qualità dell'aria, ja=大気質, nl=Luchtkwaliteit, pt-BR=Qualidade do Ar, pt-PT=Qualidade do Ar, ru=Качество воздуха, zh-CN=空气质量, zh-TW=空氣品質.
- Accept: All 13 locales have `aqiCard.title`. `JSON.parse` succeeds on each.

**QC (Opus) — after Phase 1:** Visual render of Reports page (no subtitle). Spot-check 3 locale files for valid JSON and correct `aqiCard.title` value. `tsc --noEmit` passes.

### PHASE 2 — Wizard Configuration Gaps

**T2.1 — Add new fields to WizardState**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/state.py`
- Do: Add 11 fields with `str = ""` defaults: `eula_accepted_at`, `logo_alt`, `accent`, `default_theme_mode`, `custom_css_url`, `facebook_url`, `twitter_url`, `instagram_url`, `youtube_url`, `google_analytics_id`, `privacy_regions`
- Accept: State round-trips through JSON serialization. No import errors.

**T2.2 — Add branding + social + GA + privacy region fields to appearance template**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_appearance.html`
- Do: Add to Branding fieldset: logo alt text input, accent color select (blue/teal/indigo/purple/green/amber), theme mode select (light/dark/auto-os/auto-sunrise-sunset), custom CSS URL input. New Social Media fieldset (facebook, twitter, instagram, youtube URL inputs). New Analytics fieldset (GA measurement ID input + setup instructions + consent notification text). New Privacy & Legal fieldset (continent checkboxes: North America, South America, Europe, Asia, Oceania, Africa + "Global" option).
- Accept: All fields render with labels, `aria-describedby`, pre-population from state.

**T2.3 — Wire POST handler, apply payload, merge, and review page**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py`, `templates/wizard/step_review.html`
- Do: (a) `step8_appearance_post`: save all new form fields to state. (b) `wizard_apply`: write branding + social fields to `branding.json` (Phase 4 T4.1 implements this; Phase 2 temporarily sends to API payload). (c) `_merge_from_existing_config`: merge branding + social fields from `branding.json` or `stack.conf`. (d) `wizard_index` prior-session merge. (e) `step_review.html`: add review rows for all new fields.
- Accept: Full round-trip — new wizard → fill → review → apply → re-run → fields pre-populate.

**QC (Opus) — after Phase 2:** Walk full wizard flow on weather-dev: Step 1 (EULA) → through Appearance step → verify all new fields appear → Review step → Apply → re-run wizard → verify pre-fill. Check `api.conf` on weather-dev for written values. JSON serialization round-trip of `WizardState`.

### PHASE 3 — Privacy Policy, Terms of Use, Accessibility & Consent

**T3.1 — Author default Terms of Use**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/public/locales/en/legal.json` (add `termsOfUse` section)
- Content: acceptance clause, service description (personal weather data, not professional meteorology), data accuracy disclaimer (AS-IS, not for safety-critical decisions), IP (GPL v3 software, factual weather data non-copyrightable), third-party services, prohibited conduct, limitation of liability (GPL v3 §15-16), modification clause, governing law placeholder, contact reference to About page.
- Accept: Terms of Use renders on Legal page as new card.

**T3.2 — Expand Privacy Policy with continent-based jurisdiction filtering**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `repos/weewx-clearskies-dashboard/public/locales/en/legal.json`, `src/routes/legal.tsx`
- Continent groups: North America (CCPA/CPRA, Quebec Law 25), South America (Brazil LGPD), Europe (EU GDPR + ePrivacy, UK GDPR + PECR), Asia (Japan APPI, India DPDP Act), Oceania (Australia Privacy Act), Africa (South Africa POPIA). "Global" = all.
- `legal.tsx` reads `privacyRegions` from branding API, renders only matching jurisdiction panels.
- Accept: Filtered rendering works. "Global" shows all. Default (no selection) = "Global" for safety.

**T3.3 — Author default Accessibility Statement**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `repos/weewx-clearskies-dashboard/public/locales/en/legal.json` (add `accessibility` section), `src/routes/legal.tsx`
- Content: WCAG 2.1 AA conformance target, known limitations (third-party content), how to report barriers, continent-specific accessibility laws (US ADA/Section 508, Canada AODA/ACA, Brazil Inclusion Law, EU EAA/EN 301 549, UK Equality Act, Japan JIS X 8341-3, India RPWD, South Korea KWCAG, Australia DDA, South Africa ICT rules). Same continent filtering as privacy. Operator responsibility disclaimer.
- Accept: Renders as card on Legal page. Continent-specific laws filtered by operator selection.

**T3.4 — Build cookie consent banner component**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `src/components/shared/cookie-consent-banner.tsx`, modify `src/components/layout/app-layout.tsx`, modify `src/lib/branding-provider.tsx`
- Behavior: Only renders when GA measurement ID configured. Equal-prominence Accept/Reject buttons. Consent in localStorage (`clearskies.cookie-consent`). GA blocked until consent. Respects `navigator.globalPrivacyControl`. "Cookie Settings" link in footer re-opens. Accessible: `role="dialog"`, focus trap, Escape = reject.
- Accept: Banner appears when GA configured + no consent stored. GA script absent from page until Accept. axe-core 0 violations.

**T3.5 — GA integration: script loader + page view tracking**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `src/lib/analytics.ts`, modify `src/components/layout/app-layout.tsx`
- Exports: `initGoogleAnalytics(measurementId)`, `removeGoogleAnalytics()` (clears `_ga`/`_gid`/`_gat` cookies), `trackPageView(path, title)`. Uses `useLocation()` from React Router for route-change tracking. GA4 only (Measurement ID format `G-XXXXXXXXXX`). Page views only for v0.1.
- Accept: GA loads after consent. Route changes visible in GA4 Realtime. Revoke removes script + cookies. No GA when no measurement ID.

**QC (Opus) — after Phase 3:** Content review of Terms of Use against GPL v3 §15-16 and ADR-018. Jurisdiction accuracy review of all new privacy sections against source regulations. Accessibility statement review against ADR-026. Cookie consent functional test: (1) no GA in page source before consent, (2) Accept loads GA, (3) Reject dismisses + no GA ever, (4) Cookie Settings re-opens banner, (5) GPC signal auto-rejects. WCAG audit of banner (focus trap, keyboard, contrast, aria). `tsc --noEmit` + `vite build` clean. axe-core on Legal page and consent banner.

### PHASE 4 — Branding Static File + Wizard: Policy Override

> **Architecture change (2026-06-10):** Branding config moves from the API (`/api/v1/branding`) to a static JSON file served by Caddy (`/branding.json`), per ADR-022 amendment. The API is a weather data access layer — branding is site presentation config. Same pattern as `webcam.json`: wizard writes, Caddy serves, dashboard reads.

**T4.1 — Wizard writes `branding.json` + Caddy route + dashboard fetch URL**
- Owner: Sonnet (stack + dashboard + stack/Caddyfiles)
- **Stack repo** files:
  - `weewx_clearskies_config/wizard/config_writer.py` — Add `write_branding_json(state, config_dir)` function that writes `/etc/weewx-clearskies/branding.json` with the full branding schema (siteTitle, copyrightEntity, logo, faviconUrl, accent, defaultThemeMode, customCssUrl, social, googleAnalyticsId, privacyRegions). Called from `wizard_apply`.
  - `weewx_clearskies_config/wizard/routes.py` — Apply function calls `write_branding_json` instead of sending branding to the API payload. Remove branding + social from `api_payload`.
  - `weewx_clearskies_config/wizard/state_persistence.py` — `populate_from_config` reads branding from `branding.json` on re-run (not from the API's `/setup/current-config`). Remove branding from `_merge_from_api_current_config`.
  - Three Caddyfiles (`examples/reverse-proxy/Caddyfile`, `frontend-host/Caddyfile`, `single-host/Caddyfile`) — Add `handle /branding.json { root * /etc/weewx-clearskies; file_server }` route.
- **Dashboard repo** files:
  - `src/lib/branding-provider.tsx` — Fetch from `/branding.json` instead of `/api/v1/branding`.
  - `src/lib/branding.ts` or `src/lib/client.ts` — Remove branding from the API client types/fetcher.
- Accept: Wizard apply writes `branding.json` to `/etc/weewx-clearskies/`. Dashboard reads from `/branding.json`. `branding.json` contains all fields (accent, theme, logos, social, GA ID, privacy regions). Re-run wizard pre-fills from `branding.json`. API payload no longer contains branding or social blocks.

**T4.2 — Add policy override fields to wizard**
- Owner: Sonnet (stack)
- Files: `state.py`, `step_appearance.html`, `routes.py`, `step_review.html`
- Do: Two optional `<textarea>` fields: "Terms of Use (Markdown)" and "Privacy Policy (Markdown)". When filled, written to `/etc/weewx-clearskies/content/terms.md` and `legal.md` on apply. Review step shows "Custom" or "Default".
- Accept: Operator can paste custom markdown. Apply writes files. Dashboard picks up override. Blank = built-in default.

**T4.3 — Wizard: GA setup instructions + consent notification**
- Owner: Sonnet (stack)
- File: `templates/wizard/step_appearance.html`
- Do: Collapsible setup instructions for creating GA4 property. Measurement ID input with `pattern="G-[A-Z0-9]+"`. Consent notification text explaining cookie banner implications. "What gets tracked" description (page views only).
- Accept: Instructions render. Format validation works. Notification text clear for non-technical operators.
- **NOTE:** GA Measurement ID input + pattern already added in Phase 2 (T2.2). This task adds only the collapsible setup instructions and consent notification text if not already present.

**QC (Opus) — after Phase 4:** Verify `branding.json` written to `/etc/weewx-clearskies/` with correct schema. Wizard round-trip: set GA ID + accent → apply → verify `branding.json` contains values → re-run → verify pre-fill from `branding.json`. Dashboard fetches from `/branding.json` (not API). Set custom Terms of Use markdown → apply → verify file written. API payload no longer contains branding. `tsc --noEmit` clean on dashboard.

### PHASE 5 — Locale Translations

**T5.1 — Translate legal.json to all supported locales**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: 12 files in `repos/weewx-clearskies-dashboard/public/locales/{de,es,fil,fr,it,ja,nl,pt-BR,pt-PT,ru,zh-CN,zh-TW}/legal.json`
- Do: Full translation including Terms of Use, Privacy Policy (all jurisdictions), Accessibility Statement. Brazil LGPD section MUST be in Portuguese (pt-BR) per LGPD requirement.
- Accept: All 13 locales have complete `legal.json`. Legal page renders correctly when switching locales.

**T5.2 — Translate EULA to all supported locales**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: EULA text in 12 additional locale files
- Do: Full EULA translation. Governing law (California) and arbitration clauses in English legal terms with translated context.
- Accept: Wizard EULA step renders in operator's selected language. All 13 locales complete.

**QC (Opus) — after Phase 5:** Spot-check 3 locales (de, ja, pt-BR) for: valid JSON, correct legal terminology, LGPD in Portuguese, EULA renders in wizard. Legal page renders all sections when switching locales in dashboard.

### PHASE 6 — Deploy & Final Verification

**T6.1 — Deploy dashboard**
- Owner: Coordinator (Opus)
- Do: `tsc --noEmit` passes. `npm run build` succeeds. Deploy via `scripts/redeploy-weather-dev.sh`.
- Accept: All pages render. Cookie banner appears when GA configured. Legal page shows Terms of Use + Accessibility Statement + Privacy Policy with correct jurisdiction filtering.

**T6.2 — Deploy wizard**
- Owner: Coordinator (Opus)
- Do: Restart `weewx-clearskies-config` service.
- Accept: EULA Step 1 gates progression. Appearance step shows all new fields. Full round-trip works.

**T6.3 — Verify branding.json served by Caddy**
- Owner: Coordinator (Opus)
- Do: Confirm `/branding.json` is served by Caddy from `/etc/weewx-clearskies/branding.json`. Verify dashboard reads it correctly. API restart no longer needed for branding changes.
- Accept: `curl https://weather-dev/branding.json` returns valid JSON with all branding fields.

**Final QC (Opus):** Walk every acceptance criterion from every task. Verify against ADR-022 (accent palette, logo alt, branding.json delivery), ADR-023 (theme modes), ADR-026 (WCAG AA on all new UI), ADR-027 (wizard scope), ADR-055 (no skeleton flash). Record evidence in scratchpad.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 0 | T0.1 EULA authoring + wizard step | `clearskies-stack-dev` | Sonnet | Content review vs GPL v3, California law, Numisync precedent; wizard gate test | After T0.1 completes |
| 1 | T1.1 Reports header | `clearskies-dashboard-dev` | Sonnet | Visual render | After Phase 1 |
| 1 | T1.2 Locale files | `clearskies-dashboard-dev` | Sonnet | JSON parse + spot-check 3 locales | After Phase 1 |
| 2 | T2.1 State fields | `clearskies-stack-dev` | Sonnet | Serialization round-trip | After Phase 2 |
| 2 | T2.2 Appearance template | `clearskies-stack-dev` | Sonnet | Visual verify all fields | After Phase 2 |
| 2 | T2.3 Wire POST/apply/merge/review | `clearskies-stack-dev` | Sonnet | Full wizard round-trip test | After Phase 2 |
| 3 | T3.1 Terms of Use | `clearskies-dashboard-dev` | Sonnet | Content review vs GPL v3 + ADR-018 | After Phase 3 |
| 3 | T3.2 Privacy Policy expansion | `clearskies-dashboard-dev` | Sonnet | Jurisdiction accuracy review | After Phase 3 |
| 3 | T3.3 Accessibility statement | `clearskies-dashboard-dev` | Sonnet | Content review vs ADR-026 + a11y law research | After Phase 3 |
| 3 | T3.4 Cookie consent banner | `clearskies-dashboard-dev` | Sonnet | WCAG audit + functional test (5-point checklist) | After Phase 3 |
| 3 | T3.5 GA integration | `clearskies-dashboard-dev` | Sonnet | Verify no GA before consent; verify page views track | After Phase 3 |
| 4 | T4.1 Branding static file + Caddy + dashboard fetch | Sonnet | Sonnet | branding.json verify + dashboard fetch | After Phase 4 |
| 4 | T4.2 Wizard: policy override | `clearskies-stack-dev` | Sonnet | File write verify on weather-dev | After Phase 4 |
| 4 | T4.3 Wizard: GA instructions | `clearskies-stack-dev` | Sonnet | Visual verify | After Phase 4 |
| 5 | T5.1 Legal translations | `clearskies-dashboard-dev` | Sonnet | Spot-check de, ja, pt-BR | After Phase 5 |
| 5 | T5.2 EULA translations | `clearskies-stack-dev` | Sonnet | Spot-check de, ja, pt-BR | After Phase 5 |
| 6 | T6.1-T6.3 Deploy + final verify | Coordinator | Opus | Walk all acceptance criteria; ADR compliance sweep | After deploy |

**Sequencing:**
- Phase 0 (EULA — wizard prerequisite) → Phase 1 (dashboard tweaks) → Phase 2 (wizard gaps)
- Phase 3 (privacy/legal + consent banner — depends on Phase 1 clean dashboard)
- Phase 4 (API + wizard analytics — depends on Phase 3 consent banner design)
- Phase 5 (translations — depends on Phase 3 final English content)
- Phase 6 (deploy everything)

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- Dashboard: `tsc --noEmit` 0 errors. `vite build` clean.
- Wizard: `python -m py_compile <file>` passes. Templates render without Jinja2 errors.
- API: `ruff check` + `mypy` no introduced errors.

### Gate 2 — Feature Correctness (per phase, Opus verifies)
- Phase 1: Visual render of all modified pages.
- Phase 2: Full wizard round-trip (new session → fill → review → apply → re-run → verify pre-fill).
- Phase 3: Cookie consent functional test: (1) GA absent before consent, (2) Accept loads GA, (3) Reject = no GA ever, (4) Cookie Settings re-opens banner, (5) GPC auto-rejects.
- Phase 4: API response contains new fields. Wizard writes policy files. GA measurement ID round-trips.
- Phase 5: Legal page renders correctly in 3+ non-English locales.

### Gate 3 — ADR Compliance (Opus verifies after Phase 6)
- ADR-022: Accent palette = 6 curated options only. Logo alt text collected.
- ADR-023: Theme mode options = light/dark/auto-os/auto-sunrise-sunset.
- ADR-026: Cookie banner meets WCAG AA. All new wizard inputs have labels. Heading hierarchy correct. axe-core 0 violations.
- ADR-027: Wizard scope boundary respected — deferred items documented.
- ADR-055: No skeleton flash during refetches (verify no regression).

### Gate 4 — Privacy/Legal Compliance (Opus verifies after Phase 3 + Phase 6)
- GDPR: Cookie banner blocks GA until explicit opt-in. "Reject" has equal prominence to "Accept". No pre-ticked boxes.
- CCPA/CPRA: Privacy policy includes all required disclosures. GPC signal honored.
- LGPD: Portuguese-language privacy notice in pt-BR locale.
- UK GDPR: ICO referenced as supervisory authority. PECR cookie rules.
- Cookie consent records: localStorage stores timestamp + choice per purpose.
- EULA: Operator must accept before wizard proceeds. Acceptance timestamped. Re-accept on version change.

### Gate 5 — Accessibility (Opus verifies after Phase 3 + Phase 6)
- Cookie banner: `role="dialog"`, `aria-labelledby`, focus trap, Escape = reject.
- All new wizard inputs have `<label>` + `aria-describedby`.
- All new legal content has correct heading hierarchy (h1 → h2 → h3).
- Accessibility statement accurately references continent-specific laws.
- axe-core 0 violations on Legal page and cookie banner.

---

## 5. Self-Audit

**Risk: State persistence backward compatibility.** New `WizardState` fields with `str = ""` defaults are safe — dataclasses-json fills defaults for missing keys on deserialization. No migration needed.

**Risk: API payload includes GA field before API update.** Phase 4 T4.1 adds the field to the API. Phase 2 wizard work can send the field earlier — the API's `BrandingApplyConfig` uses `extra="ignore"` for unknown fields. Silently dropped until API updated.

**Risk: Cookie consent banner performance.** Lightweight React component, no external dependencies. GA script dynamically injected only on consent — no initial bundle impact.

**Risk: Legal content accuracy.** Default Terms of Use, Privacy Policy, and Accessibility Statement are templates, not legal advice. The EULA makes this explicit (§9 Operator Responsibilities). Wizard communicates this clearly. Operators must review and customize for their jurisdiction.

**Risk: Translation accuracy for legal content.** Phase 5 requires accurate legal terminology. Coordinator spot-checks 3 locales (de, ja, pt-BR) against source regulations. LGPD must be in Portuguese per statutory requirement.

**Risk: EULA enforceability.** The EULA wraps GPL v3 with additional operational terms. GPL v3 is the license; the EULA adds warranty disclaimers, indemnification, and operator responsibility terms that GPL v3 permits but doesn't require. California governing law clause is standard for US-based developers.
