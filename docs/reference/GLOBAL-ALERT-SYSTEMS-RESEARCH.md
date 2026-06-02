# Global Weather Alert Systems — Provider Research & Cross-Mapping

**Status:** Research note (not a decision record). Produced 2026-06-01 for the C5 alert system ADR.
**Purpose:** Document how our three alert providers deliver alerts for different geographies,
how each national warning system classifies severity, and the cross-mapping between provider
data and native severity labels.

**Why this exists:** ADR-010 and ADR-016 defined a US-centric canonical severity model
(`advisory | watch | warning`) that forces every national alert system into NWS terminology.
This research documents what the providers actually deliver so we can build a geography-correct
model.

---

## Table of Contents

1. [Our Three Alert Providers](#1-our-three-alert-providers)
2. [Aeris/Xweather — Detailed Wire Format](#2-aerisxweather--detailed-wire-format)
3. [OpenWeatherMap — Detailed Wire Format](#3-openweathermap--detailed-wire-format)
4. [NWS Direct — Detailed Wire Format](#4-nws-direct--detailed-wire-format)
5. [National Alert Classification Systems](#5-national-alert-classification-systems)
6. [Cross-Mapping: Aeris Suffix → Native Severity Label](#6-cross-mapping-aeris-suffix--native-severity-label)
7. [Cross-Mapping: OWM → Severity](#7-cross-mapping-owm--severity)
8. [Fields We Currently Discard](#8-fields-we-currently-discard)
9. [Known Bugs in Current Implementation](#9-known-bugs-in-current-implementation)
10. [Live API Verification (2026-06-01)](#10-live-api-verification-2026-06-01)

---

## 1. Our Three Alert Providers

| Provider | Module | Coverage | Auth | Severity Info |
|---|---|---|---|---|
| **NWS** (direct) | `providers/alerts/nws.py` | US + territories + adjacent marine | Free, no key | CAP severity field + event name contains tier (Warning/Watch/Advisory) |
| **Aeris/Xweather** | `providers/alerts/aeris.py` | US, Canada, Europe (MeteoAlarm), UK (Met Office), Japan (JMA), Australia (BoM), + India, Brazil, South Africa, South Korea, Mexico | Keyed (client_id + client_secret) | `details.type` suffix (`.W`/`.A`/`.Y`/`.S` for US/CA; `.EX`/`.SV`/`.MD`/`.MN` for international) + `localLanguages` with native labels |
| **OpenWeatherMap** (One Call 3.0) | `providers/alerts/openweathermap.py` | 100+ countries | Keyed (appid, paid One Call 3.0) | **No severity field.** Only `event` string (keyword matching) |

**OWM also offers a Push Weather Alerts API** (separate product, requires email request for access)
with richer data: `severity` (Extreme/Severe/Moderate/Minor/Unknown), `urgency`, `certainty`,
`instruction`, `headline`, 195+ countries. See §3.2. Same underlying data source as One Call 3.0
is likely but unconfirmed.

---

## 1b. Provider Coverage Matrix — Alerts vs Forecast

**Critical distinction:** Provider coverage for alerts is NOT the same as coverage for
forecasts. Aeris provides global forecasts but only covers specific regions for alerts.

### Aeris/Xweather coverage by domain

| Domain | `geographic_coverage` in our code | Actual coverage per current Aeris docs |
|---|---|---|
| **Alerts** | `"us-ca-eu"` ← **WRONG, too narrow** | US, Canada, Europe (MeteoAlarm), UK (Met Office), Japan (JMA), Australia (BoM), India (IMD), Brazil (INMET), South Africa (SAWS), South Korea (KMA), Mexico (CONAGUA/SMN) — 10+ regions per current alerts endpoint docs. |
| **Forecast** | `"global"` | Global (some specialized fields US-only, e.g., ice accumulation out 48h). Up to 15-day forecasts worldwide. |
| **AQI** | `"global"` | Global |
| **Radar** | `"global"` | Global |

**Key takeaway:** Aeris forecast/AQI/radar are global. Aeris alerts are **NOT global** —
they cover a specific list of 10+ regions. An operator outside those regions (e.g.,
Southeast Asia, Middle East, Central America outside Mexico, most of Africa outside South
Africa) would get no alerts from Aeris.

### Aeris alerts — coverage per current Aeris docs

All 10+ regions are documented on the current Aeris alerts endpoint page. `dataSource` values
are documented for 4 regions; the others use the same `AW.XX.YY` international code scheme
(confirmed for Japan and Australia via live API).

| Region | Source System | `dataSource` | Live API Evidence (2026-06-01) |
|---|---|---|---|
| US | NWS | `noaa_nws` | Test fixture (Nebraska fire weather watch) |
| Canada | Environment Canada | `envca` | — (no active alerts at query time) |
| Europe | MeteoAlarm | `meteoalarm` | Paris: `AW.TS.MD`, `localLanguages` French+English |
| UK | Met Office | `ukmet` | — (no active alerts at query time) |
| Japan | JMA | *(not documented)* | Tokyo: `AW.EQ.MN`, country `"jp"` |
| Australia | BoM | *(not documented)* | Sydney: `AW.WI.MD`, country `"au"`, state `"au.ns"` |
| India | IMD | *(not documented)* | — (no active alerts at query time) |
| Brazil | INMET | *(not documented)* | — (no active alerts at query time) |
| South Africa | SAWS | *(not documented)* | — (no active alerts at query time) |
| South Korea | KMA | *(not documented)* | — (no active alerts at query time) |
| Mexico | CONAGUA/SMN | *(not documented)* | — (no active alerts at query time) |

**Action needed:** Update our Aeris alerts CAPABILITY `geographic_coverage` from `"us-ca-eu"`
to include all documented regions.

### OWM coverage by domain

| Domain | Coverage | Notes |
|---|---|---|
| **Alerts** (One Call 3.0/4.0) | 100+ countries | Passthrough only — no structured severity. See §7. |
| **Forecast** | Global | |

### NWS direct coverage

| Domain | Coverage | Notes |
|---|---|---|
| **Alerts** | US + territories + adjacent marine | Rich CAP data (severity, urgency, certainty). Bug: currently maps CAP severity instead of event tier. |
| **Forecast** | US + territories | |

---

## 2. Aeris/Xweather — Detailed Wire Format

**Source:** [Xweather Alerts Endpoint](https://www.xweather.com/docs/weather-api/endpoints/alerts)
+ live API verification 2026-06-01. Captured docs at `C:\tmp\Alert Types - Raster Maps - Xweather.htm`.

### 2.1 Full field inventory

**Top-level:**
- `id` (string) — unique alert ID
- `dataSource` (string) — **source system identifier** (see §2.2)
- `active` (boolean) — whether alert is active
- `loc` (object) — `{lat, long}` coordinates

**`details` object:**
- `type` (string) — structured code with severity suffix (see §2.3)
- `name` (string) — human-readable event name (English, all-caps)
- `loc` (string) — weather zone code
- `emergency` (boolean) — true for emergency-specific alerts (e.g., tornado emergency)
- `priority` (number) — NOAA hazard-map display priority (lower = more significant). **US-centric; meaning varies internationally.**
- `color` (string) — 6-char hex color code. **This is Aeris's own rendering color, NOT the national system's color.**
- `cat` (string) — hazard category (e.g., "thunderstorm", "fire", "wind")
- `body` (string) — shortened alert description
- `bodyFull` (string) — complete unmodified alert text

**`timestamps` object:**
- `issued` / `issuedISO` — initial issuance
- `begins` / `beginsISO` — when alert goes into effect
- `expires` / `expiresISO` — expiration
- `updated` / `updateISO` — last update
- `added` / `addedISO` — when stored in Aeris database
- `created` / `createdISO` — creation time

**`place` object:**
- `name` (string) — place or nearest place
- `state` (string) — state abbreviation (may be empty for non-US)
- `country` (string) — ISO-3166 two-letter country code

**`profile` object:**
- `tz` (string) — IANA timezone
- `isSmallPoly` (boolean) — small polygon alert (tornadoes, severe tstorms)

**`includes` object (US/CA only):**
- `fips` — US county FIPS codes
- `counties` — US county codes
- `wxzones` — NWS zones (US) or Canadian Location Codes (CA)
- `zipcodes` — affected US zip codes

**`localLanguages` array (international):**
- `language` (string) — ISO 639 two-letter code
- `name` (string) — **native-language alert name** (e.g., "Vigilance jaune orages")
- `body` (string) — native-language description

**`geoPoly`** — GeoJSON polygon boundary (when available)

### 2.2 `dataSource` values

| `dataSource` | Source System | Geographies |
|---|---|---|
| `noaa_nws` | US National Weather Service | US + territories + adjacent marine |
| `envca` | Environment Canada | Canada |
| `meteoalarm` | MeteoAlarm (pan-European) | EU member states (Météo-France, DWD, AEMET, KNMI, etc.) |
| `ukmet` | UK Met Office | United Kingdom |
| *(undocumented)* | JMA | Japan — confirmed via live API (country `"jp"`) |
| *(undocumented)* | BoM | Australia — confirmed via live API (country `"au"`) |
| *(undocumented)* | Unknown | India, Brazil, South Africa, South Korea, Mexico — listed in coverage, no documented `dataSource` values |

### 2.3 Type code format

**US/Canadian alerts — NWS VTEC format:**
Format: `XX.Y` where `XX` = hazard code, `Y` = severity suffix.

| Suffix | NWS Tier | Our Mapping |
|---|---|---|
| `.W` | **Warning** | Highest severity |
| `.A` | **Watch** | Elevated severity |
| `.Y` | **Advisory** | Lower severity |
| `.S` | **Statement** | Informational |

171 US/CA alert types documented. Complete list at
[Xweather Alert Types](https://www.xweather.com/docs/maps/reference/alert-types)
and captured at `C:\tmp\Alert Types - Raster Maps - Xweather.htm`.

**International alerts — Aeris unified format:**
Format: `AW.XX.YY` where `AW` = "Aeris Warning" prefix, `XX` = hazard code, `YY` = severity suffix.

| Suffix | Aeris Label | Aeris Description |
|---|---|---|
| `.EX` | Extreme | Highest severity |
| `.SV` | Severe | Elevated severity |
| `.MD` | Moderate | Moderate severity |
| `.MN` | Minor | Lowest severity |

33 international hazard codes, each available at all 4 severity levels (132 types total + `AW.UK.S` statement):

| Code | Hazard | Code | Hazard |
|---|---|---|---|
| AV | Avalanche | LI | Lightning |
| BZ | Blizzard | LT | Low Temperature |
| CE | Coastal Event | RA | Rain |
| DR | Drought | RC | Hazardous Road Conditions |
| DS | Dust Storm | RF | Rain Flood |
| EQ | Earthquake | SH | Sheep Grazing |
| FF | Flash Flood | SI | Snow or Ice |
| FG | Fog | SP | Special Weather |
| FL | Flood | SQ | Squall |
| FO | Forest Fire | SS | Storm Surge |
| FR | Frost | TI | Tropical Storm (alternate) |
| FS | Freezing Spray | TO | Tornado |
| FW | Fire Weather | TR | Tropical Storm |
| HL | Hail | TS | Thunderstorm |
| HT | High Temperature | UK | Unknown |
| IB | Iceberg | VO | Volcanic Activity |
|  |  | WI | Wind |

**Aeris applies this SAME `AW.XX.YY` scheme to ALL international sources** — MeteoAlarm,
UK Met Office, JMA, BoM, and the other covered countries. The original national system's
severity labels are normalized into the 4-level `.EX`/`.SV`/`.MD`/`.MN` suffix scheme.

### 2.4 `localLanguages` — native severity labels

This field is the key to recovering the source system's native terminology. Aeris provides
translations of the alert name in both the source language and English.

**Live example — France MeteoAlarm thunderstorm alert (2026-06-01):**
```json
"localLanguages": [
  {"language": "fr", "name": "Vigilance jaune orages", "body": "Des phénomènes habituels..."},
  {"language": "en", "name": "Moderate thunderstorm warning", "body": "Moderate damages may occur..."}
]
```

The French name **"Vigilance jaune"** = **Yellow** in Météo-France's system.
The Aeris type code is `AW.TS.MD` (Moderate).
This confirms: **Météo-France Yellow → Aeris `.MD` (Moderate)**.

### 2.5 `details.color` — NOT the national system's color

The hex color (e.g., `"FF7000"` = orange for the French Yellow alert) is **Aeris's own rendering
color** for their map products. It does NOT correspond to MeteoAlarm's awareness colors, UK Met
Office's warning colors, or any other national system's color scheme. Do not use this field to
infer the source system's severity classification.

---

## 3. OpenWeatherMap — Detailed Wire Format

**Source:** [OWM One Call 3.0](https://openweathermap.org/api/one-call-3) +
[OWM Push Weather Alerts](https://openweathermap.org/api/push-weather-alerts).

### 3.1 One Call 3.0 / 4.0 — alerts

**One Call 4.0 exists** (One Call 2.5 was deprecated June 2024) but does NOT improve alert
data quality. 4.0 changes the structure (alerts referenced by ID, fetched via a dedicated
`/data/4.0/onecall/alert/{alert_id}` endpoint instead of embedded in the response) but
provides the **same 5 core fields** minus `tags`. Still no severity field.

Our provider currently uses 3.0. Upgrading to 4.0 may be worthwhile for forecasts (15-minute
resolution, 47-year history) but is irrelevant for alerts.

**One Call 3.0 alert entry (6 fields):**

| Field | Type | Required | Description |
|---|---|---|---|
| `sender_name` | string | No | Source agency name (e.g., "NWS Tulsa (Eastern Oklahoma)", "UK Met Office") |
| `event` | string | **Yes** | Agency's natural-language event name |
| `start` | int | **Yes** | Epoch UTC seconds, alert start |
| `end` | int | No | Epoch UTC seconds, alert expiry |
| `description` | string | No | Alert body text |
| `tags` | string[] | No | Hazard type tags (e.g., `["Wind"]`, `["Tornado"]`). NOT severity. |

**No severity, urgency, certainty, areaDesc, or category fields.**

**Language:** "National weather alerts are provided in English by default" but "some agencies
provide the alert's description only in a local language." Event strings from non-English
agencies may be in the native language.

**Coverage:** 100+ countries with national meteorological agencies. Full list in OWM docs.

### 3.2 Push Weather Alerts API — richer alternative

**Separate OWM product** (requires email request for access). Provides push notifications with
**significantly richer data** than One Call 3.0:

| Field | Values | Notes |
|---|---|---|
| `severity` | Extreme, Severe, Moderate, Minor, Unknown | **CAP-style severity — absent in One Call 3.0** |
| `urgency` | Immediate, Expected, Future, Past, Unknown | **Absent in One Call 3.0** |
| `certainty` | Observed, Likely, Possible, Unlikely, Unknown | **Absent in One Call 3.0** |
| `headline` | string | Separate from event name. **Absent in One Call 3.0** |
| `instruction` | string | Agency instructions. **Absent in One Call 3.0** |
| `language` | string | Alert language identifier |
| `sender` | string | Source agency |
| `geometry` | GeoJSON | Polygon/MultiPolygon alert area |

**195+ countries** (vs One Call 3.0's ~100).

Likely shares the same underlying data source as One Call 3.0. If accessible, this would
provide proper severity data for all supported countries — solving the One Call 3.0 gap.

### 3.3 OWM Country Coverage (One Call 3.0 — confirmed)

100+ countries including: Albania, Algeria, Argentina, Australia, Austria, Bahrain, Barbados,
Belarus, Belgium, Belize, Benin, Bosnia and Herzegovina, Botswana, Brazil, Bulgaria, Cameroon,
Canada, Chile, Congo, Costa Rica, Croatia, Curacao, Cyprus, Czech Republic, Denmark, Ecuador,
Egypt, Estonia, Eswatini, Finland, France (Meteo-France), Gabon, Germany (DWD), Ghana, Greece,
Guinea, Guyana, Hong Kong, Hungary, Iceland, India (IMD), Indonesia, Ireland (Met Eireann),
Israel, Italy, Ivory Coast, Jamaica, Japan (JMA), Jordan, Kazakhstan, Kenya, Kuwait, Latvia,
Lesotho, Libya, Lithuania, Luxembourg, Macao, Madagascar, Malawi, Maldives, Mauritania,
Mauritius, Mexico (CONAGUA), Moldova, Mongolia, Mozambique, Myanmar, Netherlands (KNMI),
New Zealand, Niger, Nigeria, North Macedonia, Norway, Paraguay, Philippines, Poland, Portugal,
Qatar, Republic of Korea (KMA), Romania, Russia, Saudi Arabia, Serbia, Seychelles, Singapore,
Slovakia, Slovenia, Solomon Islands, South Africa (SAWS), Spain (AEMET), Sudan, Sweden,
Switzerland (MeteoSwiss), Tanzania, Thailand, Timor-Leste, Trinidad and Tobago, Ukraine,
UAE, UK (Met Office), Uruguay, USA (NWS), Uzbekistan, Yemen, Zambia, Zimbabwe.

---

## 4. NWS Direct — Detailed Wire Format

**Source:** [NWS API](https://www.weather.gov/documentation/services-web-api) +
`repos/weewx-clearskies-api/providers/alerts/nws.py`.

### 4.1 Field inventory (CAP format via GeoJSON)

| Field | Type | Description |
|---|---|---|
| `id` | string | Alert identifier |
| `severity` | string | **CAP severity: Extreme, Severe, Moderate, Minor, Unknown** — separate from tier |
| `urgency` | string | Immediate, Expected, Future, Past, Unknown |
| `certainty` | string | Observed, Likely, Possible, Unlikely, Unknown |
| `event` | string | Event name **containing the tier**: "Tornado **Warning**", "Flash Flood **Watch**", "Wind **Advisory**" |
| `headline` | string | Full headline text |
| `description` | string | Alert body |
| `instruction` | string | Recommended actions |
| `effective` | string | ISO-8601 start time |
| `expires` | string | ISO-8601 expiry |
| `senderName` | string | Issuing NWS office |
| `areaDesc` | string | Affected geographic area |
| `category` | string | Alert category |

### 4.2 NWS three-tier system (Warning / Watch / Advisory)

The NWS three-tier system is encoded in the **event name**, NOT the CAP severity field:

| Tier | Meaning | VTEC Suffix | Example Events |
|---|---|---|---|
| **Warning** | Hazardous weather occurring or imminent. Take action. | `.W` | Tornado Warning, Hurricane Warning, Flash Flood Warning |
| **Watch** | Conditions favorable for hazardous weather. Be prepared. | `.A` | Tornado Watch, Hurricane Watch, Flash Flood Watch |
| **Advisory** | Weather conditions that cause inconvenience but aren't life-threatening if precautions taken. | `.Y` | Wind Advisory, Heat Advisory, Dense Fog Advisory |
| **Statement** | Informational, follow-up information. | `.S` | Special Weather Statement, Severe Weather Statement |

The **CAP severity field** (Extreme/Severe/Moderate/Minor/Unknown) is a **separate dimension**
from the tier. A "Tornado Warning" can be CAP "Extreme" or "Severe" depending on the
situation. These are NOT the same thing.

---

## 5. National Alert Classification Systems

### 5.1 United States — NWS (National Weather Service)

- **Agency:** NOAA National Weather Service
- **System:** 3 tiers + Statement
- **Tiers:** Warning → Watch → Advisory → Statement
- **Language:** English
- **Coverage via:** NWS direct, Aeris (`dataSource: "noaa_nws"`), OWM

### 5.2 Canada — Environment Canada

- **Agency:** Environment and Climate Change Canada
- **System:** 3 tiers + Special Weather Statement
- **Tiers:** Warning → Watch → Advisory → Special Weather Statement
- **Language:** English + French (bilingual)
- **Coverage via:** Aeris (`dataSource: "envca"`), OWM

### 5.3 Europe — MeteoAlarm (pan-European)

- **Agency:** EUMETNET (aggregates 38 national meteorological services)
- **System:** 4 awareness levels with colors
- **Tiers:**

| Level | Color | Meaning | Expected Action |
|---|---|---|---|
| 4 | **Red** | Very dangerous. Exceptionally intense phenomena. Major damage/threat to life. | Take immediate action |
| 3 | **Orange** | Dangerous. Unusual phenomena. Damage and casualties likely. | Be prepared, take precautions |
| 2 | **Yellow** | Potentially dangerous. Not unusual but occasionally locally dangerous. | Be aware, check forecasts |
| 1 | **Green** | No particular awareness required. | No action needed |

- **Language:** Multiple; each national service provides alerts in their own language
- **Coverage via:** Aeris (`dataSource: "meteoalarm"`), OWM
- **National services feeding MeteoAlarm:** Météo-France, DWD (Germany), AEMET (Spain),
  KNMI (Netherlands), Met Éireann (Ireland), SMHI (Sweden), FMI (Finland), IMGW (Poland),
  CHMI (Czech Republic), OMSZ (Hungary), ARSO (Slovenia), DHMZ (Croatia), and ~25 others.

### 5.4 United Kingdom — Met Office

- **Agency:** UK Met Office
- **System:** 3 warning levels with colors (no Green/informational level)
- **Tiers:**

| Level | Color | Meaning | Expected Action |
|---|---|---|---|
| 3 | **Red** | Danger to life. Significant disruption. Extreme conditions. | Take immediate action to stay safe |
| 2 | **Amber** | Increased likelihood of significant impacts. Risk to life/property. | Adjust plans, take precautions |
| 1 | **Yellow** | Low-level impacts possible. Minor disruption OR higher impacts with lower certainty. | Be aware, check details |

- **Language:** English
- **Matrix:** UK Met Office uses a **likelihood × impact matrix** to determine color level
- **Coverage via:** Aeris (`dataSource: "ukmet"`), OWM
- **Note:** Met Office issues alerts for today + next 4 days

### 5.5 Japan — JMA (Japan Meteorological Agency)

- **Agency:** Japan Meteorological Agency (気象庁)
- **System:** 5 levels (overhauled May 2026)
- **Tiers:**

| Level | Japanese | English | Expected Action |
|---|---|---|---|
| 5 | 特別警報 (Black) | Emergency Warning | Disaster already occurring or imminent |
| 4 | (Purple) | Urgent Warning | Evacuate immediately |
| 3 | 警報 (Red) | Warning | Elderly evacuate; others prepare |
| 2 | (Yellow) | Advisory | Check evacuation procedures |
| 1 | 注意報 | Advisory | Be aware |

- **Language:** Japanese (English translations available)
- **Coverage via:** Aeris (confirmed via live API, country `"jp"`), OWM
- **Live API evidence (2026-06-01):** Tokyo returned `AW.EQ.MN` (Minor Earthquake), country `"jp"`

### 5.6 Australia — BoM (Bureau of Meteorology)

- **Agency:** Australian Bureau of Meteorology
- **System:** Varies by hazard type; thunderstorms use 2 tiers (Severe / Very Dangerous)
- **Tiers (general):**

| Level | Label | Expected Action |
|---|---|---|
| 4 | Severe Warning (or "Very Dangerous") | Take immediate emergency action; SEWS triggered |
| 3 | Warning | Take precautions, shelter |
| 2 | Watch | Be prepared, stay informed |
| 1 | Advice | Be aware |

- **Language:** English
- **Coverage via:** Aeris (confirmed via live API, country `"au"`, state `"au.ns"`), OWM
- **Live API evidence (2026-06-01):** Sydney returned `AW.WI.MD` (Moderate Wind), country `"au"`, state `"au.ns"`

### 5.7 India — IMD (India Meteorological Department)

- **Agency:** India Meteorological Department (Ministry of Earth Sciences)
- **System:** 4 color-coded levels
- **Tiers:**

| Level | Color | Label | Expected Action |
|---|---|---|---|
| 4 | **Red** | Take Action | Extremely bad weather; significant risk to life |
| 3 | **Orange/Amber** | Be Prepared | Extremely bad weather expected; disruption likely |
| 2 | **Yellow** | Be Aware | Severely bad weather over several days |
| 1 | **Green** | All is Well | No advisory |

- **Language:** English + Hindi
- **Coverage via:** Aeris (listed in coverage), OWM (IMD listed as agency)

### 5.8 Brazil — INMET (National Institute of Meteorology)

- **Agency:** Instituto Nacional de Meteorologia
- **System:** 4 color-coded levels
- **Tiers:**

| Level | Color | Portuguese | English | Expected Action |
|---|---|---|---|---|
| 4 | **Red** | Grande Perigo | Great Danger | Severe damage expected |
| 3 | **Orange** | Perigo | Danger | Significant material damage and life risk |
| 2 | **Yellow** | Atenção | Attention | Potentially dangerous; stay vigilant |
| 1 | **Gray** | (information) | (information) | Dense fog, low humidity — no immediate risk |

- **Language:** Portuguese
- **Coverage via:** Aeris (listed), OWM (INMET listed)

### 5.9 South Africa — SAWS

- **Agency:** South African Weather Service
- **System:** Impact-Based (1–10 numeric scale mapped to 3 color bands)
- **Tiers:**

| Level | Range | Color | Expected Action |
|---|---|---|---|
| 4 | 9–10 | **Red** | Severe impact, high likelihood. Disaster-level. |
| 3 | 5–8 | **Orange** | Significant disruptions. Moderate to high impact. |
| 2 | 3–4 | **Yellow** | Low to moderate impact. Minor disruptions. |
| 1 | 1–2 | **Yellow** | Minimal impact likely. |

- **Language:** English / Afrikaans
- **Coverage via:** Aeris (listed), OWM (SAWS listed)

### 5.10 South Korea — KMA (Korea Meteorological Administration)

- **Agency:** Korea Meteorological Administration (기상청)
- **System:** 4 color-coded levels (overhauled June 2026)
- **Tiers:**

| Level | Color | Expected Action |
|---|---|---|
| 4+ | **(Extreme)** | Extreme Heat Emergency (new 2026): perceived temp ≥38°C |
| 4 | **Red** | Serious emergency |
| 3 | **Orange** | Higher alert |
| 2 | **Yellow** | Caution advised |
| 1 | **Green** | No warning |

- **Language:** Korean (English available)
- **Coverage via:** Aeris (listed), OWM (KMA listed)

### 5.11 Mexico — CONAGUA/SMN

- **Agency:** Servicio Meteorológico Nacional (under CONAGUA)
- **System:** 5 color-coded levels
- **Tiers:**

| Level | Color | Spanish | English | Expected Action |
|---|---|---|---|---|
| 5 | **Purple** | Púrpura | Purple | Rarely recorded intensity; severe damage |
| 4 | **Red** | Rojo | Red | Direct damage to buildings; 50-70mm rain |
| 3 | **Orange** | Naranja | Orange | Capable of damaging fragile structures |
| 2 | **Yellow** | Amarillo | Yellow | Light hazards; water puddles possible |
| 1 | **Green** | Verde | Green | Average rainfall; constant monitoring |

- **Language:** Spanish
- **Coverage via:** Aeris (listed), OWM (CONAGUA listed)

---

## 6. Cross-Mapping: Aeris Suffix → Native Severity Label

Aeris normalizes all international alerts into a 4-level suffix scheme. This table maps each
suffix back to the source system's native terminology, informed by live API data and the
national system documentation.

**Verified via live API (2026-06-01):** Météo-France "Vigilance **jaune**" (Yellow) →
Aeris `.MD` (Moderate). This confirms the Yellow → `.MD` mapping for MeteoAlarm.

| Aeris Suffix | Aeris Label | NWS (US/CA) | MeteoAlarm (EU) | UK Met Office | JMA (Japan) | BoM (Australia) | IMD (India) | INMET (Brazil) | SAWS (S. Africa) | KMA (Korea) | SMN (Mexico) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `.S` | Statement | Statement | — | — | — | — | — | — | — | — | — |
| `.Y` | Advisory | Advisory | — | — | — | — | — | — | — | — | — |
| `.MN` | Minor | — | Green (no alert) | — | Level 1 Advisory | Advice | Green | Gray | Level 1-2 (Yellow) | Green | Verde (Green) |
| `.MD` | Moderate | — | **Yellow** ✓ | **Yellow** | Level 2 Advisory | Watch | Yellow | Yellow (Atenção) | Level 3-4 (Yellow) | Yellow | Amarillo (Yellow) |
| `.SV` | Severe | — | **Orange** | **Amber** | Level 3 Warning | Warning | Orange | Orange (Perigo) | Level 5-8 (Orange) | Orange | Naranja (Orange) |
| `.EX` | Extreme | — | **Red** | **Red** | Level 4-5 Urgent/Emergency | Severe/Very Dangerous | Red | Red (Grande Perigo) | Level 9-10 (Red) | Red | Rojo/Púrpura (Red/Purple) |

**Key:** ✓ = confirmed by live API data. Others are inferred from system documentation.

**US/Canadian alerts use VTEC suffixes (`.W`/`.A`/`.Y`/`.S`), not the international scheme.**

**Important caveats:**
- The `.MN` → Green/informational mapping is assumed; Green/informational-level alerts may not
  be issued in practice (most systems only issue alerts at Yellow and above).
- Japan's 5-level system (post-May 2026 overhaul) maps to 4 Aeris levels — Levels 4 and 5
  likely both map to `.EX`.
- Mexico's 5-level system also compresses: Purple (highest) and Red likely both map to `.EX`.
- South Africa's 10-level numeric scale compresses significantly into 4 levels.
- These mappings are Aeris's responsibility — we trust their normalization but should verify
  with real international alert data when available.

---

## 7. Cross-Mapping: OWM → Severity

OWM One Call 3.0 provides **no severity field**. Our current approach (English keyword substring
matching on `event`) is fundamentally broken for non-US alerts:

| Scenario | Event String | Keyword Match | Result | Correct? |
|---|---|---|---|---|
| NWS Wind Advisory | "Wind Advisory" | "advisory" | advisory | ✓ |
| NWS Tornado Warning | "Tornado Warning" | "warning" | warning | ✓ |
| UK Met Yellow Warning | "Yellow Warning for Rain" | "warning" | warning | **✗** (should be lowest UK tier) |
| UK Met Red Warning | "Red Warning for Snow" | "warning" | warning | ✓ (by accident) |
| Météo-France (French) | "Avertissement de tempête" | no match | advisory | **✗** (unknown severity) |
| JMA (Japanese) | "大雨警報" | no match | advisory | **✗** (unknown severity) |

**Decision: OWM alerts are passthrough-only.**

OWM lacks structured severity data. Rather than guessing severity from keyword matching
(which produces wrong results for non-US alerts), OWM alerts are passed through to the
operator as-is:
- Event text, description, sender name displayed verbatim
- Generic `ph:warning` icon (no hazard-specific icon)
- Neutral alert glass (no severity-specific color treatment)
- `role="status"` ARIA (no assertive `role="alert"`)
- No severity label, no severity level

This is an honest representation of the data quality. Operators choosing OWM for alerts
should understand they get **informational passthrough, not classified alerts**. The
operator documentation must make this tradeoff explicit: Aeris and NWS direct provide
classified, severity-aware alerts; OWM provides raw passthrough.

**Future path: direct national provider modules.** The long-term solution for full-quality
global alerts is direct integrations with national meteorological services (Met Office API,
JMA API, BoM API, IMD API, etc.) per ADR-038's provider module pattern. Each would be a
new-module PR that delivers native severity data without depending on Aeris as an
intermediary. Highest-impact candidates (based on likely operator locations and Aeris
coverage gaps):
- **Met Office** (UK) — already an Aeris `dataSource`, but a direct integration would
  give us native Yellow/Amber/Red without trusting Aeris's mapping
- **BoM** (Australia) — Aeris coverage confirmed but severity mapping unverified
- **IMD** (India) — Aeris lists coverage but no `dataSource` documented; large user base
- **CONAGUA/SMN** (Mexico) — same situation as India
- **KMA** (South Korea) — same situation

---

## 8. Fields We Currently Discard

Data available from providers that our canonical `AlertRecord` does not capture:

| Field | Provider | What It Contains | Why It Matters |
|---|---|---|---|
| `dataSource` | Aeris | Source system ID (`"meteoalarm"`, `"ukmet"`, etc.) | Identifies which national alert system issued the alert — essential for correct native label rendering |
| `localLanguages[]` | Aeris | Native-language alert name + body (+ English translation) | "Vigilance jaune orages" tells us this is a Météo-France Yellow alert. Without it we only have "MODERATE THUNDERSTORM" |
| `details.color` | Aeris | Hex rendering color | Aeris's own color, but could supplement our rendering |
| `details.bodyFull` | Aeris | Complete unmodified alert text | We only get the shortened `body` |
| `details.cat` | Aeris | Hazard category ("thunderstorm", "fire", etc.) | Maps to hazard type for icon selection |
| `tags[]` | OWM | Hazard type (e.g., `["Wind"]`, `["Tornado"]`) | Dropped because AlertRecord has no field for it |
| `place.country` | Aeris | ISO-3166 country code | Needed to determine which national system's labels to display |
| `profile.tz` | Aeris | IANA timezone | Could supplement station timezone for alert time display |
| `emergency` | Aeris | Boolean flag for emergency-level alerts | Could distinguish a Tornado Emergency from a regular Tornado Warning |

---

## 9. Known Bugs in Current Implementation

### Bug 1: NWS provider uses CAP severity instead of event tier

**File:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/nws.py:119-125`

```python
_NWS_SEVERITY_MAP = {
    "Extreme": "warning",
    "Severe":  "watch",      # BUG: "Tornado Warning" is CAP "Severe" → maps to "watch"
    "Moderate": "advisory",  # BUG: "Flash Flood Watch" is CAP "Moderate" → maps to "advisory"
    "Minor":   "advisory",
    "Unknown": "advisory",
}
```

The NWS three-tier system (Warning/Watch/Advisory) is in the event name. The CAP severity
field is a separate dimension. This mapping produces incorrect results.

**Fix:** Extract the tier from the event name (look for "Warning"/"Watch"/"Advisory" suffix)
or from the VTEC code suffix (`.W`/`.A`/`.Y`/`.S`).

### Bug 2: OWM keyword matching fails for non-US alerts

**File:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/openweathermap.py:118-122`

English keyword matching on `event` collapses UK Met Office Yellow/Amber/Red warnings into
the same tier ("warning") and defaults non-English alerts to "advisory" regardless of actual
severity.

### Bug 3: Canonical model is US-centric

**Files:** ADR-010 (`docs/decisions/ADR-010-canonical-data-model.md`), ADR-016
(`docs/decisions/ADR-016-severe-weather-alerts.md`),
`repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py:773-816`

`AlertRecord.severity` is defined as `advisory | watch | warning` — NWS terminology that does
not represent UK Met Office Yellow/Amber/Red, MeteoAlarm Green/Yellow/Orange/Red, or any other
national system's classification.

---

## 10. Live API Verification (2026-06-01)

### Aeris — Paris, France (MeteoAlarm thunderstorm alert)

```
GET /alerts/48.8566,2.3522
```

```json
{
  "dataSource": "meteoalarm",
  "details": {
    "type": "AW.TS.MD",
    "name": "MODERATE THUNDERSTORM",
    "priority": 71.1,
    "color": "FF7000",
    "cat": "thunderstorm"
  },
  "place": {"name": "ain", "state": "", "country": "fr"},
  "profile": {"tz": "Europe/Paris"},
  "localLanguages": [
    {"language": "fr", "name": "Vigilance jaune orages",
     "body": "Des phénomènes habituels dans la région mais occasionnellement et localement dangereux..."},
    {"language": "en", "name": "Moderate thunderstorm warning",
     "body": "Moderate damages may occur, especially in vulnerable or in exposed areas..."}
  ]
}
```

**Findings:**
- `dataSource: "meteoalarm"` — identifies MeteoAlarm as source system
- `localLanguages[0].name: "Vigilance jaune orages"` — **French Yellow** alert
- `details.type: "AW.TS.MD"` — Aeris maps Yellow → `.MD` (Moderate)
- `details.color: "FF7000"` (orange) — **NOT** the MeteoAlarm Yellow color; it's Aeris's own rendering color
- `place.country: "fr"` — identifies France

### Aeris — Tokyo, Japan (JMA earthquake advisory)

```
GET /alerts/summary/35.6762,139.6503
```

```json
{
  "summary": {
    "count": 1,
    "countries": ["jp"],
    "typeCodes": ["AW.EQ.MN"],
    "types": [{
      "type": "MINOR EARTHQUAKE",
      "code": "AW.EQ.MN",
      "priority": 100.2,
      "color": "#D2B48C",
      "countries": ["jp"]
    }]
  }
}
```

**Findings:**
- Japan uses the same `AW.XX.YY` international scheme
- `AW.EQ.MN` = Minor Earthquake — maps to JMA Level 1 Advisory
- `country: "jp"` confirms geographic identification

### Aeris — Sydney, Australia (BoM wind warning)

```
GET /alerts/summary/-33.8688,151.2093
```

```json
{
  "summary": {
    "count": 1,
    "countries": ["au"],
    "states": ["au.ns"],
    "typeCodes": ["AW.WI.MD"],
    "types": [{
      "type": "MODERATE WIND",
      "code": "AW.WI.MD",
      "priority": 73.1,
      "color": "#E2BA76",
      "countries": ["au"],
      "states": ["au.ns"]
    }]
  }
}
```

**Findings:**
- Australia uses the same `AW.XX.YY` international scheme
- `AW.WI.MD` = Moderate Wind — maps to BoM Watch level
- `country: "au"`, `state: "au.ns"` (New South Wales) confirms geographic identification

### Locations returning no active alerts (2026-06-01)

London, Berlin, Stockholm, NYC, Houston, Phoenix, Miami, Seattle, Oklahoma City,
Mexico City, New Delhi, Cape Town, Seoul, São Paulo — all returned `warn_no_data`
(valid request, no active alerts at query time).

---

## 11. Icon Coverage: Aeris Hazard Codes → Alert Icons

ADR-050 defines 13 alert icon categories. Aeris's international scheme has 33 hazard codes.
This table maps every Aeris hazard code to an icon, identifying gaps that need new icons.

### Current ADR-050 alert icons (13)

| Icon | Phosphor/Cross-pack | Hazard |
|---|---|---|
| `ph:fire` | Phosphor | Fire |
| `ph:hurricane` | Phosphor | Tropical/hurricane |
| `ph:lightning` | Phosphor | Thunderstorm |
| `ph:tornado` | Phosphor | Tornado |
| `ph:warning` | Phosphor | Generic warning |
| `ph:warning-circle` | Phosphor | Generic watch |
| `ph:wind` | Phosphor | Wind |
| `ph:sailboat` | Phosphor | Marine |
| `ph:snowflake` | Phosphor | Snow/winter |
| `ph:thermometer` | Phosphor | Heat & cold |
| `ph:cloud-fog` | Phosphor | Fog |
| `material-symbols:flood-outline-rounded` | Material Symbols (cross-pack) | Flood |
| `carbon:tsunami` | Carbon (cross-pack) | Tsunami |

### Complete mapping: Aeris hazard code → icon

| Aeris Code | Hazard | Icon | Source | Status |
|---|---|---|---|---|
| AV | Avalanche | `material-symbols:landslide` | Material Symbols | **NEW** |
| BZ | Blizzard | `ph:snowflake` | Phosphor | Existing |
| CE | Coastal Event | `ph:sailboat` | Phosphor | Existing (marine) |
| DR | Drought | `ph:warning` | Phosphor | Existing (generic — slow-onset, not immediate weather) |
| DS | Dust Storm | `material-symbols:air` | Material Symbols | **NEW** — air/particulate icon |
| EQ | Earthquake | `material-symbols:earthquake` | Material Symbols | **NEW** — dedicated earthquake glyph |
| FF | Flash Flood | `material-symbols:flood-outline-rounded` | Material Symbols | Existing |
| FG | Fog | `ph:cloud-fog` | Phosphor | Existing |
| FL | Flood | `material-symbols:flood-outline-rounded` | Material Symbols | Existing |
| FO | Forest Fire | `ph:fire` | Phosphor | Existing |
| FR | Frost | `ph:thermometer` | Phosphor | Existing (cold) |
| FS | Freezing Spray | `ph:snowflake` | Phosphor | Existing |
| FW | Fire Weather | `ph:fire` | Phosphor | Existing |
| HL | Hail | `material-symbols:weather-hail` | Material Symbols | **NEW** — dedicated hail glyph |
| HT | High Temperature | `ph:thermometer` | Phosphor | Existing |
| IB | Iceberg | `ph:warning` | Phosphor | Existing (generic — niche hazard) |
| LI | Lightning | `ph:lightning` | Phosphor | Existing |
| LT | Low Temperature | `ph:thermometer` | Phosphor | Existing |
| RA | Rain | `material-symbols:hail` | Material Symbols | **NEW** — `hail` glyph is actually a rain/precipitation icon in Material Symbols |
| RC | Road Conditions | `ph:warning` | Phosphor | Existing (generic — secondary effect, not a weather event) |
| RF | Rain Flood | `material-symbols:flood-outline-rounded` | Material Symbols | Existing |
| SH | Sheep Grazing | `ph:warning` | Phosphor | Existing (generic — very niche) |
| SI | Snow or Ice | `ph:snowflake` | Phosphor | Existing |
| SP | Special Weather | `ph:warning` | Phosphor | Existing (generic) |
| SQ | Squall | `ph:wind` | Phosphor | Existing |
| SS | Storm Surge | `carbon:tsunami` | Carbon | Existing |
| TI | Tropical Storm | `ph:hurricane` | Phosphor | Existing |
| TO | Tornado | `ph:tornado` | Phosphor | Existing |
| TR | Tropical Storm | `ph:hurricane` | Phosphor | Existing |
| TS | Thunderstorm | `ph:lightning` | Phosphor | Existing |
| UK | Unknown | `ph:warning` | Phosphor | Existing (generic) |
| VO | Volcanic Activity | `material-symbols:volcano` | Material Symbols | **NEW** — dedicated volcano glyph |
| WI | Wind | `ph:wind` | Phosphor | Existing |

### US/Canadian VTEC hazard codes — additional icons needed

Most US/CA VTEC codes map to the same icons above. Additional gaps specific to US events:

| VTEC Hazard | Icon | Source | Status |
|---|---|---|---|
| Extreme Wind | `ph:wind` | Phosphor | Existing |
| Storm Surge | `carbon:tsunami` | Carbon | Existing |
| Cyclone / Typhoon | `ph:hurricane` | Phosphor | Existing — cyclone/typhoon/hurricane are the same phenomenon named by region |

### Summary of new icons needed

**5 new icons** (all Material Symbols cross-pack) to cover all 33 international hazard codes:

| Icon | Codepoint | Used For |
|---|---|---|
| `material-symbols:earthquake` | `f64f` | Earthquake (EQ) |
| `material-symbols:volcano` | `ebda` | Volcanic Activity (VO) |
| `material-symbols:weather-hail` | `f67f` | Hail (HL) |
| `material-symbols:landslide` | `ebd7` | Avalanche (AV) |
| `material-symbols:air` | `efd8` | Dust Storm (DS) |

Cyclone/typhoon uses existing `ph:hurricane` — same phenomenon, regional naming only.
Drought and Road Conditions use generic `ph:warning` — not immediate weather events.

For Rain (RA), use `material-symbols:hail` (codepoint `e9b1`) — despite the name, this is
the standard Material Symbols rain/precipitation glyph. Alternatively, `ph:cloud-rain`
(available in our Phosphor package) could be used, but ADR-050 reserves `ph:cloud-rain` for
forecast-style icons, not observation/alert icons. This may need an operator decision.

These follow the existing ADR-050 cross-pack precedent: Phosphor as base, Material Symbols
and Carbon for specific glyphs that Phosphor doesn't have.

---

## References

**Provider API documentation:**
- Aeris Alerts endpoint: https://www.xweather.com/docs/weather-api/endpoints/alerts
- Aeris Alerts Summary: https://www.xweather.com/docs/weather-api/endpoints/alerts-summary
- Aeris Alert Types reference: https://www.xweather.com/docs/maps/reference/alert-types
  (captured at `C:\tmp\Alert Types - Raster Maps - Xweather.htm`)
- OWM One Call 3.0: https://openweathermap.org/api/one-call-3
- OWM Push Weather Alerts: https://openweathermap.org/api/push-weather-alerts
- NWS API: https://www.weather.gov/documentation/services-web-api
- NWS VTEC: https://www.weather.gov/vtec/

**National meteorological services:**
- UK Met Office warnings: https://weather.metoffice.gov.uk/guides/warnings
- MeteoAlarm: https://www.meteoalarm.org/
- JMA 2026 update: https://www.jma.go.jp/jma/kishou/know/bosai/keiho-update2026/
- BoM warnings: https://www.bom.gov.au/weather-and-climate/warnings-and-alerts
- IMD colour-coded warnings: https://www.drishtiias.com/daily-updates/daily-news-analysis/imd-colour-coded-warnings
- INMET alerts: https://portal.inmet.gov.br/
- SAWS impact-based warnings: https://www.weathersa.co.za/
- KMA: https://www.kma.go.kr/neng/forecast/warning.do
- Mexico SMN: https://smn.conagua.gob.mx/en/

**Existing project docs:**
- ADR-010: `docs/decisions/ADR-010-canonical-data-model.md` (AlertRecord schema)
- ADR-016: `docs/decisions/ADR-016-severe-weather-alerts.md` (provider set, single-source-per-deploy)
- ADR-038: `docs/decisions/ADR-038-data-provider-module-organization.md` (provider module pattern)
- ADR-050: `docs/decisions/ADR-050-utility-stat-nav-icons.md` (13 alert icon categories)
- Aeris provider: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/aeris.py`
- OWM provider: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/openweathermap.py`
- NWS provider: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/nws.py`
- Aeris captured docs: `docs/reference/api-docs/aeris.md`
- OWM captured docs: `docs/reference/api-docs/openweathermap.md`
