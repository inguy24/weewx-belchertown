# Row Height Options — ADR-051 Token Adjustment

**Date:** 2026-06-16
**Context:** Card title font (`--text-card-title: 0.82rem`) is smaller than body text (`--text-body: 0.9rem`), destroying visual hierarchy. Root cause: row height too tight, which pressured title size down to fit content. Fix: increase row height to allow proportionally larger titles.

**Constraint:** All values derive from `--card-quarter-row` (quarter x2 = half, quarter x4 = row, content-max = row - 4rem). Changing the quarter changes everything.

---

## Current Baseline

| Token | Desktop | Mobile |
|---|---|---|
| `--card-quarter-row` | 2.75rem (44px) | 3.25rem (52px) |
| `--card-half-row` (page header) | 5.5rem | 6.5rem |
| `--card-row` (data card) | 11rem (176px) | 13rem (208px) |
| `--card-content-max` | 7rem | 9rem |
| `--text-card-title` | 0.82rem (13px) | 0.82rem |
| `--text-body` | 0.9rem (14.4px) | 0.9rem |

---

## Option A — Small bump (+0.25rem quarter)

| Token | Desktop | Mobile |
|---|---|---|
| `--card-quarter-row` | 3rem (48px) | 3.5rem (56px) |
| `--card-half-row` | 6rem | 7rem |
| `--card-row` | 12rem (192px) | 14rem (224px) |
| `--card-content-max` | 8rem | 10rem |
| `--text-card-title` | **1rem (16px)** | 1rem |

- Title clearly larger than body text (1rem vs 0.9rem).
- +1rem per data card on desktop, +1rem on mobile.
- Minimal visual disruption to existing layouts.

---

## Option B — Medium bump (+0.5rem quarter)

| Token | Desktop | Mobile |
|---|---|---|
| `--card-quarter-row` | 3.25rem (52px) | 3.75rem (60px) |
| `--card-half-row` | 6.5rem | 7.5rem |
| `--card-row` | 13rem (208px) | 15rem (240px) |
| `--card-content-max` | 9rem | 11rem |
| `--text-card-title` | **1.1rem (~18px)** | 1.1rem |

- Strong visual separation between title and body.
- Desktop row matches current mobile row size.
- +2rem per data card on desktop — cards feel more spacious.
- Now page gets noticeably taller (more scrolling).

---

## Option C — Larger bump (+0.75rem quarter)

| Token | Desktop | Mobile |
|---|---|---|
| `--card-quarter-row` | 3.5rem (56px) | 4rem (64px) |
| `--card-half-row` | 7rem | 8rem |
| `--card-row` | 14rem (224px) | 16rem (256px) |
| `--card-content-max` | 10rem | 12rem |
| `--text-card-title` | **1.15rem (~18.4px)** | 1.15rem |

- Generous breathing room in all cards.
- Risk: Now page grid significantly taller, more scrolling.
- Some cards may feel hollow with excess space.

---

## Recommendation

**Option A.** The core problem is title/body visual hierarchy (0.82rem vs 0.9rem). A 0.82 -> 1rem title jump fixes that without dramatically changing the layout. Current cards aren't content-starved — they just need the title distinguishable from body text.

---

## Decision

**Status:** Decided

**Chosen option:** B — medium bump (+0.5rem quarter)

**Notes:** Applies site-wide including Now page cards. Requires ADR-051 amendment to update token table.
