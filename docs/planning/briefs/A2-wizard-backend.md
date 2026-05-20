# Round A2 Brief: Wizard backend endpoints

**Repo:** weewx-clearskies-stack (`c:\CODE\weewx-clearskies-stack\`)
**API repo (imports):** `c:\CODE\weewx-clearskies-api\`
**Depends on:** A1 (package scaffold) — complete

## Deliverables

1. `weewx_clearskies_config/wizard/` subpackage — backend logic for all wizard steps
2. FastAPI router at `/wizard` with endpoints for 8 wizard steps
3. Minimal Jinja2 templates for each step (functional, not polished — A4 handles UX)
4. HTMX integration (CDN script in base.html, HTMX attributes on forms)
5. pyproject.toml update: add `weewx-clearskies-api>=0.1.0` (for schema reflection)

## Architecture

The wizard is HTMX-driven: each step is a server-rendered HTML fragment. The user progresses through 8 steps. Data accumulates in an in-memory WizardState keyed by session ID.

**HTMX pattern:**
- Main wizard page loads at GET /wizard with a step container div
- Each step is a form fragment loaded/swapped via HTMX
- `hx-post` on forms, `hx-target="#wizard-content"`, `hx-swap="innerHTML"`
- Routes return HTML fragments when `HX-Request` header is present, full pages otherwise
- base.html needs `<script src="https://unpkg.com/htmx.org@2.0.4"></script>` added

## Package structure

```
weewx_clearskies_config/wizard/
├── __init__.py
├── state.py           — WizardState dataclass + session store
├── db.py              — DB connection testing, weewx.conf auto-detect
├── schema.py          — Schema introspection, column mapping suggestions
├── station.py         — Station identity extraction
├── providers.py       — Provider registry (static), API key testing
├── topology.py        — Deployment topology, shared-secret generation
├── config_writer.py   — Generate ConfigObj configs + secrets.env
└── routes.py          — FastAPI router, all 8 steps + apply

weewx_clearskies_config/templates/wizard/
├── layout.html        — Wizard container with progress indicator
├── step_db.html       — Step 1: DB connection form
├── step_schema.html   — Step 2: Column mapping form
├── step_station.html  — Step 3: Station identity form
├── step_providers.html — Step 4: Provider selection form
├── step_keys.html     — Step 5: API key entry form
├── step_topology.html — Step 6: Deployment topology form
├── step_binds.html    — Step 7: Service bind addresses form
├── step_review.html   — Step 8: Review summary
└── step_complete.html — Success page after apply
```

## Module specs

### state.py

```python
@dataclass
class WizardState:
    # Step 1: DB connection
    db_host: str | None = None
    db_port: int = 3306
    db_user: str | None = None
    db_password: str | None = None
    db_name: str = "weewx"

    # Step 2: Column mapping
    column_mapping: dict[str, str | None] = field(default_factory=dict)
    # key=db_column_name, value=canonical_name or None (unmapped)

    # Step 3: Station identity
    station_name: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    altitude_meters: float | None = None
    timezone: str | None = None

    # Step 4: Provider selections
    # key=domain (forecast/alerts/aqi/earthquakes/radar), value=provider_id
    providers: dict[str, str] = field(default_factory=dict)

    # Step 5: API keys
    # key=provider_id, value=dict of credential fields
    api_keys: dict[str, dict[str, str]] = field(default_factory=dict)

    # Step 6: Topology
    topology: str = "same-host"  # "same-host" or "cross-host"
    proxy_secret: str | None = None

    # Step 7: Bind addresses
    api_bind_host: str = "127.0.0.1"
    api_bind_port: int = 8765
    realtime_bind_host: str = "127.0.0.1"
    realtime_bind_port: int = 8766


_store: dict[str, WizardState] = {}

def get_wizard_state(session_id: str) -> WizardState: ...
def save_wizard_state(session_id: str, state: WizardState) -> None: ...
def clear_wizard_state(session_id: str) -> None: ...
```

### db.py

```python
from sqlalchemy import create_engine, text

def build_db_url(host: str, port: int, user: str, password: str, db_name: str) -> str:
    # Return pymysql URL: mysql+pymysql://user:password@host:port/db_name

def test_connection(host: str, port: int, user: str, password: str, db_name: str) -> dict[str, Any]:
    # Create engine, execute "SELECT 1", return {"success": True, "server_version": "..."} or {"success": False, "error": "..."}
    # Use connect_args={"connect_timeout": 5}

def detect_from_weewx_conf(conf_path: str) -> dict[str, Any]:
    # Parse weewx.conf using configobj (NOT the API's load_weewx_conf — to avoid the API dependency for this one function)
    # Navigate: cfg["DatabaseTypes"]["archive_mysql"] for host, user, password, port
    # Navigate: cfg["Databases"]["archive_mysql"]["database_name"] for db name
    # Return {"host": ..., "port": ..., "user": ..., "password": ..., "db_name": ...}
    # Raise FileNotFoundError if weewx.conf not found
```

### schema.py

```python
from weewx_clearskies_api.db.reflection import STOCK_COLUMN_MAP, SchemaReflector

def introspect_schema(db_url: str) -> dict[str, Any]:
    # Create engine from db_url, instantiate SchemaReflector, call .reflect()
    # Return:
    # {
    #   "stock_columns": [{"db_name": "outTemp", "canonical": "outdoorTemperature", "auto_mapped": True}, ...],
    #   "unmapped_columns": [{"db_name": "aqi", "suggested": "aqi", "confidence": "high"}, ...],
    #   "total_columns": 85,
    #   "stock_mapped": 60,
    # }

def suggest_canonical(db_column: str, canonical_fields: list[str]) -> tuple[str | None, str]:
    # Heuristic: case-insensitive substring match of db_column against canonical field names
    # Return (best_match_or_None, confidence: "high"|"medium"|"low"|"none")
```

### station.py

```python
def station_from_db(db_url: str) -> dict[str, Any]:
    # Query the archive table for lat/lon if stored (weewx stores in [Station] not DB, so this may return empty)
    # Return {"station_name": None, "latitude": None, "longitude": None, ...}

def station_from_weewx_conf(conf_path: str) -> dict[str, Any]:
    # Parse weewx.conf [Station] section
    # Return {"station_name": ..., "latitude": ..., "longitude": ..., "altitude_meters": ..., "location": ...}

def lookup_timezone(latitude: float, longitude: float) -> str | None:
    # Use timezonefinder if available, else return None
    # Add timezonefinder to pyproject.toml optional deps or try/except import
```

### providers.py

Static provider registry — the config UI has its own metadata, doesn't import API provider modules.

```python
@dataclass(frozen=True)
class ProviderInfo:
    provider_id: str
    display_name: str
    domain: str  # forecast, alerts, aqi, earthquakes, radar
    geographic_coverage: str  # "US only", "Global", etc.
    auth_fields: tuple[str, ...]  # credential field names the operator must provide
    test_url: str  # URL to hit for connectivity test
    test_method: str  # "get"
    notes: str = ""

PROVIDERS: list[ProviderInfo] = [
    # Forecast
    ProviderInfo("nws", "National Weather Service", "forecast", "US only", (), "https://api.weather.gov/points/38.8894,-77.0352", "get", "Keyless; uses User-Agent header"),
    ProviderInfo("openmeteo", "Open-Meteo", "forecast", "Global", (), "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0&hourly=temperature_2m", "get", "Keyless, free tier"),
    ProviderInfo("openweathermap", "OpenWeatherMap", "forecast", "Global", ("api_key",), "https://api.openweathermap.org/data/2.5/weather?q=London&appid={api_key}", "get"),
    ProviderInfo("aeris", "Aeris Weather", "forecast", "Global", ("client_id", "client_secret"), "https://api.aerisapi.com/conditions/washington,dc?client_id={client_id}&client_secret={client_secret}", "get"),

    # Alerts
    ProviderInfo("nws_alerts", "NWS Alerts", "alerts", "US only", (), "https://api.weather.gov/alerts/active?limit=1", "get", "Keyless"),

    # AQI
    ProviderInfo("iqair", "IQAir / AirVisual", "aqi", "Global", ("api_key",), "https://api.airvisual.com/v2/nearest_city?lat=0&lon=0&key={api_key}", "get"),
    ProviderInfo("openweathermap_aqi", "OpenWeatherMap AQI", "aqi", "Global", ("api_key",), "https://api.openweathermap.org/data/2.5/air_pollution?lat=0&lon=0&appid={api_key}", "get"),

    # Earthquakes
    ProviderInfo("usgs", "USGS Earthquakes", "earthquakes", "Global", (), "https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&limit=1", "get", "Keyless"),

    # Radar
    ProviderInfo("rainviewer", "RainViewer", "radar", "Global", (), "https://api.rainviewer.com/public/weather-maps.json", "get", "Keyless"),
]

def providers_by_domain() -> dict[str, list[ProviderInfo]]: ...
    # Group PROVIDERS by domain

def recommend_providers(latitude: float, longitude: float) -> dict[str, str]: ...
    # Return recommended provider per domain based on location
    # US locations: prefer NWS for forecast and alerts
    # Non-US: prefer OpenMeteo for forecast

def test_provider(provider: ProviderInfo, credentials: dict[str, str]) -> dict[str, Any]:
    # Make HTTP GET to test_url (with credential substitution)
    # Return {"success": True, "response_time_ms": ...} or {"success": False, "error": "...", "status_code": ...}
    # Use httpx with 5s timeout
```

### topology.py

```python
import secrets

def generate_proxy_secret() -> str:
    return secrets.token_hex(32)

def topology_defaults(same_host: bool) -> dict[str, Any]:
    # Return default bind addresses based on topology
    # same_host: API and realtime bind 127.0.0.1
    # cross_host: API binds [::] (needs shared secret)
    return {
        "api_bind_host": "127.0.0.1" if same_host else "::",
        "api_bind_port": 8765,
        "realtime_bind_host": "127.0.0.1" if same_host else "::",
        "realtime_bind_port": 8766,
        "needs_proxy_secret": not same_host,
    }
```

### config_writer.py

This is the most complex module. It generates ConfigObj .conf files with MANAGED REGION markers.

```python
from configobj import ConfigObj

def write_api_conf(state: WizardState, config_dir: Path) -> Path:
    # Write api.conf with MANAGED REGION markers
    # Sections: [server], [database], [column_mapping], [forecast], [alerts], [aqi], [earthquakes], [radar]
    # Return path to written file

def write_realtime_conf(state: WizardState, config_dir: Path) -> Path:
    # Write realtime.conf: [server], [mqtt] sections
    # Return path

def write_stack_conf(state: WizardState, config_dir: Path) -> Path:
    # Write stack.conf: [ui] section
    # Return path

def write_secrets_env(state: WizardState, config_dir: Path) -> Path:
    # Write secrets.env with all provider API keys + proxy secret
    # Format: WEEWX_CLEARSKIES_<DOMAIN>_<PROVIDER>_<FIELD>=<value>
    # Mode 0600
    # Return path

def apply_wizard(state: WizardState, config_dir: Path) -> dict[str, Any]:
    # Orchestrator: calls all write_* functions
    # Returns {"files_written": [...], "secrets_written": [...]}
```

### routes.py

FastAPI router mounted in app.py. All endpoints require auth.

```python
router = APIRouter(prefix="/wizard", tags=["wizard"])

# Step 1: DB Connection
@router.get("/step/1")      → render step_db.html
@router.post("/step/1/test") → test_connection(), return result fragment
@router.post("/step/1/detect") → detect_from_weewx_conf(), return populated form
@router.post("/step/1")     → save to state, return step 2 fragment

# Step 2: Schema + Column Mapping
@router.get("/step/2")      → introspect_schema(), render step_schema.html with columns
@router.post("/step/2")     → save mapping to state, return step 3

# Step 3: Station Identity
@router.get("/step/3")      → station_from_db() or station_from_weewx_conf(), render step_station.html
@router.post("/step/3")     → save to state, return step 4

# Step 4: Provider Selection
@router.get("/step/4")      → providers_by_domain() + recommend_providers(), render step_providers.html
@router.post("/step/4")     → save to state, return step 5

# Step 5: API Keys
@router.get("/step/5")      → render step_keys.html for selected providers needing keys
@router.post("/step/5/test") → test_provider(), return result
@router.post("/step/5")     → save to state, return step 6

# Step 6: Topology
@router.get("/step/6")      → render step_topology.html with defaults
@router.post("/step/6")     → save to state (generate proxy_secret if cross-host), return step 7

# Step 7: Bind Addresses
@router.get("/step/7")      → render step_binds.html with topology-based defaults
@router.post("/step/7")     → save to state, return step 8

# Step 8: Review + Apply
@router.get("/step/8")      → render step_review.html with full state summary
@router.post("/apply")      → apply_wizard(), render step_complete.html
```

## Templates

Minimal but functional. Use Pico CSS (already in base.html from A1). WCAG AA compliant:
- All inputs have `<label>`
- Error messages use `aria-live="polite"`
- Form fields have `aria-invalid` when errors present
- Buttons have visible text (no icon-only)

Each step template extends a wizard layout with a progress indicator (simple "Step N of 8" text).

## Integration with app.py

Add to `create_app()`:
1. Import wizard router: `from weewx_clearskies_config.wizard.routes import router as wizard_router`
2. Include router: `app.include_router(wizard_router)`
3. Update GET `/` redirect: if no config exists, redirect to `/wizard`

## pyproject.toml changes

Add dependencies:
- `weewx-clearskies-api>=0.1.0`
- `timezonefinder>=6.5.0` (for timezone lookup from lat/lon — put in optional `[wizard]` extra if you prefer)

## What NOT to build
- Config CRUD / master config page (A3/A5)
- Template polish (A4)
- CLI terminal flow (A6)
- Tests (A7)

## Commit

Commit on `main`: `feat: A2 — wizard backend endpoints and templates`
Co-author: `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`
