# Plan: Config UI UX Fixes from Live Testing

**Status:** Complete (2026-05-20). All 6 rounds executed.
**Predecessor:** Phase A (config UI build) + Phase E live testing session.
**Context:** Live browser testing of the wizard on `weather-test.shaneburkhardt.com` surfaced 30 issues across auth flow, wizard UX, provider config, and architecture. This plan addresses all of them.

---

## Priority 1 — Critical UX (blocking usability)

These must be fixed before any further user testing. Without them, the wizard is frustrating to use (session loss, raw JSON errors, repeated data entry).

| # | Issue | Fix | Files |
|---|-------|-----|-------|
| 1 | Auth error returns raw JSON `{"detail":"Authentication required"}` | Redirect to `/login` with a flash message. Add HTMX response handler for 401 that navigates to `/login`. | `app.py`, `templates/wizard/layout.html` |
| 2 | Bootstrap doesn't auto-login | After saving admin credentials, create a session and set the cookie before redirecting. Skip the login page. | `app.py` (bootstrap_post) |
| 3 | Post-login redirect goes to `/` (dashboard) instead of wizard | Store the intended destination in a `next` query param or session. Default to `/wizard` if no config exists, `/admin/config` if config exists. | `app.py` (login_post), `templates/login.html` |
| 4 | Session lost on config tool restart | Persist sessions to disk (SQLite or JSON file in config dir). Reload on startup. Sessions still expire on explicit logout or configurable timeout. | `auth.py` (SessionManager) |
| 5 | Wizard state lost on restart; doesn't read existing config | On each step load, check if config files exist and pre-populate from them. Write partial progress to disk as each step completes (not all-at-once at the end). | `wizard/routes.py`, `wizard/state.py`, new `wizard/state_persistence.py` |
| 6 | ConfigObj writes bytes not strings | Already fixed (commit `69a238d`). Use `BytesIO` + decode. | `config_writer.py`, `updater.py` |
| 7 | Bootstrap token consumed on form validation failure | Already fixed (commit `8932d71`). `check()` validates without consuming; `validate()` only on success. | `auth.py`, `app.py` |

## Priority 2 — Wizard simplification (8 steps → 5)

These reduce the wizard from 8 confusing steps to 5 clean ones. Each elimination is based on information the wizard already has.

| # | Change | Rationale | Files |
|---|--------|-----------|-------|
| 8 | Merge API Keys (step 5) into Provider Selection (step 4) | When a key-required provider is selected, expand inline key input + test button right there. Eliminates a whole step. | `wizard/routes.py`, `templates/wizard/step_providers.html` |
| 9 | Auto-detect topology from DB host in step 1 | `localhost`/`127.0.0.1` = same-host, anything else = cross-host. Auto-generate shared secret for cross-host. No user decision needed. | `wizard/routes.py`, `wizard/topology.py` |
| 10 | Remove Binds step from wizard | Bind addresses are auto-configured from topology. Same-host → loopback, cross-host → all interfaces. Power users change in master config. | `wizard/routes.py`, remove `templates/wizard/step_binds.html` |
| 11 | Column mapping: auto-skip when no custom columns | Introspect schema; if all columns are stock (auto-mapped), show a summary and "Next" button. Only show the mapping table when unmapped columns exist. | `wizard/routes.py`, `templates/wizard/step_schema.html` |

**Resulting wizard flow:**
1. Database — connect to weewx
2. Columns — auto-skip if no custom, otherwise show only unmapped
3. Station — auto-populated from API, user verifies
4. Providers — pick per domain, inline key entry + test
5. Review — confirm and apply

## Priority 3 — Wizard improvements

| # | Issue | Fix | Files |
|---|-------|-----|-------|
| 12 | Station step: blank fields, no auto-populate | Fetch from API's `/api/v1/station` endpoint using weewx host from step 1. Pre-populate station name, lat, lon, altitude, timezone. User verifies. | `wizard/station.py`, `wizard/routes.py` |
| 13 | Everything is too big (Pico CSS defaults) | Override Pico base font size. Add `--pico-font-size: 87.5%` or similar to `:root`. Tighten spacing on form elements. | `templates/base.html` or `static/clearskies.css` |
| 14 | Test Connection result appears at top of page | Show result inline next to the button using HTMX `hx-target` pointing at a result div adjacent to the button, not the whole page content. | `templates/wizard/step_db.html`, `wizard/routes.py` |
| 15 | Column mapping suggests battery/diagnostic columns | Exclude columns matching `*Battery*`, `*Link*`, `*Status*` (case-insensitive) from mapping suggestions. These are sensor diagnostics, not weather observations. | `wizard/schema.py` |
| 16 | Column mapping: no validation on submit | Validate on submit: flag duplicate canonical mappings, invalid canonical names (not in known field list). Show inline red border + error text on offending rows. Scroll to first error. | `wizard/routes.py`, `templates/wizard/step_schema.html` |
| 17 | Station: no browser geolocation option | Add "Use my location" button that calls `navigator.geolocation.getCurrentPosition()` and fills lat/lon fields. Requires location permission prompt. | `templates/wizard/step_station.html` |
| 18 | Altitude displayed in meters regardless of weewx unit system | Pull unit system from weewx (via API `/station` endpoint or weewx.conf `[StdConvert] target_unit`). Display altitude in operator's preferred unit (feet for US, meters for Metric) with toggle. Store internally as meters. | `wizard/station.py`, `templates/wizard/step_station.html` |
| 19 | Timezone doesn't re-detect when lat/lon change | Add HTMX call on lat/lon field blur that POSTs coordinates to a timezone-lookup endpoint, updates the timezone field. | `wizard/routes.py`, `templates/wizard/step_station.html` |
| 20 | Station silently reads stale local weewx.conf | Don't auto-read local weewx.conf on page load. Require explicit "Detect from weewx.conf" button (like step 1). Show note that this only works on the weewx host. | `wizard/routes.py` |
| 21 | Altitude input rejects decimal values | Set `step="any"` on the altitude `<input type="number">`. | `templates/wizard/step_station.html` |

## Priority 4 — Provider improvements

| # | Issue | Fix | Files |
|---|-------|-----|-------|
| 22 | No links to provider signup pages | Add direct link to each provider's API signup/dashboard page next to the provider name. | `templates/wizard/step_providers.html`, `wizard/providers.py` (add `signup_url` to `ProviderInfo`) |
| 23 | Indicates which DON'T need keys (backwards) | Flip: show "Key required" badge on providers that need keys. Keyless is the unmarked default. | `templates/wizard/step_providers.html` |
| 24 | Single-provider domains show unnecessary dropdown | Earthquakes (USGS) and radar (RainViewer) are single-provider keyless. Show as informational text, no dropdown. | `templates/wizard/step_providers.html` |
| 25 | All AQI providers should be selectable | Show IQAir, OWM AQI, and Open-Meteo AQI with key-required badges. User picks one. | `wizard/providers.py`, `templates/wizard/step_providers.html` |
| 26 | AQI recommendation logic wrong (suggests OWM over IQAir) | Review `recommend_providers()`. Default to Open-Meteo AQI (keyless). If user has OWM key from forecast, suggest OWM AQI. IQAir as premium option. | `wizard/providers.py` |
| 27 | Alert provider doesn't consider forecast provider overlap | If forecast provider also supplies alerts (Aeris), default to it. Show NWS as override option for US users. Let user deselect NWS if they prefer their forecast provider's alerts. | `wizard/providers.py`, `templates/wizard/step_providers.html` |
| 28 | Add Open-Meteo AQI as keyless provider | Add to the static `PROVIDERS` list with test URL. Makes zero-key wizard completion possible. | `wizard/providers.py` |

## Priority 5 — Architecture (separate from wizard)

| # | Issue | Fix | Files / Repo |
|---|-------|-----|-------------|
| 29 | AQI scale conversion done in API, should be in dashboard | API should serve raw provider data + provider's native AQI value. Dashboard converts to operator's preferred scale (US EPA / European AQI / native). Remove `_units.py` EPA conversion from API response path (keep as optional utility). | `weewx-clearskies-api` repo |
| 30 | Provider reference guide missing | Write a docs page explaining each provider: coverage, data source, key requirements, rate limits, strengths/weaknesses. Link from wizard. | `weewx-clearskies-stack` docs |
| 31 | MQTT configuration missing from wizard | Add Data Pipeline step (step 4) with Direct/MQTT mode selector, broker config, test connection. Fix config_writer INI nesting. | `wizard/state.py`, `wizard/routes.py`, `config_writer.py`, `state_persistence.py`, new `step_mqtt.html` |

---

## Execution approach

### Round 1: Critical UX (Priority 1, items 1-5) — COMPLETE
All auth flow and session persistence fixes. Unblocks usable testing.
**Commit:** `30f2824` in weewx-clearskies-stack

### Round 2: Wizard simplification (Priority 2, items 8-11) — COMPLETE
Reduce steps from 8 to 5. Restructure routes and templates.
**Commit:** `636daca` in weewx-clearskies-stack

### Round 3: Wizard improvements (Priority 3, items 12-21) — COMPLETE
Station auto-populate, typography, inline results, column mapping fixes, geolocation, altitude units, timezone.
**Commit:** `fdee8b5` in weewx-clearskies-stack

### Round 4: Provider improvements (Priority 4, items 22-28) — COMPLETE
Provider UX overhaul: inline keys, badges, single-provider skip, alert intelligence, Open-Meteo AQI.
**Commit:** `cf8ca92` in weewx-clearskies-stack

### Round 5: Architecture (Priority 5, items 29-30) — COMPLETE
API AQI refactor (separate repo), provider reference docs.
**Commits:** `31406da` in weewx-clearskies-api (item 29), `f9c9430` in weewx-clearskies-stack (item 30)

### Round 6: Test + audit — COMPLETE
Re-test full wizard flow, accessibility audit, fix any remaining issues.
**Findings:** MQTT config gap (added as new item 31), 8 MQTT audit findings (all remediated), 5 accessibility audit findings (all remediated), ProtectSystem systemd fix, non-editable pip install fix.
**Commits (weewx-clearskies-stack):** `596c13b` MQTT impl, remediation commit, a11y fix commit, `779bcca` systemd templates

---

## Pre-reading for new sessions

| File | Why |
|------|-----|
| This file | The fix plan |
| `docs/planning/CONFIG-UI-AND-DEPLOY.md` | Original deployment plan |
| `docs/planning/briefs/A1-A6` | Round briefs for context |
| `rules/clearskies-process.md` | Agent orchestration rules |
| `rules/coding.md` | Security + accessibility rules |
| `docs/decisions/ADR-027-config-and-setup-wizard.md` | Config UI spec |
