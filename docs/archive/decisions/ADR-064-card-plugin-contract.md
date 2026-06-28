---
status: Archived — consolidated into DASHBOARD-MANUAL.md + ARCHITECTURE.md
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-064: Card plugin contract

## Context

The Now page currently composes 14 data cards as hardcoded JSX in `now.tsx`. Each card is a bare React component that receives specific, individually-typed props passed by the page. The page owns the data mapping logic — it calls hooks, destructures the responses, and threads the right fields into each card's props interface.

This design has three consequences:

1. **No operator customization.** Card composition, order, and sizing are compile-time decisions. An operator who wants to hide a card or reorder them must edit source and rebuild.

2. **Page-card coupling.** Adding or removing a card requires editing both the card component *and* the page that hosts it. The page must know every card's data dependencies.

3. **No path to third-party cards.** A future card import system (v2) would require external cards to conform to whatever interface the built-in cards use. If built-in cards each have unique prop shapes, there is no stable interface to conform to.

The goal is a plugin contract: a uniform interface that all cards — built-in and future third-party — implement. The contract must be loose enough that cards remain self-contained (each handles its own loading, error, and rendering) and tight enough that a container can render any card without knowing its internals.

## Options considered

| Option | Verdict |
|---|---|
| A. Uniform props interface with a data bag (card self-extracts) | **Selected.** Cards declare their API dependencies; container fetches and deduplicates; cards extract what they need. Decouples page from card internals. |
| B. Per-card hook injection (container passes hooks, not data) | Rejected — hooks must be called unconditionally per React rules; a dynamic card set with injected hooks creates ordering violations. |
| C. Global store (Redux / Zustand) with per-card selectors | Rejected — adds a state management dependency the project does not otherwise need; over-engineers the data flow for a single-page card container. |
| D. Keep current per-card props, add metadata alongside | Rejected — metadata alone does not solve the data coupling problem; the page still needs per-card prop threading. |

## Decision

**Cards are self-contained plugin components conforming to a uniform contract.** Each card declares its metadata (identity, data dependencies, supported layout configurations, preview thumbnail) and exports a React component that receives a standardized props shape. The component extracts its own data from a shared data bag keyed by API endpoint path.

The contract has two layers:

- **Metadata layer** (no React dependency): card identity, human-readable name, array of API endpoint paths the card needs, array of layout configurations the card supports, and a thumbnail image path. This layer can be serialized to JSON at build time for non-React consumers (the admin layout editor).

- **Component layer** (React): the card component receives the data bag, its active layout configuration, and the station time zone. It handles its own loading/error states based on whether its required data is present.

The Now page becomes a container: it reads a layout configuration, looks up each active card in a registry, collects and deduplicates all declared API endpoints, fetches each once, and renders cards in order — passing each the shared data bag and its layout.

**v2 readiness:** Built-in cards ship in the bundle. Third-party cards (v2) will be stored in the web root's `cards/` directory (excluded from redeploy rsync, same isolation pattern as `webcam/`) and loaded dynamically. Both use the same contract — no rewrite when v2 adds the import mechanism.

## Consequences

- **Decouples pages from cards.** The Now page no longer knows what data each card needs or how it renders. Cards are self-describing and self-sufficient.
- **Enables operator layout customization.** With a uniform contract, a layout configuration file can specify which cards appear and in what order (see ADR-065).
- **Enables a future admin layout editor.** Card metadata (serialized as a build-time JSON manifest) provides the card palette for a drag-and-drop editor without requiring React in the admin tool.
- **Refactor cost.** All 14 existing cards must be adapted from per-card prop interfaces to the uniform contract. This is a mechanical refactor — moving existing prop-reading code into each card component and changing the data source from named props to data bag lookup.
- **Data bag is loosely typed.** Cards receive `Record<string, any>` and cast internally. This is a deliberate trade-off: a strongly-typed bag would require the container to know every endpoint's response shape, re-coupling page and card. Cards already know their own data shapes; the cast moves to the card boundary instead of the page boundary.
- **Build-time manifest generation.** A prebuild script reads the metadata-only file (no React imports) and writes a JSON manifest to the build output. This adds a build step but keeps the admin editor Python-only.

## Acceptance criteria

- [ ] All 14 built-in cards conform to the uniform contract (metadata + component).
- [ ] Each card renders identically to its pre-refactor output when given the same data.
- [ ] A build-time manifest (`card-manifest.json`) containing all card metadata is present in the build output — valid JSON, parseable by non-React consumers.
- [ ] The Now page container deduplicates API endpoint calls across all active cards (an endpoint declared by multiple cards is fetched once).
- [ ] Adding or removing a card from the Now page requires only a layout config change — no source edits to the page component.
- [ ] The card metadata file has no React imports (enforced by the prebuild script successfully importing it in a non-React context).

## Implementation guidance

Prescriptive rules (types, interfaces, file layout, data flow patterns) will be extracted into **DASHBOARD-MANUAL.md** after acceptance. Card thumbnail requirements will be extracted into **DESIGN-MANUAL.md**. Agents implement from the manuals.

## References

- Related: ADR-051 (card footprint model), ADR-062 (card header contract), ADR-024 (page taxonomy), ADR-065 (Now page layout configuration)
- Prior art: WordPress widget API (metadata + render callback), Grafana panel plugin contract (panel options + data frames), Home Assistant dashboard cards (type + config + entity declarations)
