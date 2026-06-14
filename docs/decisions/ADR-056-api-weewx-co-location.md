---
status: Accepted
date: 2026-06-13
deciders: shane
supersedes:
superseded-by:
---

# ADR-056: API co-located with weewx for Python-level metadata access

## Context

The Clear Skies API reads the weewx archive database and parses `weewx.conf` as a ConfigObj file, but has no Python-level access to weewx's runtime metadata. The most valuable metadata is `weewx.units.obs_group_dict` — a dict mapping every registered observation column to its unit group (e.g., `outTemp` -> `group_temperature`). This mapping is the key to auto-detecting units for archive columns during the wizard's column mapping step ([ADR-035](ADR-035-user-driven-column-mapping.md)).

Without co-location, the API has no reliable way to determine what unit group a stock weewx column belongs to — it would need a hardcoded copy of weewx's own lookup table, which drifts when weewx adds or changes observations across versions. Co-location lets the API import `weewx.units` directly and read the authoritative source.

Phase 0 research (T0.3) confirmed:
- `import weewx.units` fails from the API's venv by default because weewx installs outside the venv's `sys.path` (e.g., `/usr/share/weewx/` for Debian package installs).
- A `.pth` file pointing at weewx's install location makes the import work. 123 stock observation entries are available in `obs_group_dict`.
- Some weewx extensions register their columns dynamically at engine startup (not at module import time), so `obs_group_dict` at import time contains only stock weewx columns plus statically-registered extensions. Custom/extension columns that aren't in `obs_group_dict` are handled through operator column mapping ([ADR-035](ADR-035-user-driven-column-mapping.md)), not auto-detection.
- weewx's install location varies by installation method (pip, Debian package, from source). The API cannot hardcode a path.

## Options considered

| Option | Verdict |
|---|---|
| A. Co-locate API with weewx, import `weewx.units` for metadata | **Selected.** Authoritative unit groups, no drift, graceful fallback. |
| B. Hardcode a copy of weewx's obs_group_dict in the API | Rejected — drifts across weewx versions, maintenance burden. |
| C. Parse weewx Python source files without importing | Rejected — fragile, breaks on any refactor. |
| D. No unit auto-detection; operator maps everything manually | Rejected — stock columns have well-known mappings; requiring manual entry for 50+ stock columns is hostile UX. |

## Decision

The Clear Skies API runs on the same host as weewx with Python-level import access to `weewx.units`. This is a deployment constraint: the API must be able to `import weewx.units` from its Python environment.

**What co-location enables:**
- Auto-detecting unit groups for stock weewx columns via `obs_group_dict`, used as pre-filled suggestions in the wizard column mapping step. Operator always confirms — nothing auto-maps silently.
- Future potential: xtypes, aggregation system access, observation type registry.

**What co-location does NOT do:**
- Does not make weewx a hard runtime dependency. If `import weewx.units` fails, the API logs a warning and continues — auto-detection is unavailable, but the API functions normally. Stock columns fall back to the built-in lookup table; custom columns are always operator-mapped.
- Does not import weewx engine, driver, or service modules. Only `weewx.units` (and potentially `weewx.xtypes` in future phases) for read-only metadata access.
- Does not modify weewx's configuration, database, or runtime state.

**weewx path resolution:**
- At startup, the API attempts to locate weewx's Python path automatically: check `sys.path` (already importable?), check common install locations (`/usr/share/weewx/`, site-packages), check `which weewxd` and derive the path.
- If auto-detection succeeds, the path is stored in the API's config for subsequent starts.
- If auto-detection fails, the operator can provide the path in the wizard or `api.conf` (`[weewx] python_path = /path/to/weewx`). The API starts without weewx metadata access until configured.
- A `.pth` file or `PYTHONPATH` environment variable are also valid mechanisms — the ADR does not prescribe the technique, only the requirement that `import weewx.units` succeeds.

## Consequences

- **Deployment constraint:** API must run on the weewx host. This is already the default topology per [ADR-034](ADR-034-deployment-topology-default.md) (API on weewx host), so no topology change is needed.
- **Graceful degradation:** weewx not importable = warning + no auto-detection. Not a fatal error. The API still serves data, and stock columns use the built-in lookup table as fallback for pre-filling the mapping step.
- **Column mapping flow:** Stock columns are pre-filled with suggested mappings (from `obs_group_dict` when available, or the built-in lookup table as fallback). Custom columns are operator-mapped, with optional heuristic assistance. Operator confirms all mappings. Amends [ADR-035](ADR-035-user-driven-column-mapping.md): no silent auto-mapping, no auto-advance when all columns are stock.
- **Python path management:** One additional configuration item (`[weewx] python_path`) for operators where auto-detection fails.
- **Security boundary:** The API imports `weewx.units` for read-only metadata — never `weewx.engine`, `weewx.drivers`, or `weewx.manager`. This is enforced by code review and documented in `rules/coding.md`. See [ADR-058](ADR-058-security-model-threat-boundaries.md) (Phase 1, T1.5).

## Acceptance criteria

- [ ] `import weewx.units` succeeds from the API's Python environment on the weewx host (verified on weather-dev)
- [ ] `get_obs_group('outTemp')` returns `'group_temperature'` (stock column)
- [ ] `get_obs_group('nonexistent_column')` returns `None` (unknown column)
- [ ] API starts and serves data when weewx is not importable (graceful fallback, warning logged)
- [ ] `/setup/schema` response includes `autoDetectedGroup` for stock columns when weewx is importable
- [ ] Wizard column mapping step shows pre-filled suggestions for stock columns; operator confirms before proceeding
- [ ] `[weewx] python_path` config option works when auto-detection fails
- [ ] No imports of `weewx.engine`, `weewx.drivers`, or `weewx.manager` anywhere in the API codebase

## Implementation guidance

- New module: `weewx_clearskies_api/services/weewx_metadata.py`
  - `is_available() -> bool`
  - `get_obs_group(column_name: str) -> str | None`
  - `get_unit_for_group(group: str, unit_system: int) -> str | None`
  - Wraps `import weewx.units` in try/except at module load time
  - Caches `obs_group_dict` at startup (doesn't change without restarting weewx)
- Startup sequence: attempt import after settings load, before schema reflection. Log result.
- Config: `[weewx] python_path` in `api.conf`. When set, add to `sys.path` before attempting import.
- Auto-detect logic: check importability first; if fails, search common paths; if found, store in config.

## Out of scope

- Importing weewx engine or service modules (only `weewx.units` for metadata)
- Writing to weewx's database or configuration
- xtypes integration (future phase)
- Handling extension columns that register dynamically at engine runtime — these go through column mapping

## References

- Related: [ADR-012](ADR-012-database-access-pattern.md) (DB access), [ADR-034](ADR-034-deployment-topology-default.md) (deployment topology), [ADR-035](ADR-035-user-driven-column-mapping.md) (column mapping)
- Research: T0.3 findings (`c:\tmp\T0.3-weewx-import-feasibility.md`)
- Backlog: FIX-005
