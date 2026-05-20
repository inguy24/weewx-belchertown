# Round A5 Brief: Master config page frontend

**Repo:** weewx-clearskies-stack
**Depends on:** A3 (config CRUD backend) — must complete first

## Deliverable

Build the template suite for the master configuration page (the ongoing-edit interface at `/admin/config`). Uses A3's backend routes.

## Templates to create/polish

In `templates/config/`:

1. **dashboard.html** — main config page. Sidebar nav listing all config sections grouped by component (API, Realtime, Stack). Each nav item loads the section edit form via HTMX. Show current value summary next to each section name.

2. **section.html** — generic section edit form. Renders dynamically based on the section's fields. Each field has a label, current value, and input. Password/secret fields show masked value with a "change" toggle. Save button with HTMX POST.

3. **column_mapping.html** — dedicated column mapping editor (separate from generic section.html since it has special UX). Table with: DB column name | Current canonical mapping | Dropdown to change | Status (stock/custom/unmapped). Save button. Note: "Changes take effect on next API request — no restart needed."

4. **provider_section.html** — provider config form. Shows current provider for a domain, dropdown to change, API key fields (masked), "Test" button with HTMX inline result.

5. **result.html** — feedback fragment after save (success/error message with `aria-live`).

## Layout

The config dashboard should look like a settings page:
- Left sidebar (or top tabs on mobile): section navigation
- Right content area: edit form for selected section
- HTMX loads section forms without full page reload

Use Pico CSS grid/layout. Clean, functional, not flashy.

## Sections to support

**API (api.conf):**
- Server: bind_host, bind_port
- Database: host, port, user, password (from secrets.env), db_name
- Column Mapping: special editor (column_mapping.html)
- Forecast: provider dropdown + credentials
- Alerts: provider dropdown + credentials  
- AQI: provider dropdown + credentials
- Earthquakes: provider dropdown + credentials
- Radar: provider dropdown + credentials

**Realtime (realtime.conf):**
- Server: bind_host, bind_port
- MQTT: broker_host, broker_port, topic, username, password (from secrets.env)

**Stack (stack.conf):**
- UI: enabled toggle, bind_host, bind_port, TLS cert/key paths

## WCAG AA

Same checklist as A4 — labels, aria-live, keyboard access, contrast, no icon-only buttons.

## Do NOT change

- Backend modules (config/reader.py, config/updater.py, config/routes.py)
- Wizard templates
- app.py

## Commit

On `main`: `feat: A5 — master config page frontend`
