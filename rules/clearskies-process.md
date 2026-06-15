# clearskies-process.md — Clear Skies project process rules

Load when working on Clear Skies (`weewx-clearskies-*` repos, planning docs, ADRs, contracts).
Incident history and rationale at [reference/process-rule-history.md](../reference/process-rule-history.md).

---

## Architecture document discipline

**Read `docs/ARCHITECTURE.md` before any architecture work.** Before proposing, discussing, or implementing any infrastructure change, deployment fix, proxy configuration, service placement, container change, endpoint change, or config-file change: read `docs/ARCHITECTURE.md` first. This is the single source of truth for what each service is, where it runs, what it exposes, and how traffic flows. Do not re-derive the architecture from ADRs, observation, or memory.

**Update `docs/ARCHITECTURE.md` after any architecture change.** Every change to services, containers, endpoints, routing, config files, or topology must be reflected in the architecture document before the task is considered complete. If the change reveals a gap between intended and current state, update the "Known gaps" section.

**Why (2026-05-23):** Without this document, the lead spent an entire session re-deriving architecture that was already decided in ADRs — going in circles proposing the wizard as a standalone Flask app, then suggesting it be split across containers, then suggesting it be rebuilt in React in the dashboard, then suggesting it be bundled into the API container. All four proposals contradicted existing ADRs. The root cause: 40 ADRs cannot serve as a quick-reference for "how does the system work right now." A single architecture document eliminates the re-derivation loop.

## ADR discipline

**Write decisions to disk immediately.** Decision discussed → ADR drafted as `Proposed` → user reviews full content → user explicitly approves → status becomes `Accepted`. Never create ADRs as Accepted. "It was in the plan" is not sign-off. Directional chat ("yes use the prefix") is input to a Proposed ADR, not approval.

**Corrections edit in place.** Status flips back to Proposed until user re-approves. Don't create a new "supersedes" ADR for ordinary corrections — only for fundamentally distinct decisions.

**Read the ADR before the plan.** Plan body summaries drift. ADR wins on conflict — fix the plan to match.

**Read the ADRs before touching architecture.** Before proposing any infrastructure change, deployment fix, proxy configuration, service placement, or config-file change: read `docs/ARCHITECTURE.md` first (see above), then the relevant ADRs if deeper decision context is needed (especially ADR-034 deployment topology, ADR-027 config wizard, ADR-038 wizard-to-API channel). Do NOT guess the architecture from observation alone — the live state may be broken or interim. The ADRs define what the system SHOULD look like; divergence means a bug to fix, not a new architecture to invent. Session context or resume prompts may be stale or wrong; ADRs are authoritative.

**Why (2026-05-22):** Phase 5 session wasted significant time patching a wrong architecture: running the API on weather-dev (not the weewx host), adding Apache ProxyPass rules between the dashboard and API, manually writing `api.conf` on the wrong host, and proposing the wizard write `api.conf` locally. All of these contradicted ADR-034 (API co-locates with weewx), ADR-038 (API writes its own config via `/setup/apply`), and ADR-027 (wizard auto-detects topology). None of the ADRs were read until the user intervened. The ADRs had all the answers; the session burned tokens and user patience reinventing them badly.

**Recover lost state immediately.** If the user references a decision you can't find in files: STOP. Tell them. Ask for context. Write it down before the next item.

## ADR content standards

Use the Nygard format. Template at `docs/decisions/_TEMPLATE.md`. Required: Status, Context, Options considered, Decision, Consequences, Implementation guidance, References.

**Concise, not padded.** ~80 lines standard, ~150 for parent-pattern ADRs. Cut: historical recaps, multi-paragraph option analysis, implementation mockups, trade-off prose restating the obvious. Keep: the decision in 1-2 sentences, one-line verdicts per option, concrete consequences, out-of-scope items.

**Status workflow:** Proposed → Accepted → (rarely) Superseded by ADR-NNN. Pinned = placeholder.

## Research rules

**Research external systems before asking the user.** Check docs/specs before raising questions the docs already settle. Local weewx 5.3 docs at `docs/reference/weewx-5.3/`. Per-provider API docs at `docs/reference/api-docs/`.

**Don't dismiss user-named options.** Evaluate ALL options the user proposes. Every option gets a row — even if the conclusion is "exclude — reason."

**Scope the API to the dashboard.** Don't add fields/endpoints for hypothetical consumers (HA, mobile). The only justification is "the dashboard needs this."

**Use weewx terminology where possible.** Prefer weewx ecosystem terms (observations, archive, loop packet, station) over industry alternatives.

## Brief-draft quality

**Audit open questions against ADRs before surfacing.** For each "open question" in a brief, check if an ADR/contract already settles it. Drop questions that are already locked. If a question proposes doing less than an ADR mandates, frame it as a deviation explicitly.

**Cross-check canonical mapping cells against api-docs examples.** For every canonical-mapping cell the brief references, open `docs/reference/api-docs/<provider>.md` and trace the wire field path. Mismatches = canonical-table bug → STOP and surface to user. Do this at brief-draft, not audit-time.

**Verify api-docs provenance.** Files without "Captured: YYYY-MM-DD via <live URL>" headers are unverified inputs. Either capture fresh or mark claims as "tentative, verify at fixture-capture time."

**Verify codebase state.** When the brief cites file paths, helper names, settings paths, or anti-patterns: open the file and confirm. When the brief cites a conversion function: do a dimensional sanity check (name one reference data point, trace it through the function mentally).

**Canonical-spec operationalization.** When a canonical contract leaves a parser definition implicit ("first line of X"), surface the operationalization to the user at brief-draft. Don't let api-dev silently pick a parser.

## Execute the FULL request, not the easy parts

**Every item in the user's request is mandatory.** When the user gives a multi-part instruction ("do X and also Y"), plan and execute ALL parts before reporting progress. Do not cherry-pick the easier or more familiar items and defer the rest. If some parts require more research or harder implementation, that's the reason to start them first — not to skip them.

**Never ask the user to prioritize their own requests.** Everything the user asks for is mandatory — do not ask "which is most blocking?" or "which should we tackle first?" Just do all of them. If they can be parallelized, parallelize. If they must be sequential, start immediately. The user's time is wasted when they have to re-assert that their requests are requirements.

**Why (2026-05-27):** User reported three issues (seismic map sizing, logo upload, earthquake wizard config). The lead asked "which is most blocking?" instead of working all three in parallel. The user had to correct this — every item they raise is mandatory, not optional.

**Plan all parts together before executing any.** When a request has additions AND removals, new features AND fixes, research AND implementation — design one coordinated plan that covers everything. Executing half the request and then asking "what about the other half?" wastes tokens and user patience.

**Why (2026-05-26):** User asked to (1) analyze Belchertown records and carry them over to Clear Skies, and (2) eliminate inside-temp and custom records. The lead spent multiple agent cycles researching and executing only the removals while completely ignoring the additions — the primary ask. The user had to remind the lead twice. Tokens were burned on research that was never acted on.

## Agent orchestration

**Lead = Opus, orchestration + judgment only.** Teammates = Sonnet. The lead does NOT write code, run tests, do code reviews, or fill in templates. Those are delegated tasks. Lead's job: break down work, write focused prompts, spawn agents, monitor, QC output, make judgment calls, commit.

**Sonnet for ALL delegated work.** Implementation, tests, audits, verification, closeout extraction. Opus auditor is not worth the cost — Sonnet auditor validated at 75K tokens with clean results (3b-15 close).

**Lead reads and researches what it needs to understand — delegate what it doesn't need to personally comprehend.** The coordinator cannot coordinate what it doesn't understand. Reading project documents, tracing code paths, running diagnostic commands, checking logs, verifying container state — these are core coordinator activities when they inform judgment calls, agent prompts, QC, or stalemate-breaking. An agent summarizing a file is not the same as the lead understanding it. The lead reads directly when understanding is the point.

**Delegate mechanical and bulk work.** What gets delegated to Sonnet agents: writing code, writing tests, writing documentation drafts, running test suites, performing mechanical audits (grep for banned terms, check file counts), bulk file edits, broad searches across many files, and cataloging tasks. When delegating research, require a detailed brief back (not a one-line summary). The lead uses the brief to make decisions and write prompts.

**When unsure, ask the user.** If the lead isn't sure whether to do research directly or delegate it, ask. Don't guess at the boundary — the user's judgment on cost vs. context quality is what matters.

**Why (2026-06-14, corrected):** The original rule (2026-05-18) said "lead does NOT do research grunt work" and "the only direct tool calls the lead makes are spawning agents." This was never the user's intent. It over-corrected from "lead reads too many files before spawning agents" to "lead delegates ALL reading." The coordinator's value is judgment informed by direct understanding — reading, diagnosing, and verifying are part of the job. The distinction is understanding vs. mechanical bulk work, not "all research" vs. "no research."

**Small, focused tasks.** Each agent gets one specific job with a clear deliverable. "Implement 2 provider modules + tile proxy + wiring" is too big. "Implement openweathermap.py radar provider per this spec" is right. Shorter runs = less idle-bug risk, easier to monitor, cheaper to retry.

**Focused agent prompts.** Each agent receives ONLY the context needed for its specific task. Don't load full rules files, full ADRs, or project history into agent prompts. Extract the relevant section and inline it. The lead carries the full context; agents carry task context.

**Monitor via SendMessage.** After spawning background agents, check git log for commits every 3-4 minutes. If an agent has committed but gone quiet >4 min, SendMessage to wake it. After ~3 silent pings, TaskStop and reconstruct from git. The idle bug (#56930) means agents can finish work and sit silent for 30+ min — polling is the only mitigation.

**Foreground for fast tasks.** If an agent's task takes <2 min (verify git state, extract git stats, run one command), use foreground mode. Background is for tasks >5 min where parallel work is possible.

**Pre-flight repo verification before EVERY agent dispatch.** Before spawning any agent that will modify a repo, the coordinator runs `git status` and `git log --oneline -1` on the target repo. If there are uncommitted changes, unexpected HEAD, or any other surprise — STOP and report to the user. Do not dispatch the agent. Additionally, every agent prompt must include this block:

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

This block is mandatory in every implementation agent prompt. Not optional, not "when relevant." Every single one.

**Why (2026-05-28):** A dev agent was dispatched without pre-flight verification. The remote had 14 unknown commits. The agent pulled, hit conflicts, and merged — all autonomously. The coordinator accepted the merge report and continued building on top of unreviewed code. The user discovered the mess hours later. Pre-flight would have caught the divergence before any agent touched the repo. The git prohibition block would have prevented the agent from pulling even if pre-flight was skipped.

**Independent lead verification of ALL teammate claims.** Before accepting any teammate's work:

1. **Re-run the verification command** from the scope-binding step in a fresh shell on weather-dev. The teammate's self-reported numbers are one data point, not truth.
2. **Spot-check one non-trivial requirement against the code.** Pick one requirement from the brief's scope block, open the file, and confirm it was implemented — not just that tests pass. Tests can pass while requirements are unmet (tests may not cover the requirement).
3. **Compare the commit list against the scope block.** Every file in "Files to create or modify" should have a corresponding commit. Any commit touching a file in "Files NOT to touch" is a scope violation — investigate before accepting.
4. **If the numbers don't match, STOP.** Do not close the round. Triage the delta: pre-existing vs. introduced. Surface to user if introduced failures exist.

**Why (2026-05-11):** 3b-12 api-dev claimed "1762 passed, 0 failed"; lead's independent run returned 103 failed. The lead initially trusted the count and almost closed the round on a false-clean narrative. Additionally, dashboard a11y compliance claims were never independently verified by the lead.

**Lead-direct for small fixes.** When auditor findings or test bugs are mechanical and small (<=50 lines, <=3 files, no judgment calls), the lead fixes directly. Spawning costs 30-60 min; lead-direct is minutes.

## Scope binding before agent dispatch

**Every agent prompt must contain an explicit scope block.** Before the agent writes any code, it must SendMessage the lead with a one-paragraph scope acknowledgment: what it will deliver, what it will NOT touch, and the verification command it will run before closeout. The lead confirms or corrects. No code before the scope ack is confirmed.

**Scope block required contents (in the brief):**

1. **Files to create or modify** — exhaustive list, not "and related files."
2. **Files NOT to touch** — explicit exclusions (e.g., "do not write unit tests; test-author owns those").
3. **Verification command** — the exact pytest/axe-core/build command the agent will run before reporting done, including the working directory and expected pass threshold.
4. **Deliverable definition** — what the lead will see in git log when the agent is done (e.g., "N commits on origin/main implementing X; pytest at <path> showing M pass / 0 fail").

**Why (2026-05-11):** 3b-12 api-dev wrote 850 lines of unit tests in a flat file (test-author's job at the nested location), committed a plan-status-close on the meta repo (lead's job), and claimed "1762 passed, 0 failed" (103 actually failed). A scope block naming "files NOT to touch: tests/" and "deliverable: N commits on api repo only" would have made all three violations detectable at the scope-ack step before any code was written.

## Agent prompt requirements

**Every agent prompt (brief) must contain these sections.** Sections may be brief for simple tasks but cannot be omitted.

1. **Round identity** — round number, date, lead, teammates, auditor.
2. **Scope (in / out)** — per "Scope binding before agent dispatch" above.
3. **Reading list** — ordered list of files to read before coding. Extract relevant sections; do not say "read the full rules file" for a 150-line file when 10 lines are relevant.
4. **Pre-round verification** — what the lead verified before writing the brief (repo HEAD, weather-dev sync state, pytest baseline, cross-check results). This is the lead's evidence that the starting state is clean.
5. **Per-deliverable spec** — for each endpoint/module/component, the behavior decision tree or equivalent. Not "implement the endpoint" — the specific happy path, error paths, edge cases, and response shapes.
6. **Lead calls** — decisions the lead has already made that the agent must follow (not re-derive). Cite the reasoning.
7. **Open questions** — questions the agent must surface to the lead via SendMessage, NOT resolve unilaterally. Every open question must have been audited against ADRs first per the existing "Audit open questions against ADRs before surfacing" rule.

**Prompt anti-patterns (from incidents):**
- "Implement X and related files" — vague scope invites scope creep. Name every file.
- Citing a file path without verifying it exists (3b-10: `settings.aeris.client_id` was wrong).
- Citing a helper function without verifying it does what the brief claims (3b-10: brief said "don't extend datetime_utils.py" but the helper already existed there).
- Citing a numerical formula without a dimensional sanity check (3b-11: off-by-1000 chemistry bug encoded in the brief).

## False-claim protocol

When a teammate's self-reported numbers are proven wrong by the lead's independent verification:

1. **Do not close the round.** The round stays open until the real numbers are established.
2. **Triage the delta.** Categorize each failure as pre-existing (present at the round's baseline commit) or introduced (new in this round's commits). Use checkout-and-rerun against the baseline commit for a representative sample.
3. **Record the real numbers in the scratchpad** with the verification command and commit hash. Strike through the false claim with the actual numbers.
4. **Pre-existing failures** go to the parking lot as a tracked item (not buried in narrative). They do not block the current round's close IF the round introduced zero new failures.
5. **Introduced failures** block the round. Remediate before close.
6. **Do not attribute malice.** Agents hit context limits, misread output, or run against stale state. The protocol exists to catch the error, not to punish it. But the error must be caught — that is non-negotiable.

**Why (2026-05-11):** api-dev claimed "1762 passed, 0 failed"; reality was "1754 passed, 103 failed." 102 were pre-existing; 1 was introduced. The lead initially trusted the claim. The false-claim protocol ensures the lead always establishes ground truth independently before closing.

## Audit rules

**Two audit modes, both required for non-trivial work.** Runtime tests against real backends + source-only review against ADRs/rules. Neither alone is sufficient. Order: dev produces → tests run on weather-dev → auditor reviews diff → lead synthesizes.

**Real findings only.** Every finding cites a specific ADR/rule/RFC and identifies: (a) a specific failure mode, (b) a missed constraint, or (c) forced downstream rework. Generic tradeoffs are not findings. Empty audits are fine.

**Lead synthesizes auditor findings.** Per finding: accept (with specific remediation + reasoning), push back (with reasoning), or defer (with condition). Don't forward raw findings to dev unedited.

**Phase-boundary ADR compliance sweep (mandatory).** Before declaring any phase complete, run the audit in the *other* direction: for each Accepted ADR, verify that every v0.1 implementation requirement has corresponding code, config, or documentation in the repos. The per-round auditor checks the code that *was* written; this sweep catches code that *should have been* written but wasn't. Walk the full ADR index — not just the ADRs the current phase touched. Surface every gap to the user before closing the phase.

**Why (2026-05-19):** Phases 2–4 closed with clean per-round audits, yet a post-Phase-4 sweep found 15+ ADR requirements with zero implementation: the entire configuration UI (ADR-027), internationalization infrastructure (ADR-021), observability/metrics (ADR-031), realtime direct mode (ADR-005), production docker-compose and systemd units (ADR-034), Leaflet maps, NOAA report parser, custom pages, and more. Per-round audits only checked the diff — they never asked "what's missing from the full ADR surface?" The gap went undetected across 4 phases and dozens of audit rounds because nobody ran the reverse check.

**Per-round ADR spot-check (upstream complement to the phase-boundary sweep).** The phase-boundary sweep is the backstop; it should not be the first time anyone checks ADR compliance. At round close, the lead picks the 2–3 ADRs most relevant to the round's work and verifies that the round's implementation satisfies those ADRs' acceptance criteria (see ADR template). This is not a full sweep — it is a spot-check that catches drift before it accumulates across an entire phase. Record the spot-checked ADRs and their pass/fail in the verification evidence block.

**Acceptance-criteria-driven sweep.** When running the phase-boundary sweep, walk each ADR's acceptance criteria checklist (not just the prose). For ADRs that lack acceptance criteria, flag the absence as a finding — the ADR needs updating before the phase can close. An ADR without acceptance criteria is an ADR that cannot be verified.

## Round-close verification gate

**A round is not closed until all four verification steps are complete.** The lead performs these AFTER the auditor submits findings and AFTER lead-direct remediation. The verification is recorded in the scratchpad before the plan-status-close commit.

### Step 1: Brief scope walkthrough

Open the round brief's "Scope (in / out)" section. For each in-scope item, record one of:
- **DONE** — cite the commit hash where it landed.
- **DEFERRED** — cite the parking-lot entry (must exist in the scratchpad or plan; cannot be implicit).
- **MISSING** — STOP. Do not close the round. Remediate or explicitly defer with user approval.

### Step 2: Verification evidence block

Record in the scratchpad:

```
## Verification evidence — round {N}
- pytest command: `ssh weather-dev "cd /path && pytest ..."`
- pytest result: {N passed / M skipped / K failed} at commit {hash}
- auditor findings: {N total — X remediated, Y deferred (cite parking-lot), Z pushed back (cite reasoning)}
- scope walkthrough: {N of N in-scope items DONE, M DEFERRED (cite items), 0 MISSING}
- lead spot-check: {which requirement was spot-checked, what was observed}
- ADR spot-check: {which ADRs checked, pass/fail per acceptance criterion}
```

### Step 3: Deferred-item tracking

Every item marked DEFERRED or placed in a parking lot must appear in one of:
- The plan's task table as a future-round row with a clear description.
- The scratchpad's parking-lot section with a one-line description and the round that created it.

Items buried in narrative prose (decision log, closeout report, mid-scratchpad notes) are NOT tracked. If an item exists only in narrative, promote it to a tracked location before closing the round.

### Step 4: Prompt faithfulness check (when closing a user-initiated task)

When the task originated from a user prompt (not a plan-internal round), walk the original prompt line by line. Every distinct request in the prompt must map to either:
- A deliverable (cite commit or file).
- An explicit deferral (cite where tracked).
- A justified exclusion (cite reasoning communicated to user).

**Why (2026-05-26, 2026-05-27):** (1) User asked for analysis + carry-over + elimination of records. Lead spent multiple cycles on elimination only, ignoring the analysis (primary ask). User had to remind twice. (2) User reported three issues; lead asked "which is most blocking?" instead of working all three. (3) 3b-12's 102 pre-existing test failures were noted in narrative but not tracked as a parking-lot item until the user asked. (4) Phase-boundary sweep found 15+ ADR requirements with zero implementation — per-round audits checked the diff but never asked "did the brief's scope block get fully delivered?"

## Runtime environment

**Dev/test runs in `weather-dev` LXD container, not Windows.** Shell into container: `ssh weather-dev "<command>"`. File sync: push to GitHub from DILBERT, then run `scripts/sync-to-weather-dev.sh`. Browser testing: `http://192.168.2.113:<port>`. DILBERT = editing + git + planning only.

**Single test host.** All services (API, realtime, config UI), the dashboard, and the web server run on `weather-dev`. Do not split services across containers for testing — one host, everything local.

**API startup takes ~2 minutes.** After `systemctl restart weewx-clearskies-api`, the cache warmer makes outbound provider API calls (Aeris, NWS, etc.) before uvicorn binds to port 8765. Any deployment script or verification step that restarts the API must wait at least 120 seconds before hitting endpoints. `sleep 10` will get connection refused.

**Config files NEVER go in the web root.** All configuration files (`api.conf`, `realtime.conf`, `stack.conf`, `secrets.env`, `charts.conf`, `webcam.json`) live in `/etc/weewx-clearskies/`. The web root (`/var/www/clearskies/`) is wiped by `rsync --delete` on every dashboard deployment. Any file placed there that isn't in the dashboard's `dist/` output WILL be deleted. If a config file needs to be browser-accessible, Caddy serves it from `/etc/weewx-clearskies/` via a `handle` route — never by placing it alongside static assets.

**Why (2026-06-06):** `webcam.json` was placed in the web root by the wizard and deleted by `rsync --delete` during a dashboard redeploy. This happened repeatedly because the wizard wrote to `_dashboard_root` and no deployment script could exclude every possible config file. Moving all config to `/etc/weewx-clearskies/` eliminates the category of bug.

**PowerShell multi-line commits: use `git commit -F`.** Write message to `c:\tmp\<task>-msg.txt`, then `git commit -s -F c:\tmp\<task>-msg.txt`. PowerShell heredocs break on parens/quotes.

## Plan and documentation discipline

**Plan stays an index.** `CLEAR-SKIES-PLAN.md` links to ADRs. Decision content lives in ADRs, not the plan body.

**Don't hold things across turns.** Comparison tables, open decisions, investigation findings → write to a file immediately. The cost of writing is negligible; the cost of losing context mid-session is high.

**Live scratchpad during multi-agent rounds.** Maintain `c:\tmp\<phase-task>-scratch.md`. Append continuously after every commit, lead-call, audit finding, state change. Not reconstructed retroactively.

**Round briefs land in `docs/planning/briefs/`.** Not in `c:\tmp\` or other ephemeral locations.

**No decision log.** Don't maintain a round-by-round decision log in the plan or in per-domain files — git history is the build trail and the ADRs are the decision record. The decision log went unused and was dropped 2026-05-28.

**`.claude/` stays private.** Agent definitions, settings, MCP config are gitignored. Don't propose tracking them or exposing multi-agent orchestration in public repos.

## Provider module rules

**CAPABILITY declares paid-tier maximum supply set.** `supplied_canonical_fields` enumerates every field the provider can deliver on its richest plan. Runtime bundle population is conditional on what the actual response carries. Document tier-conditional fields in `operator_notes`. Tests cover both paths. Does NOT extend to keyless providers (no tier conditional) or fields the provider categorically does not supply.

**No "promotion candidates" in v0.1 contracts.** Stock weewx columns are first-class. `extras` carries operator-custom columns only.

## Communication rules

**Plain English to the user.** Define every technical term the first time it appears in a conversation. One phrase, not a paragraph. If a reply uses 5+ unfamiliar terms, rewrite.

**One decision thread per reply.** Don't interleave multiple topics. Note side-topics briefly at the end.

**Audit decision completeness before claiming a phase done.** Walk through the surface checklist: data model, database, API contract, external integrations, operational, UI/UX, quality bars, deployment, cross-cutting.

**Never hide operator secrets from the operator.** The wizard re-run, admin config UI, and any setup flow must pre-fill ALL existing configuration including API keys, passwords, and secrets. This is the operator's own system — there is no threat model where hiding their own keys from them makes sense. Every credential field that exists in `secrets.env` or the API's `/setup/current-config` response must round-trip through the wizard without the operator having to re-enter it. Sentinels (e.g., `_unchanged`) for form POST are fine to avoid sending plaintext unnecessarily, but the form must render with the value pre-filled (or a clear "using existing key" indicator with the sentinel). Any new provider module that adds credential fields MUST add corresponding entries to `_FIELD_REMAP` in `routes.py` and verify the env var prefix pattern in `state_persistence.py`.

**Why (2026-05-25):** Aeris `client_id` and `client_secret` were returned correctly by the API's `/setup/current-config` endpoint but silently dropped by the wizard's `_merge_from_api_current_config()` because `_FIELD_REMAP` had no entries for them. The operator was forced to re-enter keys that were already configured. Separately, `populate_from_config()` used a domain-scoped env var prefix (`WEEWX_CLEARSKIES_FORECAST_AERIS_`) instead of the actual provider-scoped prefix (`WEEWX_CLEARSKIES_AERIS_`), so the local fallback also failed.

**Verify default branch name before writing it into briefs.** api repo = `main`, meta repo = `master`. Brief errors propagate when reused as templates.

## UI implementation quality gates

These rules apply to all Track C (component) implementation work. They exist because C1–C6 was marked "code-complete" while the code diverged from the approved mockups on every measurable axis — font sizes 23% too large, border separators missing, SVG geometry changed, layout properties wrong. Forensic comparison proved agents never opened the mockup files. These rules close the gaps that allowed that.

**CX implementation briefs must include exact CSS values, not document references.** The UI-REDESIGN-PLAN and C0 inventory are strategic. Each CX implementation brief (C7-PLAN, C8-PLAN, etc.) must be **prescriptive to exact property values.** No handwaving. No "read the typography doc and apply it." Every acceptance criterion must include the exact values the agent must use, plus grep-checkable FAIL conditions. Example:

```
Card title — ALL cards on this page:
  font-family: var(--font-sans)
  font-size: var(--text-card-title, 0.82rem)
  font-weight: 600 (semibold)
  padding-bottom: 5px
  border-bottom: 1px solid var(--border)

FAIL CONDITIONS (grep-checkable):
  - Any card h2 with className containing "text-base" → WRONG
  - Any card h2 with "font-medium" → WRONG, should be font-semibold
  - Any card h2 missing "border-b" or "borderBottom" → WRONG
```

The same level of specificity applies to every element: stat numerals, labels, gauges, chart axes, SVG geometry. If the mockup says `font-size: 18px`, the brief says `font-size: 18px` and the acceptance criteria says `FAIL if not 18px`.

**Mockup-to-implementation handoff must be explicit.** When an approved HTML mockup exists, the CX implementation brief must include:

```
SOURCE OF TRUTH: docs/design/mockups/<mockup>.html
Agent MUST open this file, extract the exact CSS values for the elements
it is building, and use those values. If the code uses different values,
that is a defect — not a refinement.
```

The brief must ALSO extract the key values from the mockup and list them inline (per the rule above), so there is no ambiguity even if the agent skips the file.

**Why (2026-06-02):** C4 stat tiles mockup specified card titles at 13px with border-bottom separators. Every tile was implemented at 16px with no separators. The C4 brief told agents to read the typography spec and reference implementations but never said "open C4-stat-tiles.html and use its CSS values." The mockup was a Phase 0 artifact with no bridge back to Phase 2 code. The agents coded from a mental model.

**Coordinator must QC agent work iteratively BEFORE it reaches the operator.** The coordinator is the quality gate between the agent and the operator. When an agent delivers code:

1. Open the rendered output (dev server screenshot or headless render).
2. Compare it against the mockup (if one exists) and the spec values from the brief.
3. If there are discrepancies, **send it back to the agent for rework** with specific instructions ("card title is 16px, should be 13px per brief §X; border-bottom missing; fix these").
4. Repeat until the output matches the spec.
5. Only THEN report to the operator as complete.

The operator should never see first-draft slop. If the coordinator cannot run the dev server in a session, the task stays open — do not declare it done based on `tsc` passing.

**Visual verification (QC Gate 3) must be a side-by-side comparison, not a glance.** After the component is built:

1. Screenshot the built component at the locked footprint size.
2. If a mockup exists, screenshot the mockup at the same size.
3. Open both images and compare — report specific discrepancies (font too large, border missing, SVG proportions changed), not "looks good."
4. Run the brief's FAIL CONDITIONS as mechanical grep checks.

"It renders without crashing" is NOT visual verification. "The card title is 13px with a 1px border-bottom and the gauge value is 18px Outfit 600" IS visual verification.

**Auditor must check governing doc compliance mechanically.** For every UI card, the auditor must run these checks (grep or code inspection):

- Every card h2/title uses `var(--text-card-title)` or equivalent 0.82rem — NOT `text-base`
- Every card h2/title has `border-b` or `borderBottom` — NOT missing
- Every card h2/title uses `font-semibold` (600) — NOT `font-medium` (500) or `font-bold` (700)
- Stat numerals use `var(--font-display)` (Outfit) — NOT `var(--font-sans)` (Manrope)
- Chart labels use `var(--font-chart)` (Lexend) — NOT system fonts

These are pattern matches, not judgment calls. FAIL if any violation is found.

**"Code-complete" requires coordinator visual sign-off.** The agent that writes the code cannot declare it done. The coordinator must render the output, verify it against the spec, and sign off. Self-attestation of visual quality is not accepted.

**Why (2026-06-02):** C1–C6 were all self-attested as code-complete. QC gates checked `tsc` (compiles) and `vite build` (bundles) but never compared the rendered output against the mockups. Every tile card had wrong font sizes, missing separators, broken sr-only hiding, no vertical centering, and inconsistent text hierarchy. The operator discovered all of this during live testing — not during any QC gate.
