# Round A6 Brief: CLI mode

**Repo:** weewx-clearskies-stack
**Depends on:** A2 (wizard backend modules) — complete

## Deliverable

Implement the `--cli` and `--headless` flags in the CLI entry point. Terminal-based wizard that reuses the same backend modules as the web wizard.

## Files to create/modify

1. **NEW: `weewx_clearskies_config/cli_wizard.py`** — terminal wizard implementation
2. **MODIFY: `weewx_clearskies_config/cli.py`** — wire `--cli` and `--headless` flags to new module

## cli_wizard.py

Interactive terminal wizard using `click.prompt` and `click.confirm` (click is already a dependency). Do NOT add questionary or rich as dependencies — keep it simple with click's built-in prompts.

### Flow (mirrors web wizard steps 1-8):

```python
def run_cli_wizard(config_dir: Path) -> None:
    click.echo("Clear Skies — Configuration Wizard (CLI)")
    click.echo("=" * 40)
    
    # Step 1: DB Connection
    db_host = click.prompt("Database host", default="localhost")
    db_port = click.prompt("Database port", default=3306, type=int)
    db_user = click.prompt("Database user", default="weewx")
    db_password = click.prompt("Database password", hide_input=True)
    db_name = click.prompt("Database name", default="weewx")
    
    # Test connection
    from .wizard.db import test_connection
    result = test_connection(db_host, db_port, db_user, db_password, db_name)
    if result["success"]:
        click.echo(f"Connected! Server: {result['server_version']}")
    else:
        click.echo(f"Connection failed: {result['error']}")
        if not click.confirm("Continue anyway?"):
            return
    
    # Step 2: Schema introspection
    from .wizard.db import build_db_url
    from .wizard.schema import introspect_schema
    schema = introspect_schema(build_db_url(db_host, db_port, db_user, db_password, db_name))
    click.echo(f"Found {schema['total_columns']} columns ({schema['stock_mapped']} auto-mapped)")
    # Show unmapped columns, prompt for mapping
    for col in schema.get("unmapped_columns", []):
        if col.get("suggested"):
            mapping = click.prompt(
                f"Map '{col['db_name']}' to", default=col["suggested"]
            )
        else:
            mapping = click.prompt(f"Map '{col['db_name']}' to (or 'skip')", default="skip")
    
    # Step 3: Station identity
    # Step 4: Provider selection
    # Step 5: API keys
    # Step 6: Topology
    # Step 7: Bind addresses
    # Step 8: Review + Apply
    # ... follow same pattern: prompt → validate → store in WizardState

    # Apply
    from .wizard.config_writer import apply_wizard
    from .wizard.state import WizardState
    state = WizardState(...)  # populated from prompts
    result = apply_wizard(state, config_dir)
    for f in result.get("files_written", []):
        click.echo(f"  Written: {f}")
```

### Headless mode

`--headless` accepts all config via CLI flags (no prompts). Minimum viable:

```
weewx-clearskies-config --headless \
    --db-host localhost --db-port 3306 --db-user weewx --db-password secret --db-name weewx \
    --forecast-provider openmeteo \
    --topology same-host
```

Implement as additional click options on the main CLI command. When `--headless` is set, skip prompts and use flag values directly.

For A6, implement the full `--cli` wizard and a basic `--headless` with the most important flags (db connection, forecast provider, topology). Full flag coverage can be expanded later.

## cli.py changes

Replace the stub:
```python
if cli_mode:
    click.echo("CLI terminal flow not yet implemented.")
    sys.exit(0)
```

With:
```python
if cli_mode:
    from weewx_clearskies_config.cli_wizard import run_cli_wizard
    run_cli_wizard(_config_dir())
    sys.exit(0)
```

Similarly for headless.

## Do NOT change

- Web routes or templates
- app.py
- auth.py, tls.py

## Commit

On `main`: `feat: A6 — CLI wizard and headless mode`
