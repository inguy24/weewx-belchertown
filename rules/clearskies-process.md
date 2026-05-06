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

## Plain English when explaining decisions to the user

When walking the user through an architectural decision, write so they can read it without translation. Spell out what jargon means in the same sentence; don't string technical-sounding language together as a substitute for actually communicating.

**Why:** On 2026-05-05, during the OpenAPI inventory review, Claude produced "paragraph upon paragraph of utter techno-babble" using unexplained terms like "entity," "envelope," "RFC 9457," "AsyncAPI." The user verbatim: "using the english language is not your strong suit is it. … None of this means shit to me."

**How to apply:**

- When raising a question, state plainly what you're asking and why — don't bury it inside an audit-finding bullet list.
- When using a technical term that isn't already in the user's working vocabulary, define it in the same sentence.
- If you find yourself writing "I want your judgment on …" followed by six numbered tradeoff bullets, you're doing it wrong. State the recommendation; ask if they agree.
- Audit findings still belong in the response — but written so the user can read them, not as a wall of jargon.

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
