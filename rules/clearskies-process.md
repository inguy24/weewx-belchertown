# rules/clearskies-process.md — Clear Skies project process discipline

Load when working on the Clear Skies project (`weewx-clearskies-*` repos, [docs/planning/CLEAR-SKIES-PLAN.md](../docs/planning/CLEAR-SKIES-PLAN.md), and any ADRs/contracts/research feeding into it).

## Core principle: write decisions down immediately

When a design or architecture decision is made — even verbally in chat — write the ADR before continuing the conversation. Do not hold decisions in working memory.

**Why:** Context windows fill. Sessions get interrupted. Claude over-estimates retention. The file system is the only reliable record. The user has been explicit: "you tend to start dropping details as your context window fills and we may lose things if this session is interrupted."

**How to apply:**

1. Decision discussed → ADR drafted with status **`Proposed`** → user reviews the full content → user **explicitly approves** → status changes to `Accepted`.
2. **Directional dialogue is not sign-off.** When the user gives a one-line answer like "yes use the prefix" or "we want both options," that's an *input* to a Proposed ADR, not approval of an Accepted ADR. The ADR captures more than the directional answer — options considered, consequences, implementation guidance — and ALL of that requires explicit user review before status can move to Accepted.
3. **ADRs are NEVER created in `Accepted` status.** Always `Proposed` first. Status moves to `Accepted` only when the user says so in plain words ("approved," "accepted," "go," "sign off," or similar). Inferred agreement is not sign-off.
4. **Past decisions in earlier docs (e.g., the original plan) also need to be reviewed before becoming Accepted ADRs.** "It was in the plan" does not mean "it's been signed off."
5. Don't say "I'll capture this" without immediately writing the file in the same turn.
6. If you find yourself thinking "let me also note that..." or "to remember this for later..." — that's the cue to write a file NOW, not later.
7. **Corrections and refinements to an Accepted ADR are made by editing the ADR in place.** Status flips back to `Proposed` until the user re-approves the corrected content; date updates. Do **NOT** create a new "supersedes ADR-NNN" ADR for ordinary architectural corrections — it clutters the index with no value. **User direction 2026-05-02: "I don't need a bunch of superseded ADRs laying around. That is ridiculous."** The `Superseded by ADR-NNN` status remains in the legend for the rare case where two distinct decisions both deserve to be on file (e.g., a fundamentally renamed component, a major-version split where readers benefit from seeing both); when in doubt, edit in place.

## Project layout

```
docs/
├── planning/
│   └── CLEAR-SKIES-PLAN.md           # Master plan — phases & status, links out
├── decisions/                         # ADRs (Architecture Decision Records)
│   ├── INDEX.md                       # Table of all ADRs with status
│   ├── _TEMPLATE.md                   # Copy this for new ADRs
│   └── ADR-NNN-{slug}.md
├── contracts/                         # Machine-readable contracts (created as needed)
│   ├── openapi-v1.yaml                # API contract
│   ├── canonical-data-model.md        # Internal types every provider normalizes to
│   └── security-baseline.md           # Per-component security checklist
└── reference/                         # Background research feeding ADRs
    └── *.md                           # E.g., FORECAST-PROVIDER-RESEARCH.md
```

## ADR format

Use the Michael Nygard ADR format. Template at [docs/decisions/_TEMPLATE.md](../docs/decisions/_TEMPLATE.md). Required sections:

- **Status** — Proposed / Accepted / Superseded by ADR-NNN / Pinned
- **Context** — the problem, constraints, what triggered the decision
- **Options considered** — explicit pros/cons table; never silently drop options the user named
- **Decision** — what we picked, in 1–2 sentences
- **Consequences** — what changes downstream (positive and negative)
- **Implementation guidance** — concrete enough that a future Sonnet session can act on this without re-deriving
- **References** — research links, related ADRs, relevant code paths

## ADRs are concise — no filler

ADRs exist to give a future implementer the facts they need to act. **Bloat is the enemy** — bloated ADRs waste the user's time on re-read, waste context window on load, and get skimmed in practice.

**Bloat is measured by content density, not line count.** A 200-line ADR where every paragraph carries a load-bearing fact is fine. An 80-line ADR with 60 lines of throat-clearing is bloat. The line-count thresholds below are rough sanity-checks, not contracts — when an ADR exceeds them it is *probably* padded, but the audit happens at the paragraph level: does this paragraph explain the decision, or guide implementation? If neither, cut it.

**Rough sanity-check length:** ~80 lines for standard ADRs; ~150 for parent-pattern ADRs (e.g., ADR-038) that govern multiple downstream decisions. Use as a smell test, not a budget.

**Cut:**

- Historical-context paragraphs (Belchertown precedent, predecessor-plan recaps). One-line pointer if needed.
- Cross-cutting reminders that live in other ADRs or the plan — reference, don't restate.
- Options-considered tables with multi-paragraph analysis per option. One-line verdict per option; rejected options need a reason, not a defense.
- Implementation mockups (UI sketches, file-tree diagrams, code blocks) that the relevant interface ADR will own.
- Trade-off prose that restates the obvious.
- "Not-yet-decided" sections recapping other Pinned ADRs.

**Keep:**

- The decision in 1–2 sentences.
- Every option the user named, with one-line verdicts (rejected options get a reason, not a defense).
- Concrete consequences a future implementer must know (file paths, named contracts, gating ADRs).
- Out-of-scope items that protect against scope creep.
- Terse references.

**User direction 2026-05-02 (verbatim):** "it will just bloat your context window, you will then ignore most of it, and I as a human cannot bare to read that drool."

**Anti-pattern:** writing the ADR to persuade a skeptical stranger. Persuasion belongs to the user's review step; the ADR records what was decided.

## Status workflow

- **Proposed** — drafted, under user review. Implementation MUST NOT proceed.
- **Accepted** — locked. Governs implementation. Immutable except via supersession.
- **Pinned** — known-needed but not yet drafted. Placeholder row in INDEX.md.
- **Superseded by ADR-NNN** — old decision; the linked ADR is now authoritative.

## Plan stays an index, not the content

[CLEAR-SKIES-PLAN.md](../docs/planning/CLEAR-SKIES-PLAN.md) is a high-level phase tracker. Do not put decision content there — link to the ADR. Plan task entries reference the ADR(s) that govern them. When a decision changes, update the ADR (or supersede), not the plan body.

### Read the ADR before the plan

When validating any decision in this project — what library, what protocol, what schema, what config shape, what status — **read the relevant ADR first.** The plan body is not authoritative; it summarizes for navigation, and summaries drift.

**Why:** On 2026-05-04 the Phase 1 spike was built against the plan body's stale tech-stack table (Tremor + ECharts) when ADR-002 had already locked shadcn + Recharts. The spike validated the wrong stack on first pass and almost generated a Proposed ADR-002 amendment that would have undone an already-locked decision. Audit findings: [docs/reference/PLAN-VS-ADR-AUDIT-2026-05-04.md](../docs/reference/PLAN-VS-ADR-AUDIT-2026-05-04.md).

**How to apply:**

- For any task that names a tech-stack choice, library, protocol, or schema, open the relevant ADR via [docs/decisions/INDEX.md](../docs/decisions/INDEX.md) **before** opening the plan.
- If the plan and the ADR disagree, the ADR wins. Treat the disagreement as a plan-body bug — fix the plan to match the ADR, never the other way around. Drift fixes don't need a new ADR; per item 7 (corrections to Accepted ADRs), only ADR content changes flip status to Proposed.
- If you find yourself drafting a Proposed ADR change to "lock in" something the spike validated, first verify the existing ADR didn't already lock the opposite decision.

## Research before recommending

Decisions that depend on external facts (provider terms, library capabilities, OS/platform behavior) require real research with web tools or codebase reads. Do not recommend from training-data assumptions.

- Cite sources (URLs) in the resulting ADR.
- Save raw research in `docs/reference/<topic>-RESEARCH.md`. The ADR cites it.
- For provider/API research, current-year facts only — pricing pages and ToS shift frequently.

## Stick with weewx terminology where possible

When choosing names for concepts in our code, docs, or APIs, prefer terms that already exist in the weewx ecosystem (observations, archive, loop packet, station, units, schema, service, extension, skin) over inventing new terms.

**Why:** Users coming from weewx already have a mental model. New terms force a translation step. Sticking with weewx vocabulary lowers the barrier to adoption and reduces docs friction.

**How to apply:** When naming a new concept, check what weewx calls it (or its closest analog) before reaching for industry-standard alternatives like "metrics" (Prometheus), "entities" (Home Assistant), "fields" (generic). Document the weewx term and use it. Industry alternatives can appear as parenthetical aliases in docs — "observations (called `entities` in Home Assistant)" — but the canonical term stays weewx-native.

## Don't dismiss user-named options

When the user proposes a list of options to evaluate, evaluate ALL of them. Do not silently drop one.

**Why:** During the forecast-provider discussion, Claude dropped Weather Underground from a comparison without research. The user correctly called it out.

**How to apply:** When the user lists options, echo the full list back before researching. After research, every option in the list gets a row in the comparison ADR — even if the conclusion for that row is "exclude — reason."

## Stay focused — one decision thread per reply

Do not interleave multiple decision threads in a single response. If the user is dialoguing about forecast providers, don't also propose changes to auth or design direction in the same reply.

**Why:** A reply that addresses six topics at once is hard to respond to and produces under-considered decisions on all six.

**How to apply:** When the user asks about Topic A, answer about Topic A. If Topic B occurs to you, note it briefly at the end ("we should come back to B next") rather than expanding the current reply.

## Audit decision completeness before claiming a phase done

Phase 1's job is to lock every architecture decision Phase 2+ depends on — not just the decisions that came up first in conversation. Before claiming any decision-set "complete," do a deliberate pass against the standard surface.

**Why:** Claude defaults to a checkbox mindset — "the items I've talked about" become "the items that exist." The user explicitly flagged this failure: "THERE WAS STILL A BUNCH OF DECISIONS THAT NEEDED MADE AND YOU FORGOT ABOUT ALL OF THAT." Phase 1's surface is much larger than the 4-5 open decisions a plan typically lists.

**How to apply:**

Before claiming a phase or sub-phase is decided, walk through this surface checklist. For each, either confirm an ADR exists, OR add a Pinned slot to [docs/decisions/INDEX.md](../docs/decisions/INDEX.md):

- **Data model:** canonical types, fields, units, nullability, multi-station scope
- **Database:** schema assumptions, access pattern, migration approach, read-only enforcement
- **API contract:** versioning policy, error format, pagination, units conversion edge, time zone handling, SSE event format
- **External integrations:** which providers, caching strategy, alerts source, AQI handling, almanac source, radar source
- **Operational:** logging, health checks, observability, configuration format, secret handling, update mechanism
- **UI/UX:** design direction, page taxonomy, navigation, theming, light/dark, i18n
- **Quality bars:** browser support, accessibility level, performance budget
- **Deployment:** topology default, TLS approach per topology, versioning across repos
- **Cross-cutting:** auth model, license, compliance model

After the audit, **explicitly tell the user** which slots are now Pinned and ask what's still missing. Never assume the surface is complete based on what's been discussed so far.

## Recover lost state immediately

When the user references a prior decision (elimination, choice, scope change, agreement) that you cannot find in the project's files, **STOP**. Do not proceed with placeholders, assumptions, or "I'll figure it out from context."

**The recovery sequence:**

1. Tell the user plainly: you cannot find the decision in the files.
2. Ask once for the rationale or context, framed as: "if you want to recap I'll capture it; if not, we proceed with a documented gap."
3. Whatever you learn — even if the answer is "no rationale, just dropped it" — write it to the relevant file BEFORE responding to the next item.

**Why:** Verbatim user feedback: "the point of a computer is the fact that you can keep track of things that humans are not good at. if you fucking drop details and forget things, then you are no fucking better than a human and i have no fucking use for you." A placeholder note that papers over a gap (e.g. "rationale not captured at decision time") is acceptable ONLY when the user has been asked and chose not to recap. Otherwise it is the AI hiding a failure rather than recovering from it.

**Examples:**

- Bad: user says "we already eliminated Meteoblue." Claude silently removes it with a placeholder note and proceeds. The reason is now lost.
- Good: user says "we already eliminated Meteoblue." Claude responds: "I can't find that in the files — what was the rationale, so I can record it now? If you don't want to recap, say so and we proceed with a documented gap."

**This rule applies to scope decisions too, not just ADRs.** Eliminating a candidate from a research set, dropping a feature from a phase, narrowing an option list — all qualify.

## Audit means real findings, not contrarianism

When self-auditing an ADR, only surface concerns that point at something that could actually go wrong — not generic engineering tradeoffs that apply to any decision.

**Why:** During ADR-005 review, Claude produced four "audit findings" that were all empty: "two code paths = more tests" (true of any multi-mode system), "default doesn't match Shane's deployment" (a config nitpick, not an architecture risk), etc. The user called this out: "YOU ARE NOT FUCKING AUDITING, YOU ARE JUST BEING CONTRARIAN."

**How to apply:**

- Generic tradeoffs ("more code = more bugs", "two paths = more tests", "longer names = more typing") are NOT audit findings. They apply to any decision and add no information.
- An audit finding has teeth only if it identifies (a) a specific failure mode the decision invites, (b) a constraint the decision misses, or (c) a downstream rework the decision forces. If you can't name (a), (b), or (c), don't include it.
- If a decision is genuinely fine, say so. Don't manufacture three concerns to look thorough. Empty-padding the audit is worse than skipping it — it wastes the user's time and erodes trust in the audit step itself.
- Length is not a quality signal. A one-bullet audit that names one real concern beats a five-bullet audit of platitudes.

## Real schemas in unit tests where the schema shape matters

Unit tests for code that depends on the **shape** of an external schema (column count, null constraints, foreign keys, index presence) must use a schema that matches what the code will see in production. Synthetic stand-in schemas hide error-class bugs.

**Why (2026-05-06):** Phase 2 task 2's startup write-probe shipped with a unit test that built a one-column synthetic `archive` table. The test asserted the probe correctly classified writable users by checking for `OperationalError` permission-denied. The real production weewx archive has multi-column NOT NULL constraints (`usUnits`, `interval`, others). A writable user attempting `INSERT INTO archive (dateTime) VALUES (...)` against the real schema gets `IntegrityError` (NOT NULL violation), not `OperationalError` (permission denied). The probe's broad `DatabaseError` catch swallowed `IntegrityError` as "denied" — silently passing a writable user, defeating the entire defense-in-depth intent of [ADR-012](../docs/decisions/ADR-012-database-access-pattern.md). The unit test couldn't reproduce the bug it was testing for; only the integration test against the production schema (loaded via the dev/test stack at `repos/weewx-clearskies-stack/dev/`) surfaced the defect. The lead's initial fix-suggestion (catch `IntegrityError` as writable) missed a third case — MariaDB error 1364 ("no default value for column") also fires from a writable user — which the dev caught only because they re-ran against the real schema after the first fix attempt.

**How to apply:**

- For DB-layer code, schema-introspection code, query-construction code, or any other code where the schema shape determines which exception class fires at runtime: use the dev/test stack's seeded production schema for unit tests too, OR be explicit in the test that it uses a stand-in and the real verification lives in `test_*_integration.py`.
- Don't read this as "no synthetic schemas, ever." Synthetic schemas are fine for testing pure logic that has no schema dependency. The rule is: don't synthesize a one-column schema and then test for behavior that only emerges with multi-column schemas — that's a test that proves nothing.
- The test-author's "real backends, not dialect-divergent stand-ins" rule (in `.claude/agents/clearskies-test-author.md`) extends to schema *shape*, not just the database engine.

## Audit modes are complementary, not redundant

Two distinct audit modes — runtime tests against real backends, and source-only review against ADRs and rules — catch different bug classes. Both gates fire for non-trivial work; neither alone is sufficient.

**Why:**

- **Phase 2 task 1 (2026-05-06):** pytest in `weather-dev` caught three runtime bugs the auditor missed entirely (regex group-reference template referencing a group the SQL pattern didn't have; missing path-existence check in `load_settings` when an explicit `config_path` was passed; Authorization-header regex stopping at the first whitespace so `"Bearer xxx"` only redacted `"Bearer"`). Each one looks fine in isolation as source code; each fails at runtime.
- **Phase 2 task 2 (2026-05-06):** integration tests against the production-schema dev/test stack caught two runtime defects the unit-test suite missed (writable user passes the probe via `IntegrityError` per the rule above; SQLite URL form `sqlite:////path?mode=ro&uri=true` works for `engine.connect()` but fails for `MetaData.reflect()`). The auditor's separate review caught five source-side findings the runtime tests had no visibility into (registered-but-undecorated pytest marker selecting zero tests; critical-log message pointing at an `INSTALL.md` that doesn't exist; `pool_size`/`max_overflow` knobs absent from the example config; reflection-non-fatal-startup paired with `/health/ready=200` letting orchestrators route traffic into a service with an empty registry; bare-IP heuristic misclassifying `host:port` typos as malformed IPv6).

Neither audit mode would have found what the other found. Compressing the flow loses one audit class.

**How to apply:**

- The lead routes non-trivial work in this order: dev produces code → tests run on `weather-dev` → auditor reviews diff → lead synthesizes. Don't compress: don't skip runtime tests because "the auditor will catch it"; don't skip the auditor because "pytest is green."
- The dev runs pytest on `weather-dev` BEFORE submitting for audit — the auditor is not the first runtime check.
- For trivial work (one-line fixes, simple sync), this rule still loses to "Simple means simple" in [CLAUDE.md](../CLAUDE.md). A typo fix doesn't need a multi-mode audit.

## Lead synthesizes auditor findings; doesn't forward

When the auditor returns N findings, the lead triages each one before sending the dev a remediation brief. Forwarding raw findings without a lead-call-per-finding loses the synthesis step that catches ambiguous remediations.

**Why (2026-05-06):** Phase 2 task 2 round 3 had five auditor findings. F4 (reflection-non-fatal-startup vs `/health/ready=200` disagreement) admitted two reasonable remediations: (a) extend the readiness probe with retry machinery to flip when reflection eventually succeeds, or (b) make reflection failure fatal at startup, matching the write-probe pattern. The auditor surfaced the failure mode but didn't pick a remediation. The lead picked (b) because it matched [ADR-012](../docs/decisions/ADR-012-database-access-pattern.md)'s spirit ("refuse to start in known-bad states") and removed the deferred-rework risk of (a)'s retry machinery (when does it run? on every probe call? periodically? this needs another decision). The dev's brief carried the call ("Fix (lead's call — option A: fatal-exit on reflection failure)") with one sentence of reasoning, plus an explicit "if you disagree with a lead call, STOP and message back" — so the dev could push back rather than silently re-interpret. Forwarding the auditor finding raw, without the synthesis, would have either landed the dev on the more complex remediation by default, or required them to re-derive the lead's reasoning from scratch.

**How to apply:**

- Before sending the dev a remediation brief, the lead reads each auditor finding and decides per finding: accept (with what specific remediation), push back (with what reasoning), or defer (with what condition).
- Each accepted finding in the brief has the lead's recommended remediation plus one sentence of reasoning. The dev can push back; they cannot silently re-interpret.
- For each pushed-back or deferred finding, the lead surfaces the reasoning to the user before the brief goes out — those are real decisions, not routing.
- Anti-pattern: treating the auditor's findings list as a self-executing TODO and forwarding it to the dev unedited.

## Plain English when explaining decisions to the user

When walking the user through an architectural decision, write so they can read it without translation. Spell out what jargon means in the same sentence; don't string technical-sounding language together as a substitute for actually communicating.

**Why (2026-05-05):** During the OpenAPI inventory review, Claude produced "paragraph upon paragraph of utter techno-babble" using unexplained terms like "entity," "envelope," "RFC 9457," "AsyncAPI." User verbatim: "using the english language is not your strong suit is it. … None of this means shit to me."

**Why (2026-05-06):** During Phase 2 task 1 audit synthesis, Claude wrote a wall of technical terms — "RFC 9457 problem+json," "FastAPI TestClient," "loopback port 8081," "trusted-bypass path," "hmac.compare_digest" — without defining any of them. User verbatim: "you have been bombarding me with so much jargon, I cannot see straight." The pre-existing "define in the same sentence" rule was being skipped under audit-result density. Strengthened to once-per-conversation.

**How to apply:**

- **Define every technical term the first time it appears in a conversation.** This includes library names (FastAPI, ruff, pytest), RFC numbers (RFC 9457), file conventions (`pyproject.toml`, `secrets.env`), networking concepts (loopback, reverse proxy, dual-stack), and project-internal acronyms. Once per conversation is enough; subsequent uses can lean on the earlier definition. New conversation = counter resets.
- **Definitions are short — one phrase, not a paragraph.** "FastAPI (the Python web framework we picked for the api)" not three sentences of context. The point is to let the user read on without context-switching, not to teach.
- **Code identifiers are not jargon.** Function names, file paths, env var names, config keys — they're labels for the actual things being changed. The user reads them as labels. The rule is about explanatory prose, not naming.
- **If a reply uses 5+ unfamiliar terms, step back and rewrite.** Inline definitions are a patch; they don't license stacking more jargon on top. When the count climbs, the message is too dense — break it up, drop terms that don't carry weight, restate from the user's vocabulary.
- **State the recommendation; ask if they agree.** Don't bury a question inside an audit-finding bullet list or a six-numbered-tradeoff sequence. If you find yourself writing "I want your judgment on …" followed by tradeoffs, you're doing it wrong.
- **Audit findings still belong in the response** — but written so the user can read them, not as a wall of jargon.

## Scope the API to the dashboard, not hypothetical third parties

The clearskies-api exists to serve the clearskies-dashboard. Don't add fields or endpoints justified by speculative future consumers (Home Assistant, mobile apps, third-party tools). Don't bloat the api for use cases nobody has asked for.

**Why:** On 2026-05-05, during the OpenAPI inventory review, Claude proposed server-side parsing of NOAA report text on the rationale that "future consumers like HA or mobile might use the structured shape." User verbatim: "This API is written by us for us. I doubt other users are going to use our API as it is not officially a part of the weewx product. … I do not think it is a good idea to bloat the API."

**How to apply:**

- Every endpoint and field justifies itself by what the dashboard needs. If the only justification is "a future external consumer might want this," cut it.
- Phase-6+ extensibility may be left room for, but don't pay for it now in the v0.1 contract.
- Drift between api and dashboard is a real cost; drift between api and a hypothetical mobile app is not.

## Research what an external system provides before asking the user

If a question depends on what an external system already produces (weewx, a provider API, a library), check that system's documentation BEFORE raising the question. Don't ask the user to invent details that a doc already settles.

**Why:** On 2026-05-05 Claude asked the user whether the api or the dashboard should parse NOAA reports without first checking what weewx actually outputs. User verbatim: "HAVE YOU EVEN READ THE WEEWX DOCUMENTATION TO FIGURE OUT WHAT IT ALREADY PROVIDES?" Same session: Claude proposed an `EarthquakeRecord` shape without first researching what the four earthquake providers return. User: "you need to read the documentation for the earthquake data providers to see what the fuck they even provide."

**How to apply:**

- Before asking "what shape should X be?", read the relevant docs/specs/research and propose a shape based on what the source system actually offers.
- Local weewx 5.3 docs are at [docs/reference/weewx-5.3/](../docs/reference/weewx-5.3/) — use them.
- Per-provider API docs we've captured are at [docs/reference/api-docs/](../docs/reference/api-docs/) — read first. If a provider isn't there, web-research and write findings to a new `<topic>-RESEARCH.md` per "Research before recommending."
- Surfacing a question without this research is a process failure — name it as such if you catch yourself doing it.

## Don't hold things across turns

Whenever you find yourself building up information across turns — comparison tables, decision points, open questions — write it to a file. Examples:

- Comparing 6 forecast providers across 8 dimensions → that table goes in `docs/reference/FORECAST-PROVIDER-RESEARCH.md` as you build it, not held in your reply text.
- Noting open decisions "to come back to" → add them as Pinned rows in [INDEX.md](../docs/decisions/INDEX.md).
- Findings from a Belchertown source audit → save to `docs/reference/BELCHERTOWN-AUDIT.md` so we don't have to re-grep.

The cost of writing a file is negligible. The cost of losing context mid-session is high.

## Dev/test runs in `weather-dev` LXD container, not on the Windows workstation

Clear Skies dev and test work — `docker compose`, `pytest`, `npm`, `vite`, `playwright`, `axe-core`, the seed loader, the SPA dev server, integration tests against MariaDB or SQLite — runs **inside the `weather-dev` LXD container on ratbert**. The Windows workstation (DILBERT) is for editing, git, planning, and orchestration only.

**Why:** The Windows host is a misfit for the entire downstream stack — Docker Desktop is heavyweight and unreliable, Linux containers don't run natively, Playwright browser deps are Linux-first, weewx + MariaDB integration testing wants a real systemd-style environment. Smoke-testing on bare-Python-on-Windows (as happened on 2026-05-04 during the Phase 1 dev/test stack scaffolding) is the wrong shape — it validates the loader code path but tells you nothing about the Docker-compose path, the MariaDB dialect path, or anything tied to a Linux runtime.

**How to apply:**

- When a Phase 1+ task involves *running* code (compose up, npm run, pytest, vite, the seed loader), shell into the container: `ssh ratbert "lxc exec weather-dev -- bash -lc '<command>'"`. Do not propose a plan that runs those commands on the Windows host.
- **File sync DILBERT → weather-dev:** DILBERT pushes to GitHub; weather-dev has its own clones of the five repos at `/home/ubuntu/repos/<name>`. After pushing, fire [`scripts/sync-to-weather-dev.sh`](../scripts/sync-to-weather-dev.sh) from DILBERT (via git-bash or the Bash tool) to `git pull --ff-only` inside the container. The script ssh-hops to the LXD host then `lxc exec ... sudo -u ubuntu` for the pull (running as `ubuntu` matches the directory ownership and avoids git's "dubious ownership" guard). No bind-mount, no webhook auto-sync — those were considered and ruled out (bind-mount adds Windows/Linux complications; webhook needs an inbound endpoint on a host that isn't publicly exposed).
- Browser-side testing reaches the container via its LAN-routable IP (`192.168.2.113` on br-vlan2). DILBERT browser hits `http://192.168.2.113:<port>` directly; no SSH tunnels needed for normal dev iteration.
- Acceptable Windows-side activities: editing files, reading/writing this repo, running `git`, planning conversations, ADR drafting, doc work.
- Anti-pattern: installing the project's runtime deps (`pip install sqlalchemy`, `npm install`, `docker desktop`) on DILBERT to "make it work locally." Don't. The container is the local.

## `.claude/` and workstation orchestration stay private

The `.claude/` directory (agent definitions, settings, MCP config) is gitignored intentionally and is not part of the project's public surface. Do not propose tracking it, moving agent definitions to a tracked location, exposing the multi-agent orchestration setup in public repos, or otherwise treating it as shared project state. How Shane structures the work on his workstation is his business — the public artifact is the code, the ADRs, the contracts, and the docs.

## Poll background teammates at every user-prompt boundary

Background sub-agents spawned via the `Agent` tool with `run_in_background: true` in
agent-teams mode (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) hit a known harness bug:
the inbox-polling loop only activates between tool-call boundaries, so an agent
that finishes its work and enters an idle state will sit silent for 30+ minutes
before submitting its closeout. The completion notification path is also
unreliable on Windows. See `anthropics/claude-code` issues #24108, #26426, #21048
(closed without fix, locked), and our own filing #56930.

**The lead's job is to poll, not to wait.** The lever that wakes a stuck agent
is `SendMessage` — delivered on the agent's next tool-call boundary,
non-disruptive during active work, and a wake mechanism during idle. The lead's
cadence problem is *when* to send those pings.

**The cadence trigger is every user-prompt boundary, not a runtime timer.** Every
time the user sends a message that resumes the lead — even a one-line "how's it
going" — the lead does, before answering whatever the user actually asked:

1. `git log -20 origin/<branch>` on the relevant repo to see if teammates are
   committing.
2. `SendMessage` to any teammate whose last commit is older than ~4 minutes AND
   who hasn't submitted a closeout. The ping is one paragraph: "lead status
   check; submit closeout now if pytest is green; flag any blocker."
3. One sentence to the user about what teammates are doing.
4. Resume whatever the user asked.

**Why the cadence is NOT timer-paced:** `ScheduleWakeup` with the
`<<autonomous-loop-dynamic>>` sentinel does NOT reliably wake the lead outside
an active `/loop` session, despite the tool's docstring claim that the runtime
resolves the sentinel to a no-op tick. **Verified 2026-05-07** during 3b round
2: lead scheduled a 240s wake; the wake did not visibly fire; lead sat silent
until the user prompted ("Why did 18:47 roll by and you did nothing?"). An
earlier same-day session's attempt to apply this rule was based on the
sentinel's docstring claim without empirical verification — the "project rule
trumps tool docstring" framing was 1-empirical-trial wrong. `ScheduleWakeup` is
acceptable as a *hope* signal — schedule it and hope it fires, but never *rely*
on it as the cadence keeper. The user's natural cadence of asking "how's it
going" is the verified trigger.

**Why the original idle-bug filing matters (2026-05-07):** Phase 2 task 3a-2
had three consecutive sub-agents hit this bug — api-dev round 1 (~30 min idle
gap), test-author (~48 min idle gap), api-dev round 2 (overnight gap until
pings woke it). Several hours of wasted wall-clock time. The auditor (Opus,
source-only review with no commits as final action) ran 4 minutes with no idle
gap — the bug strikes when the last action is something other than the
closeout report. Filed
[#56930](https://github.com/anthropics/claude-code/issues/56930) with timing
evidence. The polling rule exists to short-circuit the idle gap; the user is
the only verified cadence trigger we have for it.

**How to apply:**

- Spawn a background teammate → at every user-prompt boundary thereafter,
  check `git log -20 origin/<branch>` + `SendMessage` the teammate if silent
  for >~4 minutes since their last commit AND no closeout submitted.
- After ~3 silent user-prompt cycles without teammate response, the agent is
  likely dead-not-idle (per `anthropics/claude-code` #29271). `TaskStop` and
  reconstruct the closeout from `git log` + commit messages. Diff stats and
  commit-message bodies are authoritative; agent-self-reported test counts
  can be verified by re-running pytest on `weather-dev` directly.
- Don't put "submit IMMEDIATELY, do not idle" instructions in briefs — they
  don't work. The polling loop isn't active during the idle state, so no
  prompt language can trigger earlier submission.
- If the user is afk for hours, the lead will genuinely sit silent until the
  user returns. This is a known limitation, not a workaround we have at the
  rule layer. Surface the limitation honestly when the user asks why nothing
  happened — don't blame a tool.
- This rule applies to the agent-teams in-process mode (Windows-required).
  The TUI/tmux split-pane mode is documented as broken at #24108 and is not
  in use on this project.

## Verify the default branch name before writing it into a round brief

When a brief carries shell instructions like `git fetch origin master` or
`git merge --ff-only origin/master`, verify the target repo's actual default
branch name first. A typo (`master` vs `main`) is silently survivable — the dev
figures it out and corrects locally — but it costs the parallel test-author idle
time while they retry the wrong command.

**Why (2026-05-07):** Phase 2 task 3a-1's brief was carried forward to 3a-2 with
its `master` references intact, but the api repo's actual default branch is
`main`. api-dev round 1 figured it out and silently used `main`; test-author was
slower to recover. The cost surfaced as additional idle gap on top of the
post-completion idle bug. Cheap to verify with `git symbolic-ref refs/remotes/
origin/HEAD` or `gh repo view <owner>/<repo> --json defaultBranchRef`.

**How to apply:**

- Before writing a parallel-pull-then-pytest gate into a brief, confirm the
  branch name matches the repo. Cross-repo briefs (e.g. five repos under
  `inguy24/weewx-clearskies-*`) verify each one.
- Brief errors propagate forward when one round's brief is reused as a template
  for the next. Audit the carried-forward parts at brief-draft time, not at
  brief-review time.

## Round briefs land in the project, not in tmp

Operational briefs for a multi-agent round (per-task scope, reading lists, per-endpoint specs, process gates, what-to-flag-as-STOP triggers) live at `docs/planning/briefs/<phase-task>-brief.md`. Do not put them in `c:\tmp\`, `tmp/`, or other ephemeral locations — briefs are useful when launching the next round (3a-2 reuses 3a-1's pattern; 3b-alerts will reuse 3b's; etc.) and to track which gates the lead set per round. Markdown links in chat should resolve under the project workspace; tmp paths break the link rendering.

## Live scratchpad during multi-agent rounds

During any multi-agent round (lead + dev/test sub-agents in `agent-teams` mode), the lead maintains a **live scratchpad** at `c:\tmp\<phase-task>-scratch.md`. The scratchpad is appended to continuously — after every commit landed, every lead-call decision, every audit finding, every state change — NOT reconstructed retroactively at session-end.

**Why (2026-05-07):** Phase 2 task 3b round 3 hit a session-limit warning mid-round with two background teammates active. The lead's first attempt at handoff was a retrospective `phase-2-task-3b-3-handoff-mid-round.md` written from `git log` + kill-state strings — a snapshot reconstructed from external signals. User pushback was immediate: *"Why are we losing information? Why are you not dumping to a scratchpad to pick up later?"* The retrospective approach loses everything held only in head — running audit considerations, negotiation history, lookup-table reasoning, alternatives rejected, the fact that "fixture-scope drift" was an open audit thread before TaskStop. The corrected pattern (a live `c:\tmp\3b-3-scratch.md` updated continuously across the session) survived the next-session resume cleanly: every commit's concerns, every lead-call, every verification item, every queued lessons-triage candidate was readable in one place.

**How to apply:**

- At the start of any multi-agent round, create `c:\tmp\<phase-task>-scratch.md`. Tmp location is intentional — fast/ephemeral, doesn't pollute `docs/planning/briefs/`.
- Append to it continuously — commit-landed events, lead-call decisions, audit findings, negotiation thread state, queued lessons. Don't batch updates.
- Round-close: triage the scratchpad's queued lessons per CLAUDE.md "Capture lessons in the right place" routing rules. Scratchpad itself stays in `c:\tmp\` as a reference artifact; not committed.
- The scratchpad is the lead's running notes. The brief at `docs/planning/briefs/` stays authoritative for round scope and gates; the scratchpad records *what happened during execution* as it happens.
- Operationalizes the existing "Don't hold things across turns" rule for multi-agent rounds: that rule says "write things that span turns to a file" — the scratchpad is the file for round-execution state.
- This rule applies regardless of whether a session ends mid-round. The pattern's value isn't only mid-round-handoff; it's also the audit trail for the round-close commit and lessons triage.

## Lead-direct remediation when the surface is small

When auditor findings or test-author bugs are mechanical and small (≲50 lines across ≲3 files, no judgment calls beyond what the lead can synthesize), the lead fixes them directly rather than spawning the responsible teammate. Spawning costs ~30-60 min wall-clock plus a respawn-context overhead; lead-direct fixes are minutes. Reserve teammate-spawn for fixes that need real implementation judgment, larger scope, or repeated iteration.

**Why (2026-05-07):**

- Phase 2 task 3b round 2 had four auditor findings (F1-F4), all under ~30 lines apiece. The lead fixed them directly in commit `521f5e1` rather than spawn api-dev for a 4-finding remediation round. No quality regression; round-close was faster.
- Phase 2 task 3b round 3 surfaced three test-author bugs at first pytest (cache-not-wired, fakeredis-kwarg, station-info-missing), one off-by-one date assertion, one Redis-flushdb miss, and six auditor findings. The lead fixed all of them lead-direct (commits `c49ed12`, `ca6f099`, `976286a`, `98ec7dc`) — total ~250 lines across 5 files, would have been a full respawn round otherwise. Spawning would have lost ~2 hours plus the brief-writing overhead for a remediation that took ~30 min lead-direct.

**How to apply:**

- **Lead-direct candidates:** mechanical narrowings (bare-except → specific-class), trivial assertion fixes (off-by-one constants, copy-paste typos), test-fixture wiring that needs a one-helper-add, structural exception-attribute extensions (F2 round 3 pattern: add a kwarg, propagate at the boundary, dispatch on the attribute), short docstring/comment additions documenting deviations.
- **Spawn the teammate when:** the fix needs design judgment (which option to pick from a non-obvious set), spans a larger module surface (>~50 lines or >~3 files), requires iteration against pytest output to converge, OR represents a real new capability (not a fix). Spawn also when the lead would be exercising the dev/test-author/auditor agent's specific knowledge that the lead doesn't have (rare).
- **Document provenance:** lead-direct commits use `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` (or the Sonnet trailer if the lead is Sonnet). Mention the lead-direct precedent in the commit body for posterity.
- **Anti-pattern:** spawning a teammate for a 5-line fix because "the rule says dev fixes dev bugs." The rule is "dev produces code; teammates implement; auditor reviews"; when the post-audit fix is 5 mechanical lines, the lead executing that fix is *part of synthesis*, not a delegation skip.

## Canonical-spec operationalization is a brief-draft question, not an impl call

When a canonical contract (`canonical-data-model.md`, `openapi-v1.yaml`) names a field as "first line of [X]" or otherwise leaves a parser definition implicit, surface the operationalization to the user at brief-draft time. Don't ship the brief letting api-dev silently pick a parser definition; that's a covert canonical amendment dressed as an impl detail.

**Why (2026-05-07):** Phase 2 task 3b round 3 audit F1 caught a brief-vs-canonical drift on `ForecastDiscussion.headline` and `senderName`. Canonical §4.1.4 says "headline = `productText` first line" — but real NWS AFD productText starts with a wire-format header (`000\n FXUS66 KSEW DDDDZZ\n AFDSEW\n`), so "first line" is operationally ambiguous. api-dev picked `headline = wmoCollectiveId` ("FXUS66" — a different field entirely), which the auditor caught. The brief was silent on the operationalization; api-dev shouldn't have made the call unilaterally, but neither should the brief have left it to api-dev. Same drift class as 3b-2 F2 (impl-vs-canonical without lead approval) — but the new lesson is that the brief had a chance to catch it earlier.

**How to apply:**

- At brief-draft time, audit each canonical reference for parser-definition ambiguity. "First line of `productText`" — first non-blank? after a header skip? what counts as a header? Pin the answer in the brief OR surface as a real open question for user sign-off.
- Same applies to "extract from URL," "compose from fields X and Y," "abbreviate," "first sentence of," "next non-empty," and any other content-shaping verb in the canonical-mapping table.
- Cross-check the brief against the canonical's example output, not just the formula. Canonical §4.1.4 says `senderName = wmoCollectiveId + issuingOffice (e.g. "NWS Seattle WA")` — the formula and the example disagree. That's the brief's signal to surface; impl shouldn't reconcile silently.

## Cross-check canonical mapping cells against api-docs example responses at brief-draft

When a round brief cites a canonical-data-model.md mapping table (`§4.x` provider columns) as the source of truth for a wire-shape field, **cross-check each cell against the corresponding api-docs example response** in `docs/reference/api-docs/<provider>.md` BEFORE drafting the brief. If the api-docs example contradicts the canonical mapping cell, that's a canonical-table bug — surface it to the user at brief-draft time. Do not draft the brief on top of canonical text the api-docs already disagrees with.

This rule operationalizes one layer above "Canonical-spec operationalization is a brief-draft question" — that rule covers parser-definition ambiguity *within* a canonical mapping (e.g., "first line of X"). This rule covers cross-validation *of* the canonical mapping cells against external evidence captured in api-docs files.

**Why (2026-05-09):** Phase 2 task 3b-7 (alerts/aeris) was drafted against canonical-data-model §4.3 verbatim. §4.3 mapped Aeris severity from `details.priority` integer (1-5 → enum). The api-docs file at `docs/reference/api-docs/aeris.md` line 249 already showed `priority: 60` in its example response — inconsistent with the 1-5 scale. A cross-check at brief-draft time would have caught the mismatch before fixture capture. Instead, the contradiction surfaced only when test-author captured the real Aeris fixture (priority=96 for a Fire Weather Watch); the lead then had to web-research the actual Aeris severity model (suffix on `details.type`, not `priority`), amend canonical §4.3, rewrite the impl + tests (~310 lines, mid-flight). Three further mismatches surfaced in the same fixture: `details.urgency` / `details.certainty` / `details.category` were not Aeris response fields at all (PARTIAL-DOMAIN), and the actual category field is named `details.cat` (not `details.category`). All five mismatches were visible in the api-docs file or the published Aeris docs at brief-draft time.

**How to apply:**

- For every canonical-mapping cell the brief references, open `docs/reference/api-docs/<provider>.md` and find the example response. Trace the wire field path; verify the canonical mapping points at it correctly.
- If the api-docs example doesn't show a field the canonical mapping names, that's a yellow flag — either the example is truncated (mark uncertain in brief) or the field doesn't exist in real responses (PARTIAL-DOMAIN candidate, surface to user).
- If the api-docs example shows a field shape inconsistent with the canonical mapping (different value range, different field name, different type), that's a canonical-table bug — STOP and surface to user before brief-draft continues.
- For provider docs not yet captured in `docs/reference/api-docs/`, fetch them via web research and write a `<provider>.md` BEFORE drafting the brief, per the existing "Research what an external system provides before asking the user" rule.
- The cross-check is brief-draft work, not audit-time work. Catching it at audit time means the impl already shipped against the wrong contract; remediation is a mid-flight rewrite, not a small audit fix.
- Anti-pattern: drafting calls 12-19 of a brief by reading canonical §4.3 alone, without ever opening the provider's api-docs file. The 3b-7 brief's Section "Operationalization audit checklist" walked through every canonical field but only against the canonical text, not against the wire-shape evidence.

## Multi-line commit messages on PowerShell: use `git commit -F` with a written file

PowerShell's parser breaks multi-line `git commit -m "$msg"` invocations when the message contains parentheses, quote marks, or shell-special characters — the parser interprets them as positional arguments to git, producing `error: pathspec 'X' did not match any file(s) known to git` and ALSO leaves a partial commit half-formed. Use `git commit -F <file>` with a written `.txt` file in `c:\tmp\` instead.

**Why (2026-05-08):** during Phase 2 task 3b round 3 remediation, a here-string commit message containing parentheses (`(F1 HIGH, F2 MED, F3-F6 LOW)`) and quoted strings ((`"NWS Seattle WA"`) broke the PowerShell heredoc parsing. Git emitted ~30 `pathspec ... did not match` errors. Workaround: write the commit message to `c:\tmp\<task>-msg.txt`, run `git commit -s -F c:\tmp\<task>-msg.txt`. Cost was a confused round of error messages and a re-stage.

**How to apply:**

- For any non-trivial commit message (>~5 lines, contains parens/quotes/backticks/dollar signs), write the message to `c:\tmp\<phase-task>-msg.txt` first via the Write tool, then `git commit -s -F c:\tmp\<phase-task>-msg.txt`.
- Trivial commits (one-liner messages with no special chars) can still use `-m "msg"` inline.
- This is a Windows/PowerShell-specific concern. Bash (via Git Bash or WSL) handles heredocs cleanly — if a command path goes through Bash, `-m "$(cat <<EOF ... EOF)"` works as documented. The two pipelines coexist; pick the one that matches your current shell.

## No "promotion candidates" or "we'll add it later" framing in v0.1 contracts

Clear Skies positions clearskies-api as a full Belchertown replacement that surfaces every weewx capability. v0.1 contracts (OpenAPI, canonical-data-model) must therefore enumerate the full stock weewx surface as first-class — no "promotion candidates" bucket, no "currently routes through `extras` until OpenAPI is bumped" notes, no "we'll add it later" framing. `extras` carries operator-custom columns only. Stock weewx columns are first-class on the canonical entity.

**Why (2026-05-06):** Phase 1's OpenAPI Observation schema listed only 21 fields and bucketed `appTemp`, `cloudbase`, `lightning_*`, `extraTemp*`, `soilTemp*`, etc. into a "promotion candidates routed through `extras`" framing. clearskies-api 3a-1 round 2 surfaced this as a real gap — operators with those columns would see them disappear from the API. User direction: *"We are not going to release anything half-baked. This needs to be a full replacement for Belchertown and not hiding Weewx capabilities."* The contract was expanded to 69 first-class fields covering the full `STOCK_COLUMN_MAP` set.

**How to apply:**

- For any v0.1 contract that maps weewx (or any source-system) entities to canonical entities, the lead drafts the contract against the FULL source-system surface, not a curated subset. If the surface is large, document it exhaustively in the catalog (canonical-data-model.md style); don't shortlist "first-class" vs "promotion candidate."
- The `extras` bag is for OPERATOR-EXTENSION columns (per ADR-035 mapping flow), not stock-but-unpromoted ones. Stock columns the operator's archive doesn't include surface as `null` on the canonical entity, NOT in `extras`. JSON keys are always present.
- Anchoring constants like `_FIRST_CLASS_FIELDS` to a single source of truth (e.g., `STOCK_COLUMN_MAP` from the column registry) prevents drift between contract and impl. Hand-maintained "first-class subsets" of a larger source set rot.
- This rule applies at v0.1. Post-1.0 additions (e.g., a future weewx version adds new stock columns) follow the same principle: get them into the contract on the next minor bump, not into `extras` indefinitely.

## Brief questions audit themselves before draft

When drafting a round brief, audit each "open question" against the relevant ADRs and contracts BEFORE surfacing it to the user. Drop questions the ADR or contract already settles. Don't propose ADR deviations as questions — that's a covert ADR amendment dressed as a routing call.

**Why (2026-05-07):** the 3b round 1 alerts brief surfaced ten "lead's proposed calls" for user sign-off. Audit on user pushback found that seven of the ten were already locked: Q2 (api.conf section shape) was prescribed by ADR-027's example file at line 162-173; Q3 (capability registry mechanism) was settled by ADR-038 §3 + the existing `wire_*` patterns from 3a-1/3a-2; Q5 (rate-limiter primitive) is named in ADR-038 §3's shared-infrastructure bullet; Q10 (no live-network tests in CI) is locked by ADR-038 §Testing pattern. Q4 was worse — it proposed deferring the Redis cache backend to a later round, which directly contradicts ADR-017 §Decision + §Consequences ("Phase 2 work: cache abstraction interface + **two backend implementations (memory, redis)**"). That's not an open question; it's a covert ADR amendment that should have triggered the "ADR conflicts → STOP" rule at brief-draft time. User direction: *"why are some of these questions even questions when the ADR already answers them?"* The padding pattern is the same anti-pattern as in audit findings — manufacturing concerns to look thorough — applied at brief-draft time instead of audit time.

**How to apply:**

- For each "open question" you draft, name the ADR or contract that would settle it. If found, drop the question or convert it to a one-sentence "per ADR-NNN, X" lead-call without sign-off (no ceremony).
- If an "open question" proposes doing less than an ADR mandates, that's a deviation, not a question. Surface it with the explicit framing: "I'm proposing to deviate from ADR-NNN, which says X. Options: (1) honour the ADR, (2) edit the ADR (status flips back to Proposed, you re-approve)." Per the existing "ADRs are authoritative. STOP at first conflict" rule.
- Genuine open questions are facts not pinned by ADR or contract — implementation-detail-with-real-tradeoffs. Three or four real ones beat ten with seven fakes. The "Audit means real findings, not contrarianism" rule applies at brief-draft time, not just audit time.
- Lead-calls (trivial implementation details where the answer is obvious — e.g., `?point=` vs two-step `?zone=`) go inline as "lead-resolved" notes, not numbered questions. Don't seek sign-off on calls the user shouldn't have to think about.
- **Verify codebase state at brief-draft time, especially when prescribing file paths, helper function names, settings section paths, or anti-patterns about module structure.** Brief-bugs in 3b-10 (separately surfaced by api-dev mid-round, not caught at brief-draft): LC18/LC19 claimed credentials at `settings.aeris.client_id` — that path didn't exist; the actual path is `settings.forecast.aeris_client_id` per 3b-4 Q1 provider-scoping. Brief anti-pattern told the dev NOT to extend `providers/_common/datetime_utils.py` with an inline helper — but a near-identical helper (`to_utc_iso8601_from_offset`) had already been pulled up there in commit `0f2fe01` (3b-5), so api-dev correctly reused it per DRY. Both forced api-dev to identify the divergence and document a workaround in commit bodies. The lead's edit-and-grep cycle at brief-draft adds ~5 minutes; api-dev's mid-flight divergence handling costs ~30 minutes plus lead-clarification friction. When the brief cites a code path, helper, or anti-pattern about file structure: open the cited file and confirm the structure matches the claim before locking the brief.
    - **When the brief cites a numerical conversion function (units, scaling, currency, time-base, AQI breakpoint), perform a dimensional sanity check at draft time, not just a structural one.** Structural verification ("the function exists, takes these args, returns float") doesn't catch a unit/dimension bug — the function can exist and return a number that's 1000× the value the canonical contract expects. Pick one well-known reference point in the function's intended unit and trace it through the function in your head: does the output land where it should? **Why (2026-05-11):** 3b-11 surfaced an off-by-1000 chemistry bug in `providers/aqi/_units.ugm3_to_ppm()` dating back to 3b-9. The formula `µg/m³ × 24.45 / MW` produces ppb, not ppm — off by a factor of 1000. The bug had been encoded into 3b-9 and 3b-10 Open-Meteo tests, the 3b-11 brief, the new 3b-11 EPA breakpoint table, the test-author's 3b-11 real-capture fixture sidecar expected values, and canonical-data-model.md §4.2's footnote — six layers of agreement on the wrong formula. The 3b-11 brief's codebase-state-verification step opened `_units.py` and confirmed the function existed (structural) but didn't sanity-check that "1 ppm CO ≈ 1146 µg/m³ → `ugm3_to_ppm(1146, 'CO')` should be ≈ 1.0" (dimensional). A 30-second mental check at brief-draft would have caught the bug before the round opened; instead, the OWM real-fixture surfaced it mid-round (Seattle CO=139.79 µg/m³ → AQI 500 "Hazardous" for a perfectly clean afternoon), forcing a 200-line cross-repo remediation. The brief assertion "verified pattern" without numerical verification is the brief-bug class. **How to apply:** for any LC that cites a conversion function or chemistry/math operation, name one reference data point in the docstring/brief — e.g. "verified ugm3_to_ppm(1146, 'CO') ≈ 1.0 ppm". Trust-but-verify the math, not just the file.

## Provider CAPABILITY declares paid-tier maximum supply set; runtime population is conditional

For keyed and tiered providers (Aeris, OpenWeatherMap, Wunderground, and any future provider whose data surface depends on plan tier), `CAPABILITY.supplied_canonical_fields` declares the **paid-tier maximum** supply set — every canonical field the provider *can* deliver on its richest plan. Runtime bundle population is **conditional** on what the actual response carries; free-tier deployments will see `None` for fields the paid tier supplies but the free tier omits.

**Why (2026-05-08):** Phase 2 task 3b-4 added Aeris as the first keyed forecast provider. The lead initially proposed `discussion=None always for v0.1` (matching Open-Meteo / OWM-free / Wunderground) on the grounds that paid-tier `summary` field availability is conditional, and CAPABILITY should reflect what's actually delivered. The user overrode (Q2): CAPABILITY declares max-surface so paid-tier deployments surface discussion content when available, free-tier deployments see `discussion=null`. The auditor's F3 then caught three more fields — `sunrise`, `sunset`, `windGustMax` — with the same shape (free-tier captures show them always None). User widened the Q2 acceptance to cover those too. The pattern that emerged: **CAPABILITY is a contract about what the provider's *richest* plan can deliver**, not a pinky-promise about what every operator will see. The dashboard reads CAPABILITY to know which UI panels exist; the bundle reflects the actual response. Two consumers, two contracts.

**How to apply:**

- For any keyed/tiered provider's CAPABILITY declaration, enumerate `supplied_canonical_fields` against the **paid-tier maximum** documented surface, not the free-tier subset.
- Document the tier-conditional fields in the provider module's `operator_notes` (e.g., "Forecast discussion populated when paid-tier summary field is present; free-tier returns bundle.discussion=null").
- Tests cover BOTH paths: the with-paid-tier-field path and the without-it path. Per the test-author's synthetic-from-free fixture pattern when paid-tier access isn't available, hand-craft a fixture variant that injects the paid-tier field (sidecar marks it synthetic).
- Auditors flagging this pattern as ADR-038 static-CAPABILITY drift get the lead's response: "user-accepted trade-off, see brief Q2." Don't re-litigate.
- The pattern does NOT extend to keyless providers (Open-Meteo) — there's no tier conditional, so CAPABILITY matches every operator's reality. Keyless providers stay strict static-CAPABILITY.
- The pattern does NOT extend to canonical fields the provider categorically does not supply (e.g., Wunderground PWS has no hourly forecast on any plan — `validTime`/hourly fields stay out of CAPABILITY for Wunderground regardless of tier).
