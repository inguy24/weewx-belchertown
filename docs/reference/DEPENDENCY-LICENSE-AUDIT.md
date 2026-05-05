# Dependency License Audit

**Date:** 2026-04-30
**Purpose:** Verify that every runtime/build/infra dependency named in [ADR-002](../decisions/ADR-002-tech-stack.md) is license-compatible with our chosen project license, GPL-3.0-or-later (per [ADR-003](../decisions/ADR-003-license.md)).

This is a research/verification record, not a decision. ADR-002 is the decision; this file is the evidence behind the "all deps compatible" claim. Update or replace if dependencies change or licenses change upstream.

## Method

Each library's license was verified by fetching the LICENSE file (or equivalent) directly from its upstream source repository on GitHub. Where the LICENSE file was unreachable, the package-registry metadata (PyPI / npm) was used and is noted as such. No claim is recorded on memory alone.

## Verification table

| Library | Source verified | Declared license | GPL-3.0-or-later compatible? | Notes |
|---|---|---|---|---|
| FastAPI | https://github.com/fastapi/fastapi/blob/master/LICENSE | MIT | ✅ Yes | — |
| SQLAlchemy 2.x | https://github.com/sqlalchemy/sqlalchemy/blob/main/LICENSE | MIT | ✅ Yes | — |
| uvicorn | https://github.com/encode/uvicorn/blob/master/LICENSE.md | BSD-3-Clause | ✅ Yes | — |
| Starlette | https://github.com/encode/starlette/blob/master/LICENSE.md | BSD-3-Clause | ✅ Yes | — |
| paho-mqtt | https://github.com/eclipse/paho.mqtt.python/blob/master/LICENSE.txt + https://github.com/eclipse/paho.mqtt.python/blob/master/edl-v10 + https://github.com/eclipse/paho.mqtt.python/blob/master/epl-v20 | Dual: EPL-2.0 OR EDL-1.0 | ⚠️ Conditional | Dual-licensed. EPL-2.0 alone is **not** GPL-3.0-compatible (the package's `notice.html` does not designate GPL as a Secondary License via Exhibit A). EDL-1.0 is recognized by SPDX and Eclipse as equivalent to **BSD-3-Clause**, which is GPL-3.0-compatible. Because the package is offered under both, downstream users may **elect EDL-1.0** as the operative license — which we will do. See "Action: paho-mqtt election" below. |
| React 19 | https://github.com/facebook/react/blob/main/LICENSE | MIT | ✅ Yes | — |
| Vite | https://github.com/vitejs/vite/blob/main/LICENSE | MIT | ✅ Yes | — |
| Tailwind CSS v4 | https://github.com/tailwindlabs/tailwindcss/blob/main/LICENSE | MIT | ✅ Yes | — |
| shadcn/ui | https://github.com/shadcn-ui/ui/blob/main/LICENSE.md | MIT | ✅ Yes | Copy-paste model — once copied into our repo, the upstream MIT copyright/permission notice must be preserved in our distribution. |
| Recharts | https://github.com/recharts/recharts/blob/master/LICENSE | MIT | ✅ Yes | — |
| Lucide | https://github.com/lucide-icons/lucide/blob/main/LICENSE | ISC (with MIT for some derivative icons) | ✅ Yes | Both ISC and MIT are GPL-3.0 compatible. |
| Weather Icons | https://github.com/erikflowers/weather-icons/blob/master/README.md | Triple: SIL OFL 1.1 (font) + MIT (code/CSS) + CC BY 3.0 (docs) | ✅ Yes | All three sub-licenses are individually GPL-3.0-compatible (FSF-listed for OFL). Each carries its own attribution obligation that must survive into our distribution: OFL notice with the font binaries, MIT notice with the CSS, CC BY 3.0 attribution with any reused docs. |
| tw-animate-css | https://github.com/Wombosvideo/tw-animate-css/blob/main/LICENSE | MIT | ✅ Yes | — |
| react-is | https://github.com/facebook/react/blob/main/LICENSE (covers all packages in monorepo); `package.json` `"license": "MIT"` | MIT | ✅ Yes | — |
| Caddy | https://github.com/caddyserver/caddy/blob/master/LICENSE | Apache-2.0 | ✅ Yes | Apache-2.0 is compatible with GPLv3 (not with GPLv2-only — irrelevant here). |
| Apache HTTPD | https://github.com/apache/httpd/blob/trunk/LICENSE | Apache-2.0 | ✅ Yes | — |
| certbot | https://github.com/certbot/certbot/blob/main/LICENSE.txt | Apache-2.0 (nginx plugin includes some MIT) | ✅ Yes | — |

## Findings

### paho-mqtt — election required

The dual-license offering means we must explicitly state which of the two licenses governs our use. EPL-2.0 alone would create a real GPL incompatibility; EDL-1.0 alone is clean.

**Action when paho-mqtt is integrated (Phase 2):**

1. Document in the realtime service's `LICENSE-RATIONALE.md` and any `NOTICE` file: "paho-mqtt is used under the Eclipse Distribution License v1.0 (EDL-1.0), one of the two licenses offered by the upstream package. EDL-1.0 is equivalent to BSD-3-Clause."
2. Preserve the EDL-1.0 / BSD-3-Clause copyright and permission notice with the distribution.
3. Do not invoke the EPL-2.0 path in any documentation or attribution.

This makes the conditional ⚠️ effectively ✅.

### Weather Icons — three attribution layers

Each sub-license has its own attribution obligation. None block GPL combination, but the dashboard's `LICENSE-RATIONALE.md` and any redistribution notice must surface all three:

- Font binaries — SIL OFL 1.1 notice; "Reserved Font Names" cannot be reused for derivatives.
- CSS/code — MIT notice.
- Docs (if any of theirs are reused) — CC BY 3.0 attribution.

### Everything else

Clean MIT / BSD-2/3 / Apache-2.0 / ISC — all uncontroversially GPL-3.0-or-later compatible.

## Sources note

All libraries were verified directly against the LICENSE file in the upstream source repository, with two minor exceptions:

- **react-is** — the npm registry page returned 403 to the fetch tool. License confirmed instead via the upstream `package.json` (`"license": "MIT"`) and the repo-level LICENSE file in the React monorepo, which governs all packages including `react-is`. This is the authoritative source.
- **shadcn/ui** — the documentation site does not surface license info, so verification used the LICENSE.md in the source repo directly. Authoritative.

## Re-audit triggers

This file should be re-verified when:

- Any of the libraries above publishes a license change in a future major version.
- A new runtime/build dependency is added to ADR-002 — that dep gets added to this table before merge.
- Annually as a standing check.
