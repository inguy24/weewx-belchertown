# rules/coding.md — Coding Rules

Load when writing or modifying code in this project (Python, PHP, JavaScript/TypeScript, shell, Cheetah templates, SQL). Pair with the relevant domain rules — e.g., [weather-skin.md](weather-skin.md) for skin work, [clearskies-process.md](clearskies-process.md) for Clear Skies code.

These rules are concrete and actionable. When in doubt, prefer "boring and obvious" over "clever."

---

## 1. Security & safety — zero-trust posture

### Treat your own output as untrusted

LLM-generated code (including yours) is unverified until reviewed and tested against the real data shape. Before committing:

- Read every line you produced.
- Trace data flow at each trust boundary (HTTP input, external API response, file read, DB result).
- Run it against actual data, not synthetic examples.

### Never hardcode secrets

API keys, passwords, tokens, DB creds — never in source. Use:

- `.env` (already in `.gitignore`) for local secrets, loaded via the project's existing pattern.
- weewx `skin.conf` for skin-level *non-secret* config; secrets stay in `.env` and are referenced from there.
- Environment variables for runtime injection in containers.

If you find a secret already in source: stop, report it. Assume it's compromised the moment it lands in git history — rotation is mandatory, not a "fix in place."

### Validate inputs at trust boundaries

Trust boundaries on this project: HTTP request bodies/query strings, weewx archive DB rows (sensor data is mostly clean but rain/lightning/wind extremes can be wildly out of range), file uploads, external API responses (forecast, alerts, AQI), filesystem inputs, anything from a user-editable config file.

For each, validate **before use**: type, length/range, format (regex or schema), allowed-value list where possible.

### Use parameterized queries for SQL

The weewx archive DB and any future Clear Skies databases must use prepared statements:

- Python `sqlite3` / `mysql.connector` — `?` or `%s` placeholders, never f-strings.
- PHP — PDO with `bindParam` / `bindValue`, never string concatenation.

**Anti-pattern:** `f"SELECT * FROM archive WHERE dateTime > {ts}"` — even if `ts` "should be" an integer, validate-and-bind, don't interpolate.

### Backtick-quote SQL-reserved-word identifiers uniformly across all sites

When a column name (or any identifier) is a reserved word in any supported SQL dialect, it must be backtick-quoted at *every* site that references it in an SQL string — not site-by-site. SQLite tends to be permissive about reserved words; MariaDB is not, so a dual-backend test suite is the gate that catches this.

Known cases on this project: weewx's `interval` column collides with MariaDB's `INTERVAL` reserved word. Reserved-word lookups: [MariaDB reserved words](https://mariadb.com/kb/en/reserved-words/).

**How to apply:** when introducing SQL that references a weewx (or any external-system) column name, check the column name against the dialect reserved-word list before composing the query. If reserved, wrap with backticks `` `interval` `` consistently; do not rely on context-based lexer permissiveness.

**Why (2026-05-06):** during clearskies-api 3a-1 round 1, a one-site fix to `60 AS \`interval\`` missed a second site emitting `MAX(interval) AS interval`. SQLite passed; MariaDB raised `ProgrammingError 1064`. The dual-backend integration test caught the dialect drift, but the cost was a remediation round that wouldn't have been necessary with uniform backticking from the first edit.

### Pydantic `extra="forbid"` requires the right FastAPI wiring to actually enforce

Setting `extra="forbid"` on a Pydantic model is a security control (blocks unknown query params at the trust boundary per [`security-baseline.md`](../docs/contracts/security-baseline.md) §3.5). It only fires when the *whole* query string flows into Pydantic — which happens when the route uses `Depends(model_validator_function)` rather than declaring each query parameter individually with FastAPI's `Query()`.

**Anti-pattern (silently broken):**

```python
@router.get("/archive")
def get_archive(
    from_: str | None = Query(None, alias="from"),
    to: str | None = Query(None),
    limit: int = Query(1000),
    # ... etc
) -> ArchiveResponse:
    ...
```

FastAPI extracts only the declared fields from the query string and constructs the model from those — unknown keys never reach the model, so `extra="forbid"` doesn't fire. Operators can append `?nuke_the_db=1` and FastAPI returns 200.

**Right pattern:**

```python
def _get_archive_params(request: Request) -> ArchiveQueryParams:
    try:
        return ArchiveQueryParams.model_validate(dict(request.query_params))
    except ValidationError as exc:
        raise RequestValidationError(exc.errors()) from exc

@router.get("/archive")
def get_archive(
    params: Annotated[ArchiveQueryParams, Depends(_get_archive_params)],
) -> ArchiveResponse:
    ...
```

`model_validate(dict(request.query_params))` passes every HTTP key to Pydantic, so `extra="forbid"` fires for unknowns. `RequestValidationError` propagation keeps FastAPI's exception-handler chain (RFC 9457 problem+json output) intact.

**Why (2026-05-06):** clearskies-api 3a-1 round 1's `/archive` endpoint declared params individually; `extra="forbid"` was set on the model but never ran. test-author's `test_archive_unknown_query_param_returns_400_or_422` caught the gap; the security-baseline §3.5 control was silently bypassed. The fix is uniform across endpoints — wherever a Pydantic model gates a route, the wrapping pattern above must be used.

### Escape output before rendering

Cheetah templates and any HTML generation must escape values from external sources (forecast text, alert headlines, station name pulled from config) before rendering. Cheetah's `$value` does **not** escape by default — use `$webSafe($value)` or the project's existing escape filter.

In JavaScript: never `innerHTML` with untrusted data. Use `textContent` or a templating library that auto-escapes.

### Avoid dangerous functions

- **Python:** no `eval()`, `exec()`, `pickle.loads()` on untrusted data, `subprocess(..., shell=True)` with user input. Use `yaml.safe_load()`, never `yaml.load()`.
- **JavaScript:** no `eval()`, no `new Function()`, no `document.write()`, no `innerHTML` with untrusted data.
- **PHP:** no `eval()`, no `unserialize()` on untrusted data, no `system()` / `exec()` / `passthru()` with unsanitized input.
- **Shell:** no `eval`. Quote every variable expansion (`"$var"`, never bare `$var`). Never `bash -c "$user_input"`.

### Network code is IP-version-agnostic

Any code that listens, connects, resolves, parses, validates, formats, logs, or stores a network address must handle IPv4, IPv6, and dual-stack equally. Modern home networks include IPv6-only ISP delegations (GUAs, no ULAs in play), multi-VLAN topologies where link-local addresses don't reach across, and dual-stack hosts where the available family depends on the route. Code that only handles IPv4 silently fails for these users — silently because the symptom is "address not found" or "connection refused," not a clear error.

**How to apply:**

- **Listening (binding a server):** default to dual-stack. `localhost` resolves to both `127.0.0.1` and `::1` — bind both. Don't hardcode a single literal. Use `socket.getaddrinfo(host, port, type=SOCK_STREAM)` to resolve into the full `(family, address)` set and bind each result.
- **Connecting (outbound):** call `getaddrinfo` (Python `socket.getaddrinfo`, Go `net.Dial` with hostname, etc.). Never call `gethostbyname` — it's IPv4-only. Try all resolved families before reporting failure.
- **Parsing / validating:** use `ipaddress.ip_address` (Python), `net.ParseIP` (Go), `inet_pton` family (C), or the language equivalent. **Never** write a regex for "an IP address" that only matches IPv4 dotted-quad — IPv6 has multiple textual forms (`::1`, `2001:db8::5`, `2001:db8:0:0:0:0:0:5`, etc.) and they all need to validate as legal.
- **Formatting in URLs / logs:** wrap IPv6 literals in brackets when paired with a port (`https://[2001:db8::5]:9876/`, not `https://2001:db8::5:9876/` — ambiguous). The `urllib.parse` / `net/url` libraries do this automatically; if you're concatenating strings yourself, you're doing it wrong.
- **Configuration:** any config field that accepts an IP must accept both families. Documentation examples must show both. Don't show only `192.168.1.5` and assume IPv4 readers; include `2001:db8:1::5` or similar.
- **Range checks:** when classifying addresses (loopback / private / link-local / public), check both families. RFC1918 is IPv4-only; the IPv6 equivalents are RFC4193 (`fc00::/7`, unique-local) and `fe80::/10` (link-local). Use `ipaddress.ip_network` containment, not string-prefix matching.
- **Database / storage:** if storing an IP, use a column type that holds both (`INET` in PostgreSQL, `VARBINARY(16)` or two columns in MySQL/MariaDB; never `VARCHAR(15)` — that's IPv4-only by length).
- **Tests:** any test that exercises networking logic includes IPv6 cases. A test suite that only covers IPv4 will let IPv6 bugs through.

**Anti-patterns:** hardcoded `127.0.0.1` defaults; regex like `^(\d{1,3}\.){3}\d{1,3}$` for IP validation; documentation that only shows `192.168.x.y`; storing IPs as `VARCHAR(15)`; calling `gethostbyname`; building URLs by string-concatenation around IPv6 literals.

This rule applies project-wide — it governs the configuration UI's listener (per [ADR-027](../docs/decisions/ADR-027-config-and-setup-wizard.md)), the api and realtime services' listeners, any health-check probe code, any outbound provider call, any logging that includes a remote address, and any future networking code.

### Pin dependency versions

- **Python:** exact pins in `requirements.txt` (`==`) or `pyproject.toml` plus a lockfile (`pip-compile`, `poetry.lock`, `uv.lock`).
- **JavaScript:** commit `package-lock.json` / `yarn.lock`. Use `npm ci` in CI, not `npm install`.
- **Docker base images:** pin by digest (`FROM image@sha256:...`) for production, not just tags.
- **GitHub Actions:** pin third-party actions by commit SHA, not tag (`uses: foo/bar@a1b2c3d...`).

Note: SHA-pinning npm/PyPI packages is not standard practice — lockfiles are the equivalent guarantee. SHA-pinning is specifically for Docker images and GitHub Actions, where there's no lockfile.

---

## 2. Readability — code should self-document

### Names describe intent, not implementation

- `userAuthenticationManager` over `authMgr`.
- `parsed_alert_expiry` over `data` or `tmp`.
- `is_archive_record_stale(record)` over `check(r)`.
- Avoid abbreviations unless they're domain-standard (`url`, `id`, `db`, `aqi` are fine; `usrAuthMgr` is not).

For weewx-domain code, prefer weewx terminology (`observation`, `archive`, `loop_packet`, `unit_system`) over invented synonyms — same rule as [clearskies-process.md](clearskies-process.md).

### Follow community style

- **Python:** PEP 8. Use `black` for formatting and `ruff` for linting if they're configured in the repo.
- **JavaScript:** match the existing project style. Belchertown skin code has its own conventions — read what's there before reformatting.
- **PHP:** PSR-12 unless the file already follows another consistent style.
- **Cheetah templates:** 4-space indent, match the surrounding template.

Do **not** reformat unrelated code in the same diff — it makes review harder and rewrites blame. Reformatting goes in its own commit.

### Comment the WHY, not the WHAT

Names explain what; comments explain *why* something non-obvious is done a particular way:

- A workaround for a specific bug (link the issue/PR).
- A subtle invariant the code depends on.
- A constraint imposed by an external system.
- A trade-off where the obvious approach turned out to be wrong.

If a comment just restates the code, delete it. Default to no comments. Multi-paragraph docstrings are reserved for the public API of modules used by other code.

### Type hints

- **Python:** annotate functions touching non-trivial data structures. Use `mypy --strict` or `pyright` for new modules. Existing weewx-style modules without hints can stay until there's a reason to refactor.
- **JavaScript:** prefer TypeScript for new files. For existing JS, add JSDoc `@param` / `@returns` for non-obvious functions.

---

## 3. Organization & architecture

### Single responsibility

If a function does X *and* Y, split it. Heuristics that flag a needed split:

- Body longer than ~40 lines (not absolute — inspect).
- The name needs "and" to describe it.
- You can't write a one-line docstring without listing steps.
- Different parts of the body have different reasons to change.

### No mega-files

If a file passes ~500 lines and contains multiple unrelated concerns, split it. Belchertown's `index.html.tmpl` is an existing case where this rule has been violated — when touching it, prefer extracting includes over adding more.

### Catch specific exceptions; hide internals from users

- `except Exception:` is rarely right. Catch the actual class.
- User-facing error messages: brief, no stack trace, no DB schema names, no internal paths.
- Operator-facing logs: full context (stack, request ID, inputs).

### Dispatch on exception state via attributes, not message strings

When an exception class needs to convey state (HTTP status, retry-after seconds, internal error code) that callers will dispatch on, expose it as an attribute on the exception instance. Don't parse the message string with `if "404" in str(exc)` or similar substring checks.

**Why (2026-05-08):** clearskies-api 3b round 3 audit F2 caught `if "404" in str(exc)` in `providers/forecast/nws.py` translating NWS `/points` 404 → `GeographicallyUnsupported`. Two failure modes: (a) false positive — any 4xx whose body excerpt contains the literal `"404"` matches; (b) silent regression on wrapper-message format change — if `ProviderHTTPClient`'s message format ever shifts from `"Provider {id} returned unexpected {status}"` to anything else, the substring stops matching and the 404→503 mapping breaks with no test catching it. Remediation added `status_code: int | None` to `ProviderError.__init__`, propagated via `ProviderHTTPClient`'s 4xx/5xx raises, and changed the call site to `if exc.status_code == 404`. Same pattern applies to any future status-or-state-dependent dispatch (Aeris's 401-vs-403 distinctions, OWM's payload-bearing 4xx, etc.).

**How to apply:**

- When designing a provider/wrapper exception class that callers will need to inspect: add structured attributes (e.g. `status_code`, `error_code`, `retry_after_seconds`) at construction time, document them in the class docstring, and have callers dispatch on the attribute.
- Message strings are for humans (operator logs, error responses). Don't make program flow depend on them.
- This applies to any exception hierarchy, not just HTTP wrappers — same principle for parser errors with structured position info, file errors with structured paths, etc.

### DRY — search before writing a new helper

**Before** writing a new utility function, in this order:

1. `Grep` for the function name you're considering.
2. `Grep` for keywords describing what it does (e.g. "convert", "celsius", "format date").
3. Check the obvious utility modules (`utils/`, `lib/`, `helpers/`) in the relevant package.

If something close exists, extend or call it. If the existing version isn't quite right, prefer fixing it (and updating callers) over forking a near-duplicate.

**Why:** Duplicate utilities drift. The user has flagged "do we already have a function for that?" as a recurring concern, and the cost of a 5-second grep is much lower than the cost of two implementations of "format windspeed for display" that disagree six months later.

**How to apply:** Treat the search as a required pre-write step, not optional. Surface what you searched for in your reply ("checked `utils/format.py`, no `format_wind_speed` — writing new"). This gives the user a chance to point at something you missed before you've written it.

### No dead code

When a function, branch, import, or variable becomes unused, delete it in the same change.

- No commented-out code "for reference" — git history is the reference.
- No unused imports "in case we need them later" — re-add when needed.
- No speculative helpers without a current caller.
- Renaming a variable to `_unused` or prefixing with `_` to silence linter warnings is not deletion. Delete it.

If you spot dead code adjacent to your change but unrelated to it, mention it in your reply and ask whether to remove — don't silently expand scope ([Simple means simple](../CLAUDE.md)).

---

## 4. Self-review before declaring done

Before saying "done":

1. Re-read the diff. Treat it as a code review of someone else's work.
2. Check for: debug prints, commented-out blocks, leftover TODO notes, unused imports, hardcoded test values.
3. Run the linter / type-checker / tests if they exist in the repo.
4. For UI changes, actually load the page in a browser. Type-checking is not feature-checking — see [CLAUDE.md](../CLAUDE.md) "For UI or frontend changes" rule.
5. **For UI changes, run the Section 5 accessibility audit checklist below before declaring done.** Not optional. The user has explicitly flagged WCAG compliance as load-bearing, not Phase 4 polish.

If you can't test the change (no dev server, no fixture data), say so explicitly — don't claim success on something you couldn't exercise.

---

## 5. Accessibility — WCAG 2.1 AA target

The Clear Skies project commits to **WCAG 2.1 Level AA conformance** as the project-wide accessibility floor. This is a load-bearing constraint, not a polish-pass deliverable. User directive 2026-05-02: "ADA compliance is something we HAVE to make sure we are always keeping an eye on. … audit all code after it is written for compliance and then have a full audit before shipping."

These rules apply to every UI surface — dashboard SPA, configuration UI, NOAA-report HTML rendering, error pages, setup wizard.

### When this section applies

- You are writing or modifying anything a user sees: React/JSX, HTML templates, Cheetah templates, SVG/CSS, generated reports.
- You are choosing or adjusting colors, contrast, fonts, sizes, spacing.
- You are adding, removing, or rearranging interactive elements (buttons, links, inputs, menus, modals, tabs).
- You are adding, modifying, or replacing graphics (icons, weather icons, photos, charts, logos).

If a change is purely backend (API response shape, DB query, log format), the rest of this section can be skipped — but if the API change reshapes a UI surface (e.g., new data field appears in a tile), the consuming UI change is in scope.

### 5.1 Color and contrast

- **Normal text:** contrast ratio ≥ **4.5:1** against its background.
- **Large text (≥ 18pt regular or ≥ 14pt bold):** contrast ratio ≥ **3:1**.
- **Non-text UI components and graphical objects:** contrast ratio ≥ **3:1** for boundaries, focus indicators, icons that convey meaning.
- **Verify with a real tool**, not your eye. Use `npx @axe-core/cli`, the Chrome DevTools Accessibility panel's contrast checker, or [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/). Don't claim compliance from a screenshot.
- **Light AND dark themes both audited** — a palette that passes AA in light mode often fails in dark mode (or vice versa). Both modes audit independently.
- **Color is not the only signal.** Don't rely on color alone to convey state — pair with an icon, label, pattern, or position. (E.g. a red "alert" pill must also have an icon or word "alert," not just the color.)
- **Do not "fix" failing contrast by darkening/lightening to a near-fail.** If a brand color won't pass, pick a different shade or a different role for that color. Aesthetic preference does not override compliance.

### 5.2 Semantic HTML

- **Use the right element for the job.** `<button>` for buttons, `<a>` for links, `<nav>` for navigation, `<main>` for the primary content region, `<header>`/`<footer>`/`<section>`/`<article>` where they apply, `<h1>`–`<h6>` in document order with no skipped levels.
- **Don't use `<div>` or `<span>` with click handlers when a `<button>` will do.** A `<div onClick>` is invisible to screen readers, not keyboard-focusable, and not announced as actionable. Use `<button>`.
- **Forms:** every `<input>`/`<select>`/`<textarea>` has a `<label>` (visible, or visually hidden via `class="sr-only"` if the design demands no visible label). `placeholder` is not a label. Inputs with errors use `aria-describedby` to point at the error text and `aria-invalid="true"`.
- **Lists are lists.** Use `<ul>`/`<ol>`/`<li>` for lists, not stacked `<div>`s.
- **Tables are tables.** Records page, NOAA report HTML view, any tabular data: `<table>` with `<thead>`/`<tbody>`/`<th scope="col"|"row">`. Don't fake tables with CSS grid alone.

### 5.3 Keyboard navigation

- **Every interactive element is reachable by Tab.** No mouse-only widgets.
- **Tab order matches visual order.** Don't use `tabindex` values > 0 to reorder; fix the DOM order.
- **Visible focus indicator on every focusable element.** Don't `outline: none` without a replacement. Tailwind's default focus rings are fine if they pass 5.1's 3:1 contrast against the background.
- **Escape closes modals/menus/dropdowns.** Enter/Space activate buttons. Arrow keys move within tab/menu/listbox widgets per the [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/patterns/) for the relevant pattern.
- **Skip-to-main-content link** at the top of the document so keyboard users can bypass the nav on every page.
- **Focus traps** inside modals: Tab/Shift-Tab cycles within the modal; closing the modal returns focus to the element that opened it.

### 5.4 ARIA — only when semantic HTML can't do it

- **First rule of ARIA: don't use ARIA.** Use the right HTML element. ARIA is for cases the platform doesn't cover.
- **Icon-only buttons need `aria-label`.** A `<button>` containing only `<svg>` (e.g. a hamburger, a close-X, a search-magnifier) MUST have an `aria-label="Close"` / `aria-label="Open menu"` etc.
- **Decorative SVGs/icons get `aria-hidden="true"`** so screen readers don't read them.
- **Dynamic regions** (toast notifications, live-updating values, alert banners) use `aria-live="polite"` (or `="assertive"` for genuine emergencies). Live-updating outdoor temperature is `polite`; an active tornado warning is `assertive`.
- **Don't lie with ARIA.** A `role="button"` on a `<div>` doesn't make it keyboard-actionable — you still have to wire keydown handlers and focus management. Use `<button>`.

### 5.5 Images and graphics

- **Every `<img>` has an `alt` attribute.** No exceptions. The attribute is mandatory; the value depends on the role of the image:
  - **Informational** (weather icon next to "Sunny"): descriptive alt — `alt="Sunny"`.
  - **Decorative** (background hero photo): empty alt — `alt=""`. Empty is correct, missing is wrong.
  - **Functional** (clickable share icon): describe the action — `alt="Share on Mastodon"`.
  - **Complex** (chart, infographic): short alt + long description nearby (`<figcaption>` or `aria-describedby`).
- **Operator-uploaded images: alt text required at upload.** Setup UI does not accept an image without an alt text field filled in. No "I'll do it later" path.
- **Built-in icon set:** every weather icon ships with a known alt-text mapping (e.g. `clear-night.png` → `"Clear, night"`). The mapping is part of the source, not derived at runtime.
- **SVG icons:** if the SVG is informational, use `<svg role="img"><title>Description</title>…</svg>` or `aria-labelledby` pointing at a `<title>`. If decorative, `aria-hidden="true"` and `focusable="false"`.
- **Charts (ECharts):**
  - Set `aria-label` on the chart container summarizing what the chart shows.
  - Render a screen-reader-only data table alongside the chart (`class="sr-only"` on the `<table>`) so non-sighted users can read the actual values.
  - Verify keyboard navigation works for tooltips (ECharts has `aria` config — enable it).

### 5.6 Localization and accessibility

- **`<html lang="…">`** set correctly for every page based on the active locale (per the i18n decision — 13 locales for v0.1: en, de, es, fil, fr, it, ja, nl, pt-PT, pt-BR, ru, zh-CN, zh-TW).
- **Bidirectional text:** v0.1's locale set has no RTL languages, so `dir="rtl"` work isn't required now — but don't write CSS that assumes LTR (use `margin-inline-start` instead of `margin-left`, etc.) so RTL is a future-add, not a future-rewrite.

### 5.7 Per-change audit checklist

Run this before declaring any UI change done. Check each item explicitly — don't skip on the assumption "it's a small change."

- [ ] Every new/modified `<img>` has an `alt` attribute (empty if decorative, descriptive otherwise).
- [ ] Every new icon-only button has an `aria-label`.
- [ ] Every new `<input>` has a `<label>` (visible or sr-only).
- [ ] Every new color combo has been checked against AA contrast in BOTH light and dark themes.
- [ ] Every new interactive element is keyboard-reachable and has a visible focus indicator.
- [ ] Heading levels (h1–h6) in document order, no skipped levels.
- [ ] No `<div onClick>` where a `<button>` belongs.
- [ ] If the change adds dynamic content, `aria-live` is set appropriately.
- [ ] If the change is to a chart, the data-table fallback is updated to match.
- [ ] `npx @axe-core/cli` (or equivalent) run against the modified page; zero violations OR a documented reason for any remaining warnings.

### 5.8 Pre-ship full audit

Before tagging any release (v0.1.0, v0.2.0, etc.):

1. **Automated:** full axe-core scan of every page in the SPA (`@axe-core/playwright` against the Playwright test pages, or `@axe-core/cli` against a built static site). Zero violations target; documented exceptions for any remaining warnings.
2. **Manual keyboard-only run:** load the dashboard with no mouse, navigate every page, every modal, every form. Confirm every interactive element is reachable, focus indicator visible at every step.
3. **Screen reader spot check:** NVDA on Windows or VoiceOver on macOS. Walk the home page, configuration UI, and NOAA-report page. Confirm announcements make sense, no orphan `<div>` content, no untitled regions.
4. **Lighthouse Accessibility score** ≥ 95 on home, configuration UI, charts page, records page. (Lighthouse alone doesn't catch everything, so it supplements the above — it doesn't replace them.)
5. **Color-blindness simulation pass:** Chrome DevTools' Rendering tab → Emulate vision deficiencies (protanopia, deuteranopia, tritanopia, achromatopsia). Verify no UI state is conveyed by color alone.
6. **Document the audit run** in `docs/audits/accessibility-vX.Y.md` with the date, tools used, findings, and resolutions. This becomes part of the release artifact.

### 5.9 What "load-bearing" means in practice

- An accessibility issue is **release-blocking**, not "we'll get to it." Same severity as a security vuln or a broken-build.
- A design decision (palette, layout, motion) that creates an accessibility problem must be revised, not waivered.
- "We can fix it after launch" is the wrong posture. The user has been explicit: per-write audit + pre-ship full audit. Audits don't happen at the end if they aren't built into the development loop from day one.
