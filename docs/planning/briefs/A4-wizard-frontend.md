# Round A4 Brief: Wizard frontend polish

**Repo:** weewx-clearskies-stack
**Depends on:** A2 (wizard backend + templates) — complete

## Deliverable

Polish the existing wizard templates (created in A2) into a polished multi-step experience. No backend changes — templates only.

## What exists (from A2)

10 templates in `templates/wizard/`: layout.html, step_db.html, step_schema.html, step_station.html, step_providers.html, step_keys.html, step_topology.html, step_binds.html, step_review.html, step_complete.html. All functional but minimal.

## What to improve

1. **Progress indicator** — visual step progress bar in layout.html showing steps 1-8 with current step highlighted, completed steps checked. Use semantic HTML: `<nav aria-label="Wizard progress"><ol>` with `aria-current="step"`.

2. **Loading states** — when "Test Connection" or "Test Provider" buttons fire HTMX requests, show a spinner/loading indicator. Use HTMX `hx-indicator` attribute with a CSS spinner. No JavaScript needed.

3. **Form validation UX** — add `required` attributes on mandatory fields. Add `pattern` for port numbers. Use Pico CSS's built-in form validation styling.

4. **Column mapping table (step_schema.html)** — improve the mapping table: sortable columns (stock mapped / unmapped), clear visual distinction between auto-mapped and operator-confirmed, dropdown for canonical field selection on unmapped columns.

5. **Provider recommendations (step_providers.html)** — highlight recommended providers with a "(Recommended)" label. Group by domain with clear headings.

6. **API key masking (step_keys.html)** — use `<input type="password">` with a show/hide toggle button (accessible: `aria-label="Show password"`).

7. **Review page (step_review.html)** — format as a clean summary with section headings. Mask API key values (show first/last 4 chars). Add "Edit" links per section that HTMX-navigate back to that step.

8. **Success page (step_complete.html)** — clear instructions for next steps (start services, configure reverse proxy). Include the generated shared secret if cross-host topology.

9. **Mobile responsiveness** — Pico CSS handles most of this, but verify form layouts work on narrow screens. Use `<div class="grid">` for side-by-side fields.

10. **Back navigation** — add "Previous" buttons on each step (HTMX GET to previous step).

## WCAG AA checklist (mandatory)

- All inputs have labels
- Error regions have `aria-live="polite"` 
- Focus management: after HTMX swap, focus moves to the new content or first error
- Color contrast: all text meets 4.5:1
- All interactive elements keyboard-accessible
- No icon-only buttons without `aria-label`

## Do NOT change

- Backend routes (routes.py)
- Backend modules (db.py, schema.py, etc.)
- Non-wizard templates (login.html, bootstrap.html, base.html)

## Commit

On `main`: `feat: A4 — wizard frontend polish`
