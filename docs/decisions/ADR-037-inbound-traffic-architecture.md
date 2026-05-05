---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-037: Inbound traffic flow — one-door reverse-proxy architecture

## Context

[ADR-001](ADR-001-component-breakdown.md) defines three runtime services that must reach a browser: static SPA assets, `weewx-clearskies-api` (read-only HTTP/JSON), and `weewx-clearskies-realtime` (SSE). The original sketch had the browser making three independent connections — three internet-exposed services. User direction 2026-05-01: the API should not be directly accessible to the end-user; the web server proxies and passes through. This ADR settles inbound traffic flow before the auth model in [ADR-008](ADR-008-auth-model.md).

## Options considered

| Option | Verdict |
|---|---|
| A. Multiple internet-exposed services (browser hits SPA host, API host, realtime host directly) | Rejected — three attack surfaces; CORS preflight everywhere; API credentials would leak into JS bundle. |
| B. One-door reverse-proxy (single web server serves SPA + reverse-proxies `/api/v1/*` and `/sse`; inner services bind to loopback) | **Selected.** |
| C. Dedicated API gateway (Kong, Traefik) | Rejected — heavyweight for home-station deploys. |

## Decision

**One-door reverse-proxy is mandatory.** All public traffic terminates at a single web server that:

1. Serves the SPA static build at `/`.
2. Reverse-proxies `/api/v1/*` to `weewx-clearskies-api`.
3. Reverse-proxies `/sse` to `weewx-clearskies-realtime`.

Inner services bind to `127.0.0.1` by default and are never publicly exposed. Cross-host deploys use LAN-interface bind plus a shared-secret header per [ADR-008](ADR-008-auth-model.md).

**External upstream API calls (Aeris, NWS, OpenMeteo, OpenWeatherMap, Wunderground per [ADR-007](ADR-007-forecast-providers.md)) originate from `weewx-clearskies-api`, not from the browser.** The API holds operator credentials, makes the calls, caches per [ADR-017](ADR-017-provider-response-caching.md), returns normalized JSON per [ADR-010](ADR-010-canonical-data-model.md). Browsers never see upstream URLs or credentials.

The web server itself is **not** something this project ships, except in the docker-compose path:

| Distribution | Proxy supplied by |
|---|---|
| Native install (pip / Debian) | Operator's existing web server. Project ships example configs for Apache + Caddy + nginx in INSTALL docs. |
| docker-compose stack | Caddy bundled in the compose file; `docker compose up` yields the whole stack including TLS via auto-Let's Encrypt. |

## Consequences

- Single internet-facing component → single attack surface, single TLS termination, single rate-limiting choke point.
- CORS becomes a non-issue for the default deployment (one origin).
- API key / credential exposure to the browser eliminated structurally — operator-managed compliance per [ADR-006](ADR-006-compliance-model.md) is enforced by architecture, not "remember to do this" rules.
- Inner services don't need CORS handling, TLS termination, or per-public-IP rate limiting.

### Trade-offs accepted
- **Reverse-proxy capable web server is now a hard prerequisite.** Mitigated by the docker-compose path bundling Caddy.
- **SSE through a reverse proxy needs correct buffering/timeout config.** Apache: `flushpackets=on` + adequate timeouts. nginx: `proxy_buffering off` + `proxy_read_timeout` raised. Caddy: works out of the box. INSTALL docs cover all three; CI runs an integration test that proves SSE survives a 10-minute idle and reconnects.
- **Cross-host deploys require additional config** — LAN-bind + shared secret per [ADR-008](ADR-008-auth-model.md).
- **Same-machine deploys with `127.0.0.1` bind don't validate that the connecting process is actually the proxy.** Any local process can hit the inner service. Accepted: if an attacker has shell access, the database file is also reachable. Documented in `SECURITY.md` as the threat-model assumption.
- **CDN-hosted SPA deployments** (Cloudflare Pages, GitHub Pages calling our API) are not officially supported, not documented, not tested. If a user wants this they take on the security responsibility (CORS, public API exposure, browser-side credentials).

### Repos affected
- **api / realtime:** bind `127.0.0.1` by default; loud startup warning if bound to a non-loopback address with no shared secret set.
- **dashboard:** SPA's API client uses relative URLs (`/api/v1/...`, `/sse`) by default — works because the proxy serves it all from one origin. `VITE_API_BASE_URL` override exists for the unusual cross-origin dev case.
- **stack:** docker-compose ships Caddy as the front service; example configs for Apache and nginx live alongside as alternatives.

## Implementation guidance

### Default network bindings

```ini
# weewx-clearskies-api
[server]
bind_host = 127.0.0.1
bind_port = 8765

# weewx-clearskies-realtime
[server]
bind_host = 127.0.0.1
bind_port = 8766
```

### Proxy path conventions

| Browser path | Proxied to |
|---|---|
| `/` (and any unmatched path → SPA's `index.html`) | Static SPA bundle |
| `/api/v1/*` | `clearskies-api` (`http://127.0.0.1:8765`) |
| `/sse` | `clearskies-realtime` (`http://127.0.0.1:8766`) |
| `/health` | Proxy returns 200 if it's up |

### Reference proxy snippets (full versions in component INSTALL.md)

**Apache:**
```apache
ProxyPass        /api/v1/  http://127.0.0.1:8765/api/v1/  flushpackets=on timeout=60
ProxyPassReverse /api/v1/  http://127.0.0.1:8765/api/v1/
ProxyPass        /sse      http://127.0.0.1:8766/sse      flushpackets=on timeout=3600 keepalive=on
ProxyPassReverse /sse      http://127.0.0.1:8766/sse
```

**Caddy** (bundled docker-compose):
```caddy
weather.example.com {
    reverse_proxy /api/v1/* clearskies-api:8765
    reverse_proxy /sse      clearskies-realtime:8766
    root * /srv/dashboard
    file_server
}
```

**nginx:**
```nginx
location /api/v1/ {
    proxy_pass http://127.0.0.1:8765/api/v1/;
    proxy_buffering off;
    proxy_read_timeout 60s;
}
location /sse {
    proxy_pass http://127.0.0.1:8766/sse;
    proxy_buffering off;
    proxy_read_timeout 3600s;
}
```

## Out of scope
- Auth model details — [ADR-008](ADR-008-auth-model.md).
- Rate-limiting parameters — security baseline + [ADR-008](ADR-008-auth-model.md).
- Setup wizard / GUI — [ADR-027](ADR-027-config-and-setup-wizard.md).
- TLS provider for native installs — operator's choice (Apache + certbot documented).

## References
- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-002](ADR-002-tech-stack.md), [ADR-005](ADR-005-realtime-architecture.md), [ADR-006](ADR-006-compliance-model.md), [ADR-007](ADR-007-forecast-providers.md), [ADR-008](ADR-008-auth-model.md), [ADR-017](ADR-017-provider-response-caching.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-034](ADR-034-deployment-topology-default.md).
