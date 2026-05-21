# ADR-038: Wizard-to-API Secure Channel & API-Mediated Configuration

- **Status:** Accepted
- **Date:** 2026-05-20
- **Deciders:** shane
- **Amends:** ADR-027 (wizard flow), ADR-008 (auth model)

## Context

The current wizard (ADR-027) connects directly to the operator's MariaDB database from the config UI. This has three problems:

1. **DB credentials cross the network.** The config UI runs on one host; the database is on another. Credentials travel over unencrypted HTTP between VLANs.
2. **No access to weewx.conf.** The config UI cannot read `weewx.conf` to auto-detect station identity, DB settings, or timezone because it runs on a different machine. The operator must type everything manually.
3. **No encryption between the config UI and API.** ADR-008 explicitly uses plaintext shared secrets on the wire, relying on LAN trust. This is insufficient when traffic crosses VLANs or when third-party software may communicate with the API.

The API is co-located with the database and `weewx.conf` on the weewx host. It can read both locally. The config UI should talk to the API, not the database.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **A. Config UI talks to API (selected)** | API reads weewx.conf + DB locally; no credentials cross the network; auto-detect works; third-party extensible | Requires API installed before wizard runs; adds TLS requirement |
| B. Config UI connects to DB directly (current) | Simpler initial implementation; no API dependency during setup | DB creds cross the wire; no weewx.conf access; no station auto-detect; no encryption |
| C. Config UI SSHs into weewx host | Can read weewx.conf and DB config remotely | Requires SSH credentials; complex key management; fragile; hostile to non-technical operators |

## Decision

**The config UI communicates with the API, not the database.** All database operations and `weewx.conf` reads are performed by the API on behalf of the config UI.

### TLS

The API serves TLS by default using a self-signed certificate generated on first install.

- **Default:** API generates a unique keypair + self-signed certificate on first start. Stored in the config directory alongside `secrets.env`. Cert fingerprint printed to terminal.
- **Override:** Operator can replace with their own certificate via `--tls-cert` and `--tls-key` CLI flags, or by uploading through the config UI after initial setup. Supports Let's Encrypt, corporate PKI, or any CA-signed certificate.
- **Third-party compatibility:** Third-party software connecting to the API can either (a) verify the self-signed cert via fingerprint pinning, or (b) trust the certificate chain if the operator has installed a CA-signed cert. Both are standard patterns.

### Trust handshake

1. Operator installs the API on the weewx host.
2. API first start: generates TLS cert + trust token. Prints to terminal:
   ```
   API ready. To connect your config UI:
     Address:     https://weewx-host:8765
     Trust token: a1b2c3d4...
     Fingerprint: SHA-256:AB:CD:EF:...
   ```
3. Operator opens config UI wizard. Step 1: enters API address, trust token, and cert fingerprint.
4. Config UI connects over TLS, verifies fingerprint matches, sends trust token.
5. API validates token, issues a session. Trust token is consumed (single-use).
6. Fingerprint is pinned for future connections (SSH-style known_hosts behavior). If the cert changes, the config UI refuses to connect until the operator re-verifies.

### Revised wizard flow

| Step | Current (ADR-027) | New |
|------|-------------------|-----|
| 1 | DB connection (host, port, user, pass, db name) | **API connection** (address, trust token, fingerprint) |
| 2 | Column mapping | **DB connection** — API sends settings from weewx.conf, pre-filled. Operator reviews/overrides if DB is remote. API tests connection, returns schema. |
| 3 | Station identity (manual entry) | **Column mapping** (unchanged) |
| 4 | Data pipeline / MQTT | **Station identity** — pre-filled from weewx.conf via API. Operator reviews/edits. |
| 5 | Providers | **Data pipeline / MQTT** (unchanged) |
| 6 | Review + apply | **Providers** (unchanged) |
| — | — | **Review + apply** (config sent to API; API writes its own config files) |

### What the API provides during setup

After the trust handshake, the API exposes setup-only endpoints (authenticated by the session):

- `GET /setup/db-defaults` — returns DB connection settings from `weewx.conf`
- `POST /setup/db-test` — tests a DB connection (operator-supplied or default), returns success/failure
- `GET /setup/schema` — returns column schema from the connected database
- `GET /setup/station` — returns station identity from `weewx.conf` (name/location, lat, lon, altitude, timezone)
- `POST /setup/apply` — writes final configuration; API restarts with the new config

### DB configuration

The API reads `weewx.conf` locally and knows the database connection. But weewx allows remote databases, so the operator must be able to override:

- API sends the DB settings it found in `weewx.conf` as defaults
- Config UI pre-fills the form with those defaults
- Operator confirms or overrides (e.g., if DB is on a remote host)
- API tests the connection and returns the column schema

## Consequences

- **API must be installed before the wizard runs.** This is a new prerequisite. The install docs must reflect this.
- **ADR-008 amended:** the "no TLS" position is reversed. API serves TLS by default. The `X-Clearskies-Proxy-Auth` shared secret still applies for ongoing dashboard/realtime requests; the trust token is for initial setup only.
- **ADR-027 amended:** Step 1 changes from DB connection to API connection. Station auto-detect becomes the default path, not a best-effort fallback.
- **Config UI no longer needs direct DB access.** No database driver dependency in the config UI package.
- **Third-party extensible.** The TLS + fingerprint model is standard; third-party tools can connect to the API using the same mechanism.
- **Repos affected:** `weewx-clearskies-api` (TLS, trust token, setup endpoints), `weewx-clearskies-stack` (wizard flow rewrite).

## Implementation guidance

- Cert generation: use Python `cryptography` library (already a transitive dependency via `argon2-cffi`). Generate RSA 2048 or Ed25519 key + self-signed X.509 cert with 10-year validity.
- Trust token: same `secrets.token_hex(32)` pattern already used by the config UI bootstrap.
- Fingerprint: SHA-256 of the DER-encoded certificate, displayed as colon-separated hex (standard format).
- Pin storage: config UI stores `{api_url: fingerprint}` in its config directory.
- Setup endpoints are gated behind the trust session; they are not accessible with the normal `X-Clearskies-Proxy-Auth` shared secret. They are disabled after initial setup completes (the API has its config and no longer needs them).

## Out of scope

- Mutual TLS (mTLS) — ADR-008's position that mTLS is operationally hostile for the target audience still holds. Server-side TLS is sufficient.
- Certificate rotation / renewal automation — operator replaces certs manually if needed. ACME/Let's Encrypt integration is a future consideration.
- API discovery / mDNS — operator provides the API address manually.

## References

- ADR-027: Config and setup wizard
- ADR-008: Auth model
- ADR-037: Inbound traffic architecture
