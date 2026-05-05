---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-021: i18n strategy

## Context

User direction 2026-05-02: "We need to be multi-language friendly. It is not like we have that much we have to translate as we build." This reverses Claude's earlier proposal to ship English-only at v0.1. i18n is first-class from v0.1, not a Phase 6+ deferral.

This ADR locks the **language list**. Framework / file format / string-extraction tooling are Phase 2–3 implementation choices.

## Decision

**v0.1 ships with 13 locales** (mirrors the locale set on the user's other site, numisync.com):

| Code | Language |
|---|---|
| `en` | English (default) |
| `de` | Deutsch (German) |
| `es` | Español (Spanish) |
| `fil` | Filipino |
| `fr` | Français (French) |
| `it` | Italiano (Italian) |
| `ja` | 日本語 (Japanese) |
| `nl` | Nederlands (Dutch) |
| `pt-PT` | Português (Portugal) |
| `pt-BR` | Português Brasil |
| `ru` | Русский (Russian) |
| `zh-CN` | 中文 简体 (Simplified Chinese) |
| `zh-TW` | 中文 繁體 (Traditional Chinese) |

**No RTL languages** in v0.1 scope — `dir="rtl"` work not required. Per [rules/coding.md](../../rules/coding.md) §5.6, write LTR-neutral CSS (`margin-inline-start` over `margin-left`, etc.) so RTL is a future-add, not a future-rewrite.

**`<html lang="…">`** is set per active locale on every page (per [rules/coding.md](../../rules/coding.md) §5.6 / [ADR-026](ADR-026-accessibility-commitments.md)).

## Options considered

| Option | Verdict |
|---|---|
| A. 13 locales from numisync.com (this ADR) | **Selected** — user's locked set. |
| B. English only at v0.1, add languages in Phase 6+ | Rejected — user direction reverses this. |
| C. Belchertown's 3-locale carry-forward (en/de/it/ca) | Rejected — narrower than what the user wants. |
| D. All major locales (~30+) | Rejected — costs translation effort with no committed translators. |

## Consequences

- All user-facing strings in `clearskies-dashboard` and `clearskies-stack` (configuration UI) are extractable for translation from day 1 — no inline English in JSX/HTML.
- Phase 3 dashboard scaffold includes a `src/i18n/locales/` directory with 13 locale files.
- Default fallback locale is `en`. Missing keys fall back to `en` silently; logged for translator follow-up.
- Numbers, dates, units format per locale via `Intl.NumberFormat` / `Intl.DateTimeFormat`.
- Initial translations (beyond `en`) come from machine translation reviewed by the user; community contributions welcomed via PR after launch.

## Out of scope

- i18n framework / library choice (`react-i18next`, `lingui`, `formatjs`, etc.) — Phase 2–3.
- String-extraction tooling — Phase 2–3.
- Translation review workflow — Phase 5 / post-launch.
- RTL support — future ADR if RTL locales are added.
- Configuration UI's "default-locale" picker UX — owned by [ADR-027](ADR-027-config-and-setup-wizard.md).

## References

- Walk artifact: cat 11 cross-cutting threads in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Related: [ADR-009](ADR-009-design-direction.md), [ADR-026](ADR-026-accessibility-commitments.md), [ADR-027](ADR-027-config-and-setup-wizard.md).
