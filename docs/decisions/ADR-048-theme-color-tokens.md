---
status: Accepted
date: 2026-05-30
deciders: shane
supersedes:
superseded-by:
---

# ADR-048: Theme & color token set (as-built)

## Context

[ADR-009](ADR-009-design-direction.md) locked the *direction* for color — a neutral foundation in
light + dark, one operator-picked accent from a curated AA-safe palette, locked semantic colors, a
legible chart palette — and explicitly deferred defining the actual values to "a Phase 3 design task."
That task was done **in code** (`src/index.css`, `src/lib/branding.ts`) but the concrete token set was
**never recorded as a decision.** [ADR-022](ADR-022-theming-branding.md) covers *how* operator branding
flows to the tokens at runtime; [ADR-023](ADR-023-light-dark-mode.md) covers *how* light/dark switches.
Neither enumerates the palette itself.

This ADR closes that gap: it adopts the **already-built** token set as the binding decision. It is a
reconciliation/encapsulation ADR — it records what exists, it does not invent a new palette.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| **A. Adopt the as-built token set** (this ADR) | Matches shipped code; nothing to rebuild; shadcn/ui-idiomatic; AA already verified | Locks in a near-monochrome chart palette (see consequences) |
| B. Design a new bespoke palette from scratch | Could be more "branded" | Re-litigates a working system; rework risk; contradicts ADR-009's neutral-foundation direction; rejected by operator as too academic (2026-05-29) |
| C. Leave it implicit in code only | No doc work | Violates ADR discipline — an undocumented foundation can't be verified or referenced by Track C |

## Decision

Adopt the **as-built** theme token set as the Clear Skies color foundation: **shadcn/ui `neutral` base,
expressed in OKLCH, with light + dark variants**, exactly as defined in the dashboard's `src/index.css`
`:root` / `[data-theme="dark"]` blocks and `src/lib/branding.ts`. The operator accent is one of **six
curated, AA-verified options** (default **blue**); no free-form picker. Semantic `--destructive` and the
5-step `--chart-*` series are part of the set. Visual reference (faithful render of the real values):
[mockups/A1-theme-tokens.html](../design/mockups/A1-theme-tokens.html).

## Consequences

- **No code change** — this records existing reality. `src/index.css` + `src/lib/branding.ts` are the
  source of truth; this ADR is downstream of them.
- Track C components must consume **tokens** (`bg-card`, `text-muted-foreground`, `var(--chart-2)`, …),
  never hardcoded hex/rgb. (Current code already complies — zero hardcoded component colors found.)
- **Accepted trade-off:** the `--chart-*` series is currently a 5-step neutral grayscale, not the
  "8–12-color legible palette" ADR-009 envisioned. Recorded as a known gap (below), to be resolved when
  multi-series charts land in Track C — not in this ADR.
- **Accepted trade-off:** the EPA AQI palette (ADR-009 §color) is not yet tokenized; it will be added
  with the C6 AQI card.
- Operator branding (accent, logo, custom CSS) flows per ADR-022; light/dark resolution per ADR-023.
  This ADR does not touch those mechanisms.

## Acceptance criteria

- [ ] The token names + light/dark values in this ADR's reference mockup match `src/index.css` verbatim
      (no drift between doc and code).
- [ ] The six accent options + default (`blue`) match `ACCENT_PALETTES` / `DEFAULT_BRANDING` in
      `src/lib/branding.ts`.
- [ ] Every Track C component PR uses tokens only — grep for hardcoded hex/rgb in `src/components` returns
      no new matches (checked at each component's round close).
- [ ] WCAG AA (≥4.5:1 body text) holds for `--foreground` on `--background` and `--card`, and for each
      accent's foreground on its accent, in both themes (axe-core, gate shared with B3).

## Implementation guidance

- **Do not edit code for this ADR.** It is documentation of the existing system.
- Source of truth: dashboard `src/index.css` (lines ~93–223, the `:root` + `[data-theme="dark"]` token
  blocks; `@theme` block maps them to Tailwind `--color-*` utilities) and `src/lib/branding.ts`
  (`ACCENT_PALETTES`, `DEFAULT_BRANDING`).
- **Known gaps (tracked, NOT resolved here):** (1) chart palette is 5-step neutral, not multi-hue —
  revisit at first multi-series Track C chart; (2) EPA AQI palette not tokenized — add with C6;
  (3) `weewx-clearskies-design-tokens` repo is a Phase-6 stub — tokens stay in the dashboard until then.
- If a future change alters the palette, edit `src/index.css`/`branding.ts` first, then update this ADR
  (status → Proposed → re-approve) so doc and code never drift.

## References

- Related ADRs: ADR-009 (design direction — defers value definition here), ADR-022 (branding mechanism),
  ADR-023 (light/dark mechanism), ADR-026 (accessibility/contrast), ADR-047 (background system — scrims
  must preserve token contrast over photos)
- **Typography sibling:** [../design/design-tokens-typography.md](../design/design-tokens-typography.md)
  (LOCKED 2026-05-31) — font role assignments and type scale that complement this color token set; Track C
  components consume both.
- Code: dashboard `src/index.css`, `src/lib/branding.ts`, `src/lib/theme-provider.tsx`, `components.json`
- Visual reference: `docs/design/mockups/A1-theme-tokens.html`
- Plan: `docs/planning/UI-REDESIGN-PLAN.md` Track A1
