---
status: Archived — consolidated into DESIGN-MANUAL.md
date: 2026-06-16
deciders: shane
supersedes:
superseded-by:
---

# ADR-062: Card header contract — structured slots and standardized control patterns

## Context

Card headers are implemented inconsistently across the dashboard. Two patterns coexist:

**Pattern A (10 Now-page cards):** Custom inline `<h2>` with hand-copied classes and inline styles. Each card duplicates the same font, weight, spacing, and underline CSS. Spacing uses `pb-0.5` with no margin below.

**Pattern B (Almanac, Forecast, Webcam, Charts):** `CardTitle` component with `pb-1.5 mb-3 border-b`. Different spacing and underline width than Pattern A.

Cards with inline controls (tab pills, toggles, dropdowns) each build their own flex layout inside `CardHeader` — different alignment, spacing, and button styling card to card. There is no defined slot for controls and no pre-styled control patterns.

Result: underline spacing varies card to card, some underlines span the card and others don't, control placement and sizing is ad-hoc, and every new card author re-invents the header from scratch.

ADR-051's 2026-06-16 amendment (§11) establishes the header slot as a fixed-height container (`--card-header-h`) within the card content box contract. This ADR defines what goes *inside* that slot.

## Options considered

| Option | Verdict |
|---|---|
| Leave headers as-is, fix only the most broken ones | **Reject** — the inconsistency is systemic; per-card fixes won't converge. |
| Define header as a rigid two-slot container (title + controls) with pre-styled control patterns | **Chosen** — one component, consistent everywhere, card authors only declare what they need. |
| Build a header "builder" API with maximum flexibility | **Reject** — flexibility is the problem; constraints produce consistency. |

## Decision

The card header is a structured container with two slots and a fixed set of approved control patterns. All cards use `CardHeader` + `CardTitle` — no custom `<h2>` elements with hand-copied classes.

**Two slots:**

1. **Title slot (left):** Renders a semantic heading element (`<h2>` default, configurable level). Font, weight, size (`--text-card-title`), underline, and spacing are owned by the component. The card author passes a title string and optionally a heading level.

2. **Controls slot (right, optional):** Right-aligned area for inline controls. The card author passes control elements as `children` of `CardHeader`. The header handles alignment, vertical centering, and gap spacing. Controls render at a fixed height within `--card-header-h`.

**Underline rule:** The title's `border-bottom` spans the full width of the card interior (from padding edge to padding edge), always. No card varies this.

**Approved control patterns:**

Each pattern is a pre-styled component. Card authors choose which pattern and provide labels/values — they do not style the controls.

| Pattern | Component | Use case | Example |
|---|---|---|---|
| Tab pills | `<HeaderTabs>` | Switch between views within a card | Forecast Today / 7-Day, Webcam Live / Timelapse |
| Toggle | `<HeaderToggle>` | Binary on/off within a card | Show/hide overlay |
| Dropdown | `<HeaderSelect>` | Choose from a list | Period selector, unit selector |
| Action button | `<HeaderButton>` | Trigger an action | Download, expand, refresh |

All control components share:
- Height: fits within `--card-header-h` with vertical centering
- Font: `--text-label` (0.75rem)
- Colors: `text-muted-foreground` default, `text-foreground` on active/hover, accent background on active tab pills
- Border radius: consistent with card radius scale
- Focus: visible ring per coding.md §5.3
- Touch target: minimum 44px on mobile per WCAG

**What the card author writes:**

```tsx
<Card footprint="wide" rowSpan={2}>
  <CardHeader>
    <CardTitle as="h2">Forecast</CardTitle>
    <HeaderTabs
      tabs={[{ label: 'Today', value: 'today' }, { label: '7-Day', value: '7day' }]}
      value={activeTab}
      onChange={setActiveTab}
    />
  </CardHeader>
  <CardContent>
    {/* content box */}
  </CardContent>
</Card>
```

No flex layout, no alignment classes, no font sizes, no padding overrides. The header handles everything.

**ControlsStrip uses the same control components.**

The `ControlsStrip` (ADR-051's "many controls" pattern — a full-width quarter-row card below the page header) uses the same pre-styled control components. Page authors declare what controls they need; the strip handles layout, alignment, and spacing. No custom styling inside the strip.

```tsx
<PageLayout title="Records" icon={<Table weight="duotone" />}
  controls={
    <>
      <HeaderSelect
        label="Period"
        options={[{ label: 'Monthly', value: 'month' }, { label: 'Yearly', value: 'year' }]}
        value={period}
        onChange={setPeriod}
      />
      <HeaderButton label="Download .csv" icon={<Download />} onClick={handleDownload} />
    </>
  }
>
```

The `ControlsStrip` component owns its internal layout (`flex`, `gap`, `items-center`, wrapping). Page authors never set flex classes, gap values, or padding on the strip's children.

## Consequences

- All 10 Pattern A cards (custom `<h2>`) must be migrated to `CardHeader` + `CardTitle`. This is implementation work during the FIX-006 / FIX-012 pass.
- `CardTitle` component loses its current `pb-1.5 mb-3` spacing in favor of header-slot-level spacing owned by `CardHeader`.
- Four new lightweight components (`HeaderTabs`, `HeaderToggle`, `HeaderSelect`, `HeaderButton`) are created in `components/ui/`. They are thin wrappers around standard elements, not a design system library — each is ~20-40 lines.
- Cards that currently have custom control styling (NowForecastCard, WebcamCard, PlanetTimelineCard, ForecastDailyCard, ForecastHourlyCard) must migrate to the approved patterns.
- Future card authors have a fixed menu of control patterns. If a new pattern is needed, it gets added to this ADR — not invented per-card.

## Acceptance criteria

- [ ] Zero custom `<h2>` elements with hand-copied header classes in any card component.
- [ ] All cards use `CardHeader` + `CardTitle` for their header.
- [ ] Title underline spans full card interior width on every card, every page.
- [ ] Title-to-underline spacing and underline-to-content spacing is identical on every card.
- [ ] Cards with controls use an approved control component (`HeaderTabs`, `HeaderToggle`, `HeaderSelect`, or `HeaderButton`).
- [ ] No card component contains inline styles or className overrides for header layout (flex, alignment, gap, font size).
- [ ] Control components meet WCAG touch target (44px mobile) and visible focus requirements.
- [ ] All control components use `--text-label` for font size and the approved color tokens.
- [ ] `ControlsStrip` uses the same approved control components — no custom styling inside the strip.
- [ ] No page passes raw `<button>`, `<select>`, or custom-styled elements into `ControlsStrip`.

## Implementation guidance

- `CardHeader` becomes a flex container: `display: flex; align-items: center; justify-content: space-between; height: var(--card-header-h); padding: 0 var(--card-pad);`. Title fills remaining space (`flex: 1`), controls slot is `flex-shrink-0`.
- `CardTitle` moves its `border-bottom` to `CardHeader` (so the underline always spans the full interior). `CardTitle` itself becomes just the heading text — font, weight, size, no border, no margin.
- The four control components live in `src/components/ui/header-controls.tsx` (single file, exported individually).
- Migration order: update `CardHeader`/`CardTitle` first, then migrate Pattern A cards, then migrate cards with custom controls.
- `ControlsStrip` remains its own component (quarter-row card, full-width) but its children must use the same four control components. No custom-styled elements inside the strip.
- The control components (`HeaderTabs`, `HeaderToggle`, `HeaderSelect`, `HeaderButton`) are context-agnostic — they work identically inside `CardHeader` or `ControlsStrip`. Naming uses `Header` prefix because that's the primary context, but they are not header-only.

## References

- Parent: [ADR-051](ADR-051-card-footprint-model.md) (card footprint model, §11 content box contract)
- Related: [ADR-048](ADR-048-theme-color-tokens.md) (color tokens), [ADR-009](ADR-009-design-direction.md) (design direction)
- Fixit tracker: `docs/planning/DASHBOARD-FIXIT.md` FIX-012
