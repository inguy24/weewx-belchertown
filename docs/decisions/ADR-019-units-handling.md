---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-019: Units handling

## Context

[ADR-010](ADR-010-canonical-data-model.md) locks: "canonical units = weewx's configured `target_unit` system, with a units metadata block in every response." This ADR locks the conversion seam (server vs client) and the v0.1 override policy.

## Decision

### Server passes weewx units through; no server-side conversion

clearskies-api outputs each observation in the unit weewx is configured to write that observation in (per `target_unit` and per-observation overrides). The api **does not** convert units server-side — it passes weewx's representation through with the units metadata block per [ADR-010](ADR-010-canonical-data-model.md) describing what's in the payload.

### No per-user units override at v0.1

Whatever weewx is configured to display, the dashboard displays. A visitor in a metric country viewing a US-station dashboard sees °F. This matches every weewx skin's precedent and is consistent with [ADR-008](ADR-008-auth-model.md) (no per-user identity to attach a preference to).

### Phase 6+: client-side override (deferred)

A client-side per-user override using the units metadata block to convert at render time is a future enhancement. Stored in `localStorage`. The metadata block is already a Phase 1 commitment via [ADR-010](ADR-010-canonical-data-model.md), so the future enhancement adds no new server-side surface.

## Options considered

| Option | Verdict |
|---|---|
| A. Server passes weewx's units through; metadata describes them; no override at v0.1 (this ADR) | **Selected.** |
| B. Server-side conversion via `?units=` request param | Rejected for v0.1 — adds api complexity for no current use case. |
| C. Client-side conversion always (api serves a hard-canonical, e.g., always SI) | Rejected — fights weewx's existing operator-selected unit system; departs from weewx-skin precedent. |

## Consequences

- clearskies-api Phase 2 work has no unit-conversion code.
- Dashboard renders the units the api reports — no math.
- INSTALL.md instructs operators to set their preferred unit system in `weewx.conf` (`StdConvert.target_unit`) before installing Clear Skies.
- Phase 6+ per-user override is unblocked by ADR-010's metadata commitment — no server change needed when it ships.

## Out of scope

- Per-user override mechanism — Phase 6+.
- Unit-conversion library choice — pick when Phase 6+ override ships.
- Mixed unit systems within one weewx install — already supported via per-observation overrides in weewx; metadata block makes it transparent to the dashboard.

## References

- weewx `target_unit` docs: https://weewx.com/docs/5.1/reference/weewx-options/stdconvert/
- Related: [ADR-008](ADR-008-auth-model.md), [ADR-010](ADR-010-canonical-data-model.md), [ADR-027](ADR-027-config-and-setup-wizard.md).
