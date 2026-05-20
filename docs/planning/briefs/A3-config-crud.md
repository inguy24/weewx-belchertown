# Round A3 Brief: Config CRUD backend

**Repo:** weewx-clearskies-stack (`c:\CODE\weewx-clearskies-stack\`)
**Depends on:** A2 (wizard backend, config_writer) — complete

## Deliverables

1. `weewx_clearskies_config/config/` subpackage — read/update existing configs
2. MANAGED REGION merge logic — update managed section, preserve free-form
3. FastAPI router at `/admin/config` with per-section CRUD endpoints
4. Column re-mapping endpoint (takes effect without service restart)
5. Minimal templates for config dashboard

## Architecture

The master config page lets an operator edit settings after initial wizard setup. Each config section is independently editable. Changes are merged into the MANAGED REGION of the relevant .conf file without touching operator's free-form content below the marker.

## Package structure

```
weewx_clearskies_config/config/
├── __init__.py
├── reader.py          — Read + parse existing .conf files
├── updater.py         — MANAGED REGION merge logic
└── routes.py          — FastAPI router, per-section CRUD

weewx_clearskies_config/templates/config/
├── dashboard.html     — Config section overview/nav
├── section.html       — Generic section edit form (HTMX fragment)
└── result.html        — Save result feedback fragment
```

## Module specs

### reader.py

```python
from configobj import ConfigObj
from pathlib import Path

COMPONENTS = ("api", "realtime", "stack")

def find_config_dir() -> Path:
    # Same search order as auth.py _config_dir()

def read_config(component: str, config_dir: Path) -> ConfigObj | None:
    # Read <component>.conf if it exists, return parsed ConfigObj or None

def get_section(component: str, section_path: str, config_dir: Path) -> dict[str, Any]:
    # Read a specific section (e.g., "server", "database", "forecast")
    # section_path can be nested: "forecast.openmeteo"
    # Return flat dict of key-value pairs

def get_all_sections(config_dir: Path) -> dict[str, dict[str, Any]]:
    # Return all sections across all component configs
    # Grouped by component: {"api": {"server": {...}, "database": {...}}, "realtime": {...}, ...}

def get_column_mapping(config_dir: Path) -> dict[str, str | None]:
    # Read [column_mapping] from api.conf
    # Return dict: db_column_name -> canonical_name (or None if unmapped)
```

### updater.py

This is the core MANAGED REGION merge logic.

```python
MANAGED_BEGIN = "# MANAGED REGION BEGIN"
MANAGED_END = "# MANAGED REGION END"

def update_managed_region(
    config_path: Path,
    section: str,
    values: dict[str, Any],
) -> None:
    # 1. Read existing file as text
    # 2. Find MANAGED REGION BEGIN / END markers
    # 3. Parse the managed region as ConfigObj
    # 4. Update the specified section with new values
    # 5. Re-serialize the managed region
    # 6. Replace managed region in original text, preserving free-form below
    # 7. Write back to file
    # If no markers found, treat entire file as managed (backward compat with hand-written configs)

def update_secrets(
    key: str,
    value: str,
    config_dir: Path,
) -> None:
    # Read secrets.env, update or add the key, write back (mode 0600)

def update_column_mapping(
    mapping: dict[str, str | None],
    config_dir: Path,
) -> None:
    # Update [column_mapping] section in api.conf via managed region merge
    # This takes effect on the next API request (no restart needed —
    # the API's ColumnRegistry.refresh() re-reads on config change)
```

### routes.py

```python
router = APIRouter(prefix="/admin/config", tags=["config"])

# Dashboard
@router.get("/")              → render dashboard.html (list of all sections with current values)

# Per-section CRUD
@router.get("/{component}/{section}")   → render section.html (edit form for one section)
@router.post("/{component}/{section}")  → update section via managed region merge, return result

# Column mapping (special — no restart needed)
@router.get("/column-mapping")          → render column mapping form (current mapping + available canonical fields)
@router.post("/column-mapping")         → update mapping, return result

# Provider test (reuse wizard provider test)
@router.post("/test-provider")          → call wizard.providers.test_provider(), return result
```

## HTMX pattern

Same as wizard: HTMX forms with `hx-post`, `hx-target`, `hx-swap`. Dashboard has a sidebar nav listing sections; clicking a section loads the edit form via HTMX.

## Config sections available for editing

From api.conf:
- `server` — bind_host, bind_port
- `database` — host, port, user, password (password from secrets.env), db_name
- `column_mapping` — key=db_column, value=canonical_name
- `forecast` — provider name
- `alerts` — provider name
- `aqi` — provider name
- `earthquakes` — provider name
- `radar` — provider name

From realtime.conf:
- `server` — bind_host, bind_port
- `mqtt` — broker_host, broker_port, topic, username (password from secrets.env)

From stack.conf:
- `ui` — enabled, bind_host, bind_port, tls_cert_path, tls_key_path

## Integration with app.py

Add config router:
```python
from weewx_clearskies_config.config.routes import create_config_router
config_router = create_config_router(templates, session_manager, config_dir)
app.include_router(config_router)
```

## Accessibility

Same rules as A2 templates — labels on all inputs, aria-live for feedback, semantic HTML.

## Commit

On `main`: `feat: A3 — config CRUD backend with MANAGED REGION merge`
Co-author: `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>`
