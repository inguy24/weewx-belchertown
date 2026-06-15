---
status: Accepted
date: 2026-05-26
deciders: shane
---

# ADR-043: skin.conf compliance — section-by-section disposition

## Context

weewx's skin.conf has 9 top-level sections. Traditional skins support all of them via the Cheetah template engine. Clear Skies uses React (ADR-002) and has no Cheetah dependency, so 4 sections are irrelevant. The remaining 5 contain operator configuration that Clear Skies should honor — especially for operators migrating from Belchertown or other skins.

The `[Extras]` section is freeform (weewx documents only 3 example keys). Belchertown puts 45+ settings there: branding, MQTT config, feature toggles, provider API keys, display settings, PWA manifest, social media. The key mapping in this ADR is Belchertown-specific; other skins may use different keys.

## Options considered

| Option | Verdict |
|---|---|
| A. Section-by-section disposition with migration import | **Selected.** Clear scope, supports migration. |
| B. Full skin.conf compatibility (including Cheetah sections) | Impossible without Cheetah engine. No value. |
| C. Ignore skin.conf entirely | Forces manual re-entry of all config. Hostile to migrating operators. |
| D. Units section only | Misses branding, labels, and Extras that operators customize heavily. |

## Decision

Clear Skies documents a keep/replace/ignore disposition for each skin.conf section. The setup wizard (stack repo) supports importing an existing skin.conf to pre-fill configuration steps.

### Section dispositions

| Section | Disposition | Where it lands |
|---|---|---|
| `[Units][[Groups]]` | **KEEP** | API `api.conf` `[units][[groups]]` — wizard unit config step |
| `[Units][[StringFormats]]` | **KEEP** | API `api.conf` `[units][[string_formats]]` |
| `[Units][[Labels]]` | **KEEP** | API `api.conf` `[units][[labels]]` |
| `[Units][[Ordinates]]` | **KEEP** | API `api.conf` `[units][[ordinates]]` |
| `[Units][[TimeFormats]]` | **KEEP** | API `api.conf` `[units][[time_formats]]` |
| `[Units][[DegreeDays]]` | **KEEP** | API `api.conf` (affects calculations) |
| `[Units][[Trend]]` | **KEEP** | API `api.conf` (affects barometer trend) |
| `[Units][[TimeZone]]` | **KEEP** | Pre-fills wizard station step |
| `[Labels][[Generic]]` | **KEEP** | i18n override file — observation names, page headers |
| `[Texts]` | **REPLACE** | react-i18next already in place (ADR-021). Ingest translations on migration. |
| `[Extras]` — branding | **KEEP** | Wizard branding step (site_title, logo_image) |
| `[Extras]` — feature toggles | **INGEST, DEFER** | Parse and store. Display implementation deferred to future site builder. |
| `[Extras]` — provider config | **INGEST** | Map API keys to provider config where key patterns match |
| `[Extras]` — social | **KEEP** | Wizard social config step, footer component |
| `[Extras]` — PWA/manifest | **KEEP** | Generate manifest.json from config |
| `[Extras]` — MQTT | **IGNORE** | MQTT eliminated per ADR-058; wizard no longer has an MQTT step |
| `[Almanac]` — moon_phases | **KEEP** | Feed 8 lunar phase labels into i18n system |
| `[Generators]` | **IGNORE** | Cheetah-specific — silently skip |
| `[CheetahGenerator]` | **IGNORE** | Cheetah-specific — silently skip |
| `[ImageGenerator]` | **IGNORE** | Cheetah-specific — silently skip |
| `[CopyGenerator]` | **IGNORE** | Cheetah-specific — silently skip |

### Wizard import flow

- **Step 0 (new):** "Start fresh" or "Import from existing skin" (file upload).
- Parser reads ConfigObj-format INI (same library weewx uses).
- Cheetah-specific sections silently skipped — no warnings for expected ignores.
- Unknown `[Extras]` keys logged as warnings but not fatal.
- Each subsequent wizard step shows imported values with visual indicator ("imported from Belchertown") and allows editing.

## Consequences

- Wizard gains a pre-fill path that dramatically reduces setup time for migrating operators.
- New dependency: `configobj` in stack repo (already used by weewx itself).
- `[Extras]` key mapping is Belchertown-specific. Operators migrating from other skins (e.g., Seasons, WeeWX-WD) will get partial imports — Units and Labels sections work universally, but Extras keys may not map.
- Labels import depends on i18n infrastructure (ADR-021) being in place.
- DegreeDays and Trend values route to API config — the wizard writes to `api.conf` on apply.

## Implementation guidance

- Parser file: `weewx_clearskies_config/wizard/skin_import.py`
- Uses `configobj` for parsing (same format weewx uses).
- Returns a structured dict that wizard steps can pre-fill from.
- `[Extras]` mapping is a key-pattern dict — maintainable, extensible for other skins later.
- Section mapping details in Phase 2 of [UNIT-SYSTEM-BFF-PLAN.md](../planning/UNIT-SYSTEM-BFF-PLAN.md).

### skin.conf generation (amended 2026-05-26)

Clear Skies generates and maintains its own skin.conf at `/etc/weewx/skins/ClearSkies/skin.conf` on wizard apply. This makes Clear Skies a proper weewx skin with a standard config file that operators can share, back up, or reference when migrating away.

**Contents:** The generated skin.conf includes `[Units]` (all subsections), `[Labels][[Generic]]`, `[Extras]` (branding, social, feature toggles), and `[Almanac]`. Cheetah sections are omitted (Clear Skies has no Cheetah dependency).

**Runtime config:** The API reads unit preferences from `api.conf [units]`. The wizard writes both files atomically — skin.conf is the portable/canonical copy, `api.conf` is the API's runtime config. They cannot drift because only the wizard writes them.

**Single-host (majority):** Wizard writes skin.conf directly to the local filesystem.

**Split-host:** Wizard sends config to the API via `/setup/apply`, which writes skin.conf on the weewx host.

### Image import on skin.conf ingest (amended 2026-05-26)

When importing a skin.conf, the parser extracts image paths from `[Extras]` (`logo_image`, `logo_image_dark`, `favicon`). These paths reference files in the source skin's directory (e.g., `/etc/weewx/skins/Belchertown/images/logo.png`).

**Resolution order:**
1. **Local filesystem** (same host) — resolve path relative to source skin directory, copy to Clear Skies static assets. Show "Imported logo.png" indicator.
2. **API endpoint** (split host) — `GET /setup/skin-file?skin=Belchertown&path=images/logo.png` serves the file from the weewx host. Wizard downloads and stores locally.
3. **Neither accessible** — wizard shows amber warning listing the unreachable files with their original paths. Operator can upload replacements in the Branding step or copy manually.

**Path validation:** The API endpoint validates that the requested path stays within the skin directory (no directory traversal).

### Out of scope

- Import from non-weewx weather software (e.g., Weather Display, Cumulus).
- Full key coverage for skins other than Belchertown (partial import is acceptable).

## References

- weewx skin.conf docs: https://weewx.com/docs/5.1/reference/skin-options/
- Related: [ADR-042](ADR-042-unit-system.md) (unit system), [ADR-027](ADR-027-config-and-setup-wizard.md) (wizard), [ADR-021](ADR-021-i18n-strategy.md) (i18n)
- Research: [brief-skinconf-schema.md](../planning/briefs/brief-skinconf-schema.md)
