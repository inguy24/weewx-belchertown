# Round A1 Brief: Package scaffold for weewx-clearskies-config

**Repo:** weewx-clearskies-stack (`c:\CODE\weewx-clearskies-stack\`)
**Agent:** Sonnet (general-purpose)
**Depends on:** Phase 0 (ADR-027 refinements) — complete

## Deliverables

1. `pyproject.toml` at repo root
2. `weewx_clearskies_config/` package:
   - FastAPI application factory
   - CLI entry point with all flags
   - Auth module (Argon2id + bootstrap token + session + rate limiting)
   - TLS module (self-signed cert gen, opt-in)

## Package structure

```
weewx_clearskies_config/
├── __init__.py          # Version string
├── __main__.py          # python -m weewx_clearskies_config support
├── app.py               # FastAPI app factory, lifespan, middleware
├── auth.py              # Argon2id, bootstrap, sessions, rate limiting
├── cli.py               # click CLI, all flags, uvicorn launch
├── tls.py               # Self-signed cert generation + loading
├── static/              # Empty dir with .gitkeep (CSS/JS later)
│   └── .gitkeep
└── templates/           # Jinja2 templates (minimal bootstrap page only)
    ├── base.html         # Base template with Pico CSS CDN link
    ├── login.html        # Login form
    └── bootstrap.html    # Set admin credentials form
```

## CLI flags (cli.py, using click)

| Flag | Default | Behavior |
|------|---------|----------|
| (none) | — | HTTP on `[::]:9876` (all interfaces, dual-stack) |
| `--localhost` | off | Bind `127.0.0.1` + `::1` only |
| `--bind <addr>` | `[::]` | Specific address, resolved via `socket.getaddrinfo` |
| `--port <n>` | 9876 | Port number |
| `--tls` | off | Enable self-signed HTTPS |
| `--cli` | off | Terminal flow (print "not yet implemented" and exit for A1) |
| `--reset` | off | Overwrite config (stub: print message and exit) |
| `--reset-admin-password` | off | Clear admin hash from secrets.env, exit |
| `--show-secrets` | off | Print current secrets from secrets.env, exit |
| `--headless` | off | Non-interactive (stub: print message and exit) |

Mutual exclusion: `--localhost` and `--bind` conflict. `--cli`, `--reset`, `--show-secrets`, `--reset-admin-password`, `--headless` are action flags that run and exit (don't start the server).

## Auth module (auth.py)

**Password hashing:**
- `hash_password(password: str) -> str` — Argon2id via argon2-cffi
- `verify_password(password: str, hash_str: str) -> bool` — constant-time

**Bootstrap token:**
- `BootstrapManager` class: generates 32-byte hex token, stores in-memory, single-use
- `generate() -> str`, `validate(token: str) -> bool` (constant-time compare, invalidates on success)

**Sessions:**
- Cookie name: `clearskies_session`
- Generate: `secrets.token_urlsafe(32)` as session ID
- Store: in-memory dict mapping session_id → username
- Cookie flags: HttpOnly, SameSite=Strict, Secure only when TLS active, Path=/
- Expire on process exit (no disk persistence)

**Rate limiting:**
- Track failed login attempts per IP
- 5 failures per IP per 60-second window → 60s throttle
- In-memory dict with timestamps, no Redis
- Clean up stale entries periodically

**Secrets file I/O:**
- Config dir search order: `WEEWX_CLEARSKIES_CONFIG_DIR` env var → `/etc/weewx-clearskies/` → `~/.config/weewx-clearskies/`
- Read/write `secrets.env` as simple KEY=VALUE lines
- Write with mode 0600 (on platforms that support it)
- Keys: `WEEWX_CLEARSKIES_ADMIN_USERNAME`, `WEEWX_CLEARSKIES_ADMIN_PASSWORD_HASH`

## TLS module (tls.py)

- `generate_self_signed_cert(bind_addresses: list[str], cert_path: Path, key_path: Path) -> None`
  - RSA 2048 key, SHA-256 signature
  - Subject CN = first bind address
  - SAN: all bind addresses + `localhost` + `127.0.0.1` + `::1`
  - 365-day validity
  - key_path written mode 0600
- `load_or_generate_cert(bind_addresses: list[str], config_dir: Path) -> tuple[Path, Path]`
  - If cert exists and SAN matches → return paths
  - Otherwise generate new cert
- `get_cert_fingerprint(cert_path: Path) -> str` — SHA-256 hex fingerprint

## App factory (app.py)

```python
@dataclass
class AppConfig:
    bind_host: str
    bind_port: int
    tls_enabled: bool
    tls_cert_path: Path | None
    tls_key_path: Path | None
    config_dir: Path
    bootstrap_manager: BootstrapManager | None

def create_app(config: AppConfig) -> FastAPI:
    ...
```

- Mount Jinja2 `TemplateResponse` via `Jinja2Templates`
- Mount `/static` directory
- Routes to implement:
  - `GET /` → redirect to `/wizard` (if no config) or `/admin` (if config exists) or `/login` (if not authenticated). For A1: redirect to `/login` or `/bootstrap`.
  - `GET /health` → 200 `{"status": "ok"}`
  - `GET /bootstrap` → bootstrap page (set admin credentials) if token valid
  - `POST /bootstrap` → process admin credential setup
  - `GET /login` → login page
  - `POST /login` → process login, set session cookie
  - `POST /logout` → clear session cookie, redirect to `/login`
- Middleware: rate-limit check on POST /login

## Network binding rules

- Default `[::]` enables dual-stack on most OS (both IPv4 and IPv6 accepted)
- `--localhost`: bind both `127.0.0.1` and `::1` (two sockets)
- `--bind <addr>`: resolve via `socket.getaddrinfo(addr, port, type=socket.SOCK_STREAM)`, bind each result
- Startup banner: print each bound URL. If any address is not loopback/RFC1918/RFC4193/link-local, print: "Note: Bound to a non-private address. Ensure your firewall settings are appropriate."
- Use `ipaddress` module for address classification

## Coding conventions (match API repo)

- hatchling build, Python >=3.12, GPL-3.0-or-later
- ruff (same config as API: target py312, line-length 100, select E/F/W/I/B/S/N/UP/SIM)
- mypy strict mode
- Double quotes, space indent
- Type hints on all functions
- No comments unless WHY is non-obvious
- No docstrings
- Pin dependency versions exactly

## What NOT to build

- Wizard endpoints (A2)
- Config CRUD endpoints (A3)
- Wizard frontend templates beyond login/bootstrap (A4)
- Master config page (A5)
- CLI terminal flow implementation (A6)
- Tests (A7)

Stub routes are fine but don't implement business logic.

## Commit

Commit all work on the `main` branch with message format: `feat: A1 — package scaffold, CLI, auth, TLS modules`
