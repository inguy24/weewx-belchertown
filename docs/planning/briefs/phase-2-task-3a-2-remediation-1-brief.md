# Phase 2 task 3a-2 — remediation round 1

**Round identity.** Round 2 of Phase 2 task 3a-2. Round 1 closed 2026-05-06 with all
8 endpoints implemented and 525/525 pytest passing on both backends; runtime
test-author surfaced 2 bugs, source auditor surfaced 3. Lead synthesized 4 findings
into this brief.

**Lead = Opus.** Sonnet teammate: `clearskies-api-dev`. Auditor (Opus) does NOT re-pass
unless the lead requests it (per the auditor agent definition).

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\`. Branch `main`
(NOT `master` — round-1 brief had this typo; api-dev round 1 figured it out and
silently corrected, but it cost test-author idle time. `git fetch origin main` is
the correct command.)

**Round-1 brief stays the source of truth.** This document patches it; don't
re-derive scope from scratch. Read [`phase-2-task-3a-2-brief.md`](phase-2-task-3a-2-brief.md)
in full first if you weren't the api-dev who landed round 1.

---

## Four findings to fix

### F1 — `location` hits the same configobj list-parse bug as altitude

- **Where:** `weewx_clearskies_api/services/station.py:247` (the `raw_location =
  station_section.get("location", "").strip()` read).
- **Why this fires:** real-world weewx.conf writes `location = Belchertown, MA`
  unquoted; configobj parses comma-containing scalars as Python lists, not
  strings. `.strip()` on a list raises `AttributeError`. Round-1 commit `4d4faf7`
  only patched `altitude`; the same bug pattern affects every comma-containing
  scalar in `[Station]`. Tests pass because every fixture quotes the location
  string — bypassing the list-parse path.
- **Lead's call:** accept. **Fix by extracting a helper** (don't copy-paste the
  altitude isinstance-list guard to every site):

  ```python
  def _get_str_field(section: dict, key: str, default: str = "") -> str:
      """Read a scalar field from a configobj section, normalizing
      configobj's list-parse of comma-containing values back to a string.
      """
      raw = section.get(key, default)
      if isinstance(raw, list):
          raw = ", ".join(str(item).strip() for item in raw)
      return str(raw).strip()
  ```

  Apply to `location` and defensively to `station_type` and `timezone` too
  (a `station_type = Davis Vantage Pro2, USA` would hit the same trap; an IANA
  identifier with a comma is not a real case but the helper costs nothing). The
  altitude path stays its own helper because it parses to a number, not a
  pass-through string.
- **Test additions (file: `tests/test_station_unit.py`):** unquoted comma-bearing
  `location` value parses to the joined string; same for `station_type` if a
  test reaches that field. Add fixtures that exercise the unquoted form (real
  weewx.conf shape), not just the quoted form.

### F2 — Almanac day window is UTC; should be station-local

- **Where (cascading sites):**
  1. `weewx_clearskies_api/services/almanac.py` — `compute_almanac(date)` day
     window construction (the `t0` / `t1` Skyfield Time pair).
  2. Same file — `daylightDeltaVsYesterdayMinutes` "yesterday" computation
     (currently uses UTC-yesterday; should use station-local yesterday).
  3. Same file — `/almanac/sun-times` year-loop date generation (year boundary
     should be station-local Jan 1 / Dec 31, not UTC).
  4. Same file — `/almanac/moon-phases` month-loop and year-loop date generation
     (same reasoning).
- **Why this fires:** for a station in EDT (UTC-4) on Jun 21, sunset is at
  20:29 EDT = 00:29Z Jun 22 — outside the Jun 21 UTC midnight-to-midnight
  window. The implementation returns the previous evening's sunset (Jun 20
  ~00:28Z) for Jun 21, causing `daylightMinutes=0` on the summer solstice for
  the project's own reference station (Belchertown, MA). All western-hemisphere
  stations affected on summer solstice; eastern-hemisphere stations have the
  symmetric problem at winter solstice.
- **Lead's call (per ADR-020 source priority):** accept. The day window is a
  station-local-date question; wire format stays UTC ISO-8601 with `Z` (no
  change there). For each compute site, build the window as
  `[station_local_date 00:00, station_local_date+1 00:00]` interpreted in the
  station's IANA TZ, converted to UTC for the Skyfield call. Use stdlib
  `zoneinfo.ZoneInfo(station.timezone)` — already loaded by `services/station.py`.
  Don't introduce a new TZ library.
- **Test additions:** test-author already documented bug 2 with a passing test
  asserting the buggy behavior + a comment. **Flip that test to assert the
  fixed behavior** (`daylightMinutes ≥ ~870` for Belchertown lat/lon on Jun 21).
  Add the symmetric winter-solstice test for an EDT station to verify no
  regression. Add tests at year boundary: `/almanac/sun-times?year=2026` for an
  EDT station should NOT include 2025-12-31 23:00 EST as a 2026 day, and
  SHOULD include 2026-12-31 (full station-local year covered).

### F3 — Nine `except Exception:` blocks in `services/almanac.py`

- **Where (all in `services/almanac.py`):**
  - Line 155 — Loader / ephemeris load
  - Line 212 — lazy-load fallback in `get_ts_eph`
  - Line 381 — sun rise/set in `_compute_sun_for_date`
  - Line 401 — civil twilight
  - Line 426 — sun position / transit
  - Line 446 — equinox/solstice
  - Line 505 — moon rise/set/transit
  - Line 540 — moon position / phase angle
  - Line 561 — next moon phases
- **Why this fires:** `rules/coding.md` §3 explicitly bans `except Exception:`;
  round-1 brief restated it. Auditor verified that the polar-edge case the
  comments cite is NOT exception-driven — Skyfield's `find_discrete` returns an
  empty events array for "no events today," not a raise. So the bare-Exception
  arms are catching something else: actual bugs (a renamed skyfield API after a
  version bump, a refactor TypeError, an AttributeError from a wrong-shape
  input). They get downgraded to DEBUG-level logs + null/zero/`"new"`
  fallbacks. Operator's default log level (INFO) won't surface DEBUG, so the
  service silently returns wrong data.
- **Lead's call:** accept. Two patterns:
  - **Loader / ephemeris-load paths (lines 155, 212):** narrow to `(OSError,
    IOError, urllib.error.URLError)` plus Skyfield's documented load-error class
    (consult skyfield 1.54 docs — there's a specific exception for ephemeris
    range/format errors). Re-raise unknown exceptions with a CRITICAL log so
    `__main__.py`'s startup gate exits non-zero.
  - **Per-day compute paths (lines 381, 401, 426, 446, 505, 540, 561):** drop
    the `except Exception` arms entirely. Polar-edge handling stays — but it's
    `if events.size == 0:` not `try/except`. Real exceptions propagate to
    FastAPI's RFC 9457 handler; operator gets a 500 with the request-id-tagged
    stacktrace.
- **Test additions:** add one negative-path test that monkey-patches a Skyfield
  call site to raise a synthetic `ValueError`, asserts the response is 500
  problem+json (NOT 200 with null fields). One such test is sufficient — the
  rule is "specific catches only," not "no catches"; the test proves the
  default behavior is propagation.

### F4 — `/station` "no such table" branch contradicts the brief contract and is unreachable in production

- **Where:** `weewx_clearskies_api/endpoints/station.py:78-84`. Commit
  `b7642ae` added a substring match on `"no such table"` / `"table" + "not
  exist"` in the SQLAlchemyError text and returns 200 + null records with a
  WARN.
- **Why this fires:** three problems. (a) Round-1 brief contract: "DB error on
  MIN/MAX query → 500 + RFC 9457; do not 200 with stale or null values."
  (b) Substring matching unstructured driver error text is brittle — different
  versions emit different messages; an unrelated error containing the literal
  substring `"table"` and `"not exist"` slips through. (c) The schema reflector
  at `__main__.py:227-239` fails-closed at startup if the archive table is
  missing per ADR-012; production cannot reach this branch. It only fires in
  test scenarios that bypass reflection.
- **Lead's call:** accept — drop the branch. **Plus: explain its provenance in
  your round-2 report.** Plausible reasons: (1) some integration test bypasses
  reflection and tests the endpoint with a missing archive; (2) the branch was
  added speculatively. If (1), name the test, and EITHER seed the archive in
  that test's fixture (so reflection wouldn't bypass anyway) OR delete the test
  (since it's testing a state production can't be in per ADR-012). If (2),
  delete is straightforward.
- **Test additions:** none directly. If a round-1 test depended on the dropped
  branch, fix or delete it per the provenance call. The empty-archive case
  (zero rows in the table) is a different scenario already covered: `MIN()` on
  an empty table returns NULL with no exception, and the existing
  null-firstRecord-and-lastRecord path handles it correctly. Confirm that test
  still passes after the branch is dropped.

---

## Process gates (carry-forward, not new)

1. **Submit your closeout report immediately after your final pytest run on
   `weather-dev`. Do NOT idle.** Round-1 api-dev sat ~30 minutes after its last
   commit before submitting; test-author sat ~48 minutes; both required ping
   intervention. The wall-clock cost is real. End your work with the report on
   the same tool round you push your final commit.
2. **Branch is `main`, not `master`.** `git fetch origin main && git merge --ff-only
   origin/main` is the correct parallel-pull command. The round-1 brief had
   `master`; ignore that — use `main`.
3. **No test-author parallel this round.** Add the tests yourself per finding's
   "test additions" section. The new tests carry `@pytest.mark.integration` if
   they exercise the endpoint via TestClient + DB; otherwise unit-suite
   default. Round size is small enough that a parallel test-author would add
   coordination overhead without speed benefit.
4. **Both backends green.** `pytest -m integration` against MariaDB and SQLite
   profiles. The 22 pre-existing skips stay skipped; not a regression.
5. **No new dependencies.** Round 1 added skyfield (and configobj earlier);
   that's it. STOP and ping the lead if you think you need another.
6. **DCO + co-author trailer.** `git commit -s` plus
   `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`.
7. **Diff budget:** target 150–400 line impl diff (excl. tests). Smaller than
   round 1 by an order of magnitude — these are surgical fixes, not new
   functionality. If it crosses 600, ping the lead before submitting.

---

## Reporting back

When you're done, report to the lead:

- Files touched (paths + LOC delta).
- For F1: confirm helper name + sites it's applied at; list the test additions.
- For F2: confirm all four cascading sites updated; list the test flips +
  additions; spot-check one summer-solstice computation against published
  reference (USNO).
- For F3: confirm specific exception classes used at the Loader paths;
  confirm bare-Exception arms removed at the per-day paths; describe the
  negative-path test.
- For F4: **explain why `b7642ae` was added in round 1 and what test (if any)
  depended on it.** If a test was deleted, name it.
- Pytest counts both backends.
- Anything that surprised you or any deviation from this brief.
