# clearskies-process.md — Clear Skies project process rules

Load when working on Clear Skies (`weewx-clearskies-*` repos, planning docs, ADRs, contracts).
Incident history and rationale at [reference/process-rule-history.md](../reference/process-rule-history.md).

---

## ADR discipline

**Write decisions to disk immediately.** Decision discussed → ADR drafted as `Proposed` → user reviews full content → user explicitly approves → status becomes `Accepted`. Never create ADRs as Accepted. "It was in the plan" is not sign-off. Directional chat ("yes use the prefix") is input to a Proposed ADR, not approval.

**Corrections edit in place.** Status flips back to Proposed until user re-approves. Don't create a new "supersedes" ADR for ordinary corrections — only for fundamentally distinct decisions.

**Read the ADR before the plan.** Plan body summaries drift. ADR wins on conflict — fix the plan to match.

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

## Agent orchestration

**Lead = Opus, orchestration + judgment only.** Teammates = Sonnet. The lead does NOT write code, run tests, do code reviews, or fill in templates. Those are delegated tasks. Lead's job: break down work, write focused prompts, spawn agents, monitor, QC output, make judgment calls, commit.

**Sonnet for ALL delegated work.** Implementation, tests, audits, verification, closeout extraction. Opus auditor is not worth the cost — Sonnet auditor validated at 75K tokens with clean results (3b-15 close).

**Lead does NOT do research grunt work.** Reading files, running SSH commands, glob/grep searches, state verification — all of that is delegated to Sonnet agents (Explore, foreground general-purpose, or the relevant specialist). Opus tokens cost real money; Sonnet tokens are an order of magnitude cheaper. The lead's capability is irrelevant — what matters is whether a cheaper agent can do it. If a task is "read these files and summarize" or "check this repo's HEAD and node version," that's Sonnet work. The lead receives the summary, makes judgment calls, and writes detailed prompts for the next agent. The only direct tool calls the lead makes are: spawning agents, SendMessage to monitor them, writing to the scratchpad, and committing to git.

**Why (2026-05-18):** Phase 3 task 1 session start — the lead read 10+ files (rules, ADRs, spike findings), ran SSH commands to verify weather-dev state, ran multiple glob/grep searches to find ADR paths, and read repo files — all before spawning a single agent. Every one of those reads burned Opus tokens on work any Sonnet agent could do. The user pays for these tokens. The lead's job is to delegate the reading to cheap agents, receive summaries, then synthesize into detailed agent prompts.

**Small, focused tasks.** Each agent gets one specific job with a clear deliverable. "Implement 2 provider modules + tile proxy + wiring" is too big. "Implement openweathermap.py radar provider per this spec" is right. Shorter runs = less idle-bug risk, easier to monitor, cheaper to retry.

**Focused agent prompts.** Each agent receives ONLY the context needed for its specific task. Don't load full rules files, full ADRs, or project history into agent prompts. Extract the relevant section and inline it. The lead carries the full context; agents carry task context.

**Monitor via SendMessage.** After spawning background agents, check git log for commits every 3-4 minutes. If an agent has committed but gone quiet >4 min, SendMessage to wake it. After ~3 silent pings, TaskStop and reconstruct from git. The idle bug (#56930) means agents can finish work and sit silent for 30+ min — polling is the only mitigation.

**Foreground for fast tasks.** If an agent's task takes <2 min (verify git state, extract git stats, run one command), use foreground mode. Background is for tasks >5 min where parallel work is possible.

**Independent lead-pytest-verify.** Before accepting any teammate's pytest claim, re-run the same command from a fresh shell. Teammate self-reports are one data point, not truth. (3b-12: api-dev claimed 1762/0/0; reality was 103 failed.)

**Lead-direct for small fixes.** When auditor findings or test bugs are mechanical and small (<=50 lines, <=3 files, no judgment calls), the lead fixes directly. Spawning costs 30-60 min; lead-direct is minutes.

## Audit rules

**Two audit modes, both required for non-trivial work.** Runtime tests against real backends + source-only review against ADRs/rules. Neither alone is sufficient. Order: dev produces → tests run on weather-dev → auditor reviews diff → lead synthesizes.

**Real findings only.** Every finding cites a specific ADR/rule/RFC and identifies: (a) a specific failure mode, (b) a missed constraint, or (c) forced downstream rework. Generic tradeoffs are not findings. Empty audits are fine.

**Lead synthesizes auditor findings.** Per finding: accept (with specific remediation + reasoning), push back (with reasoning), or defer (with condition). Don't forward raw findings to dev unedited.

## Runtime environment

**Dev/test runs in `weather-dev` LXD container, not Windows.** Shell into container: `ssh weather-dev "<command>"`. File sync: push to GitHub from DILBERT, then run `scripts/sync-to-weather-dev.sh`. Browser testing: `http://192.168.2.113:<port>`. DILBERT = editing + git + planning only.

**PowerShell multi-line commits: use `git commit -F`.** Write message to `c:\tmp\<task>-msg.txt`, then `git commit -s -F c:\tmp\<task>-msg.txt`. PowerShell heredocs break on parens/quotes.

## Plan and documentation discipline

**Plan stays an index.** `CLEAR-SKIES-PLAN.md` links to ADRs. Decision content lives in ADRs, not the plan body.

**Don't hold things across turns.** Comparison tables, open decisions, investigation findings → write to a file immediately. The cost of writing is negligible; the cost of losing context mid-session is high.

**Live scratchpad during multi-agent rounds.** Maintain `c:\tmp\<phase-task>-scratch.md`. Append continuously after every commit, lead-call, audit finding, state change. Not reconstructed retroactively.

**Round briefs land in `docs/planning/briefs/`.** Not in `c:\tmp\` or other ephemeral locations.

**Decision log entries: one-line index + per-domain detail files.** The plan's decision log section is a one-line-per-round index. Detailed round narratives live in `docs/planning/decision-log-<domain>.md`. Load only the domain-relevant file when needed.

**`.claude/` stays private.** Agent definitions, settings, MCP config are gitignored. Don't propose tracking them or exposing multi-agent orchestration in public repos.

## Provider module rules

**CAPABILITY declares paid-tier maximum supply set.** `supplied_canonical_fields` enumerates every field the provider can deliver on its richest plan. Runtime bundle population is conditional on what the actual response carries. Document tier-conditional fields in `operator_notes`. Tests cover both paths. Does NOT extend to keyless providers (no tier conditional) or fields the provider categorically does not supply.

**No "promotion candidates" in v0.1 contracts.** Stock weewx columns are first-class. `extras` carries operator-custom columns only.

## Communication rules

**Plain English to the user.** Define every technical term the first time it appears in a conversation. One phrase, not a paragraph. If a reply uses 5+ unfamiliar terms, rewrite.

**One decision thread per reply.** Don't interleave multiple topics. Note side-topics briefly at the end.

**Audit decision completeness before claiming a phase done.** Walk through the surface checklist: data model, database, API contract, external integrations, operational, UI/UX, quality bars, deployment, cross-cutting.

**Verify default branch name before writing it into briefs.** api repo = `main`, meta repo = `master`. Brief errors propagate when reused as templates.
