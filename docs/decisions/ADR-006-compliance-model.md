---
status: Accepted
date: 2026-04-30
deciders: shane
---

# ADR-006: End-user-managed compliance for third-party APIs

## Context

Clear Skies will integrate with third-party weather APIs (Aeris, OpenWeatherMap, Meteoblue, Wunderground, NWS, OpenMeteo, etc.) for forecast and supplemental data. These APIs vary in:

- Auth model (API key, client_id+secret, none)
- ToS (commercial vs. non-commercial use, attribution requirements, caching restrictions)
- Free-tier rate limits
- Redistribution restrictions

We need to decide who is responsible for compliance with each provider's ToS — the project, or the end user.

User intent (verbatim, paraphrased for clarity): "All of these are going to require the end-user registering their own key and being responsible for their own compliance. I do not want that responsibility... It will be up to the user to do their own compliance and manage their own accounts."

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Project ships bundled API keys | Zero-config for end users | Violates every provider's ToS — keys cannot be redistributed |
| Project intermediates (proxy through a project-run service) | Hides keys server-side, can cache for efficiency | Project becomes a service operator with liability and uptime obligations; impractical for a small OSS team; concentrates risk |
| End user registers and manages own keys; project ships code only | Project liability stops at the code; user has full control | Users must register multiple accounts; some won't bother |

## Decision

**End users register and manage their own keys for any third-party API. The project ships code only.** Each user is responsible for compliance with each provider's ToS, including non-commercial restrictions, attribution, rate limits, and caching policies.

The project's commercial status is **not pre-locked** by this decision. Realistically the project will likely remain non-commercial in practice, but the door is left open for future donations, sponsorship, or other funding models. This compliance posture holds regardless of project commercial status: even if the project later monetizes, end users still hold their own keys and remain responsible for their own compliance.

User intent (verbatim): "let's not lock ourselves into this project being non-commercial, i overspoke here. It probably WILL BE, BUT... i don't want to be boxed into that. If it turns out we really create a bang up project, I would probably at least want to accept donations."

## Consequences

- **No bundled keys.** No example config ships with a working key.
- **No proxied calls** through a project-run service that holds credentials.
- Each provider module documents:
  - Provider's ToS link
  - Free-tier limits and key signup process
  - Any commercial-use restrictions or attribution requirements the user should weigh
- Users with low-quota providers (e.g., Meteoblue free at 5,000 calls/year) decide for themselves whether to accept the limit, upgrade to paid, or pick a different provider — that's a user decision, not a project gate.
- Project remains free to adopt funding models later (donations, sponsorship, dual-licensing) without renegotiating compliance posture.
- This decision is independent of [ADR-003](ADR-003-license.md) (license = GPL v3). License governs derivative code; compliance posture governs third-party API usage by deployments. Both can hold simultaneously regardless of commercial status.

## Implementation guidance

- **Per-provider config docs** lead with: "Get your key from `<signup URL>`. Read the ToS at `<ToS URL>` before enabling — particularly note commercial-use restrictions and rate limits."
- **Missing key disables that provider's pieces only.** If a provider module's required key env var is unset, that module is disabled and any dashboard features that depend on it (e.g., that provider's forecast tile) are hidden. The rest of the service starts normally. A clear log line points to the signup URL for the disabled provider so the user can enable it later if they want.
- **Example configs** never include a real key; placeholders look like `YOUR_AERIS_CLIENT_ID_HERE`, `YOUR_AERIS_CLIENT_SECRET_HERE`.
- **README of `weewx-clearskies-stack`** includes a "before you start" checklist: which providers you'll need to register with, depending on the modules you enable.
- **`SECURITY.md` of each component** states: "This project does not handle third-party API credentials. Users supply their own and are responsible for compliance with each provider's terms of service."
- **No telemetry** that could leak usage patterns back to the project.

## References

- Related ADRs: [ADR-003](ADR-003-license.md) (license), ADR-007 (forecast providers — pinned, will inherit this compliance posture)
- Provider research: `docs/reference/FORECAST-PROVIDER-RESEARCH.md` (in progress as of 2026-04-30 — captures Aeris, OpenWeatherMap, NWS, OpenMeteo, Wunderground, Meteoblue)
