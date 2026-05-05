# Tech-stack spike findings

**Date:** 2026-05-04
**Phase 1 task:** "Validate tech-stack via small spike … render mock data, confirm DX." Per ADR-002 implementation guidance: "shadcn + Recharts starter on Tailwind v4 + React 19."
**Where it ran:** `weather-dev` LXD container (`192.168.2.113`); spike code at `/home/ubuntu/spike/clearskies-spike/`. Throwaway — not committed, not preserved beyond the lessons in this file.
**Verdict:** ADR-002 stack validated. Bundle fits ADR-033 budget with headroom. Two concrete footguns documented for the dashboard scaffold (`react-is` override, TS6 `baseUrl` deprecation). One process correction documented in [PLAN-VS-ADR-AUDIT-2026-05-04.md](PLAN-VS-ADR-AUDIT-2026-05-04.md).

## Versions exercised (May 2026 baseline)

| Tool | Version |
|---|---|
| Node.js | 22.22.2 LTS |
| npm | 10.9.7 |
| Vite | 8.0.10 |
| React | 19.2.5 |
| TypeScript | 6.0.2 |
| Tailwind CSS | 4.2.4 (via `@tailwindcss/vite`) |
| shadcn CLI | 4.6.0 |
| `@base-ui/react` (shadcn primitive base) | 1.4.1 |
| Recharts | 3.8.1 |
| `react-is` | 19.2.5 (via `overrides`) |
| `lucide-react` | 1.14.0 |

## Findings

### Finding 1 — `react-is` override unblocks Recharts on React 19

ADR-002 implementation guidance flagged: "Recharts (current major) requires a `react-is` dependency override when used with React 19." Confirmed. Without the override, `npm install recharts` fails with `ERESOLVE could not resolve` against React 19.

**Working override** (in `package.json`, before `npm install recharts`):

```json
"overrides": {
  "react-is": "^19.2.0"
}
```

This pulls every package's transitive `react-is` to React 19's version, including the one Recharts pins below 19. Install succeeds, build succeeds, runtime works. The dashboard repo's Phase 2 scaffold MUST set this override before installing Recharts; otherwise the install fails cold and a maintainer wastes time debugging.

### Finding 2 — Bundle size fits ADR-033 budget with headroom

Production build with the locked stack and a single chart on screen:

```
dist/index.html                  0.46 kB │ gzip:   0.30 kB
dist/assets/index-*.css         34.10 kB │ gzip:   6.70 kB
dist/assets/index-*.js         546.46 kB │ gzip: 164.52 kB
```

[ADR-033](../decisions/ADR-033-performance-budget.md) sets the Now-page initial JS bundle budget at **≤ 200 KB gzipped**. We're at **164.52 KB** — under by ~35 KB. The Vite warning about "chunks larger than 500 kB" is a raw-bytes threshold; ADR-033 measures gzipped (the over-the-wire size), so the warning is informational, not a budget violation.

This is dramatically better than the off-spec first pass with ECharts (435 KB gzipped, 2.2× over budget). Recharts is the correct choice for the project's bundle goals, as ADR-002 already concluded.

**Implication:** code-splitting per page route is a Phase 3 polish concern, not a budget-driven necessity for the Now page. Worth doing as the dashboard grows (Charts page may add weight; ADR-024 has nine pages total), but the headroom suggests we won't be fighting the budget on the most-frequent landing.

### Finding 3 — TypeScript 6 deprecates `tsconfig.compilerOptions.baseUrl`

`tsc --noEmit` against the spike's first pass emitted:

```
tsconfig.json(8,5): error TS5101: Option 'baseUrl' is deprecated and will stop
functioning in TypeScript 7.0. Specify compilerOption '"ignoreDeprecations": "6.0"'
to silence this error.
```

Both shadcn's CLI scaffold and the standard Vite + React + TS path-alias pattern set `baseUrl: "."` and `paths: { "@/*": ["./src/*"] }`. TS6 has deprecated this in favor of `--moduleResolution bundler` doing the work; TS7 will remove it.

**Mitigation applied in the spike:** add `"ignoreDeprecations": "6.0"` to both `tsconfig.json` and `tsconfig.app.json`. With it set, `tsc --noEmit` is silent and the build is clean.

**Implication for the dashboard repo:** include this in the `tsconfig.app.json` template at scaffold time. When TS7 lands (likely 2027), a path-alias migration is needed across all four code repos — mechanical, but flag it now so we're not surprised.

### Finding 4 — Tailwind v4 + shadcn v4 + React 19 + Vite 8 baseline is clean

- `npm create vite@latest <app> -- --template react-ts` scaffolds React 19 + TS 6 + Vite 8.
- Tailwind v4 install: `npm install -D tailwindcss @tailwindcss/vite` + a single line in `vite.config.ts` + `@import "tailwindcss";` in CSS. **No `tailwind.config.{js,ts}` needed** (v4 is "CSS-first config" — variants and tokens declared inline in CSS via `@theme` and `@custom-variant`).
- `npx shadcn@latest init -d` validates Tailwind v4, scaffolds `components.json`, writes `src/lib/utils.ts` and `button.tsx`. Pulls `@base-ui/react@1.4.1` as the primitives base (shadcn migrated from Radix to Base UI in late 2025).
- `npx shadcn@latest add card badge separator -y` works without prompting; components copied to `src/components/ui/`.

### Finding 5 — Dark mode via `data-theme` attribute (ADR-023) is small + library-free

Tailwind v4 takes a custom variant declaration:

```css
@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));
```

Then `dark:bg-foo` works against an `<html data-theme="dark">` root. A small React state hook flips the attribute on a button click. No `next-themes` or equivalent library needed. Confirmed visually — toggle button in the Now-page header swaps theme in <16 ms.

### Finding 6 — Path alias `@/*` requires both Vite resolve.alias AND tsconfig paths

Standard footgun: setting it in only one place compiles but breaks runtime, or vice versa. shadcn's CLI doesn't set both. The spike sets both (Vite via `resolve.alias`, tsconfig via `compilerOptions.paths` + `baseUrl`). Document in the dashboard repo's first-day setup.

### Finding 7 — Dev server reachable from DILBERT browser via container LAN IP

`vite --host 0.0.0.0 --port 5173` inside `weather-dev` is reachable from DILBERT at `http://192.168.2.113:5173/` (HTTP 200, ~107 ms). No SSH tunnel, no port forward — pure LAN routing because both DILBERT and weather-dev sit on br-vlan2 with public-LAN IPs.

This validates the dev workflow architecture in [rules/clearskies-process.md](../../rules/clearskies-process.md) "Dev/test runs in `weather-dev`": services bind to all interfaces inside the container; DILBERT browser reaches them directly.

### Finding 8 — Recharts accessibility requires explicit work

Recharts renders SVG, not canvas. Good for accessibility (text in DOM), but Recharts' own components don't auto-generate accessible alternatives. The spike adds:

- An `aria-label` on the chart's parent `<section>` summarizing what the chart shows (per `rules/coding.md` §5.5 "Charts (ECharts)" — applies equally to Recharts).
- A screen-reader-only `<table>` with `class="sr-only"` containing the same data points (hour + temperature). Non-sighted users get the actual values.

This pattern needs to be enforced in any Recharts wrapper component the dashboard repo ships. Bare `<LineChart>` without the table fallback would fail [ADR-026](../decisions/ADR-026-accessibility-commitments.md)'s WCAG 2.1 AA target.

### Finding 9 — Lucide icons work cleanly with React 19

`lucide-react@1.14.0` imports as named exports, tree-shakes per icon, accepts `strokeWidth` and `aria-hidden` props, sizes via Tailwind utilities. No surprises; no peer-dep friction.

## DX assessment

The locked Vite + React 19 + Tailwind 4 + shadcn + Recharts + Lucide stack is **good DX**:

- **Hot reload is fast** (Vite cold-starts in 438 ms; component edits reload in <200 ms).
- **Type checking is strict and useful** — the Vite template's defaults (`noUnusedLocals`, `noUnusedParameters`, `verbatimModuleSyntax`, `erasableSyntaxOnly`) catch trivial mistakes early.
- **shadcn + Tailwind v4 makes one-off cards trivial** — most spike components are < 50 lines because the visual primitives compose freely.
- **Recharts API is React-idiomatic** — declarative components (`<LineChart><Line/></LineChart>`), works naturally with React state, no imperative chart-instance object to manage.
- **No build-time configuration sprawl** — no Babel config, no PostCSS config, no separate Tailwind config, no chart-library config.
- **Two paper cuts to plan around:** the `react-is` override (Finding 1) and the TS6 `baseUrl` deprecation (Finding 3). Both have one-line mitigations and need to land in the dashboard scaffold template at Phase 2 task time, not be discovered fresh by Phase 3.

## What was NOT exercised (out of spike scope)

- Tremor Raw copy-paste path. Not needed — ADR-002 already drops Tremor; shadcn + Tailwind + Recharts covers everything the locked design needs.
- Routing — single-page. React Router 7+ vs. TanStack Router not tested.
- State management — mock data is module-level; the typed API client and SSE wiring not tested.
- i18n per [ADR-021](../decisions/ADR-021-i18n-strategy.md) — text was English literals.
- Playwright + axe-core — Phase 1 task 6 (CI scaffolding) covers that.
- Production build deploy. Built artifacts confirmed in `dist/`; not served from a real reverse-proxy.
- Real API integration. Mock data only.

## Recommended Phase 2/3 follow-ups

1. **Dashboard repo scaffold (Phase 2 prep) MUST include `"overrides": { "react-is": "^19.2.0" }` in `package.json` before `npm install recharts`.** Document at the top of `DEVELOPMENT.md`.
2. **Both `tsconfig.json` and `tsconfig.app.json` MUST set `"ignoreDeprecations": "6.0"`** until TS7 lands, at which point a mechanical path-alias migration is needed across all four code repos.
3. **The Recharts wrapper component the dashboard ships MUST include the screen-reader data-table fallback.** Bare Recharts charts fail ADR-026 / `rules/coding.md` §5.5.
4. **No ADR-002 amendment needed.** ADR-002 is correct as-is; the spike confirmed every locked choice.
5. **No ADR-033 amendment needed.** Bundle fits the budget on the Now page; per-page code-splitting can be a Phase 3 polish concern, not a budget-driven necessity.

## Spike artifact location and re-run command

The spike code lives at `weather-dev:/home/ubuntu/spike/clearskies-spike/` and the dev server is currently bound to `0.0.0.0:5173`. Tear-down + re-run:

```sh
ssh ratbert "lxc exec weather-dev -- bash -lc '
# Stop running dev server
[ -f /tmp/vite.pid ] && kill \$(cat /tmp/vite.pid) 2>/dev/null
rm -rf /home/ubuntu/spike/clearskies-spike

mkdir -p /home/ubuntu/spike && cd /home/ubuntu/spike
npm create vite@latest clearskies-spike -- --template react-ts -y
cd clearskies-spike

# react-is override BEFORE recharts install
node -e '\\''const fs=require(\"fs\");const p=JSON.parse(fs.readFileSync(\"package.json\",\"utf8\"));p.overrides={...p.overrides,\"react-is\":\"^19.2.0\"};fs.writeFileSync(\"package.json\",JSON.stringify(p,null,2))'\\''

npm install
npm install -D tailwindcss @tailwindcss/vite
npx shadcn@latest init -d
npx shadcn@latest add card badge separator
npm install --save recharts lucide-react
'"
```
