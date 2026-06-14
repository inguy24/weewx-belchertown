# Round 3C-2: Wire Unit Conversion + Derived Values into Response Pipeline

## Round identity

- **Round:** 3C-2 (combines plan tasks T3C.2 + T3C.3; T3C.1 done in 3BC-1, T3C.4 done in 3BC-1+3BC-2)
- **Date:** 2026-06-14
- **Lead:** Opus
- **Teammate:** Sonnet (`clearskies-api-dev`)

## Context

The units module and all enrichment processors are ported. What's missing: the actual unit conversion step in the response pipeline. Currently the API returns raw archive values — the BFF used to convert them. Now the API must convert them itself.

The BFF's conversion logic lives in `proxy.py` — specifically `_apply_conversion()` and its helpers. We need to port this code faithfully into the API (not rewrite it) and wire it into the REST and SSE response paths.

## Scope

### Files to create

| File | Purpose | Source |
|------|---------|--------|
| `units/response_conversion.py` | Port of proxy.py's `_apply_conversion()`, `_infer_us_units()`, `_flatten_converted_value()`, `_cardinal_for_degrees()` | `realtime/proxy.py` |

### Files to modify

| File | What changes |
|------|-------------|
| `endpoints/observations.py` | Insert `apply_conversion()` BEFORE `apply_enrichments()` in both `get_current_endpoint()` and `get_archive_endpoint()` |
| `endpoints/sse.py` | Add conversion + `add_derived_fields()` in the SSE generator before serialization |
| Other data endpoints (if found) | Same conversion pattern: convert before return |

### Files NOT to touch

- `units/transformer.py` — already ported, don't modify
- `units/conversion.py`, `units/derived.py`, `units/groups.py`, `units/labels.py` — already ported
- `sse/enrichment/*` — already wired in 3BC-2
- `sse/endpoint_enrichment.py` — already created in 3BC-2
- Test files

## Key design decisions (lead calls)

1. **Port `_apply_conversion()` from proxy.py faithfully.** Do not rewrite. The BFF's conversion handles multiple response shapes correctly. Port the logic, update imports, change module-level `_transformer` to use the existing `configure()` pattern.

2. **Conversion order: convert BEFORE enrich.** The BFF converted first, then applied enrichments. Enrichment functions expect already-converted data. Insert conversion between `model_dump()` and `apply_enrichments()`.

3. **SSE path uses `transform_record()` + `add_derived_fields()`.** The transformer's `add_derived_fields(record)` method (ported in 3BC-1) handles SSE-specific derived values (beaufort, comfortIndex, weatherText, windSpeedAvg10m, windGustMax10m, lightningStrikeHistory). Verify its lazy imports resolve to the 3BC-2 enrichment modules.

4. **`us_units` from station metadata.** The API has direct access to the station's unit system — no need to infer from labels. But port `_infer_us_units()` as a fallback for robustness.

5. **Flattening strategy matches the BFF:**
   - `/current`: ConvertedValue → display-precision scalar (via `_flatten_converted_value()` which parses the formatted string)
   - `/archive`: ConvertedValue → full-precision `val["value"]` (for chart rendering)
   - `/archive`: `beaufort` kept as ConvertedValue dict (wind rose reads it)
   - SSE: same as /current (display-precision)

6. **Cardinal wind directions added by `_apply_conversion()`**, not by `transform_record()`. Port the `_cardinal_for_degrees()` helper.
