# NOAA Cooperative Observation, CWOP, and weewx "NOAA Reports" — Research Report

Compiled 2026-05-02 to inform the Clear Skies dashboard project's decision on whether to ship its own enhanced NOAA-style report Cheetah template. Every claim is anchored to a current source URL. Anything that could not be verified from a public 2026 source is marked **unverified**.

Scope of the question: a weewx user who is also a CWOP participant (callsign GW2292) wants to know what an authoritative "NOAA monthly/yearly report" is supposed to look like, what weewx ships by default, and what gaps a Clear Skies template should reasonably fill.

---

## 1. The programs — what they are, who runs them, what an operator submits

### 1.1 Cooperative Observer Program (COOP)

- The **NOAA/NWS Cooperative Observer Program (COOP)** is an NWS-run national network of more than 10,000 (mostly volunteer) daily observers reporting at fixed sites. Observers measure max/min temperature, 24-hour precipitation, snowfall and snow depth at minimum; many also report evaporation, soil temperatures, river stage, and other elements. It is the backbone of the U.S. long-period climate record. — [NWS COOP overview](https://www.weather.gov/coop/overview), [NCEI COOP product page](https://www.ncei.noaa.gov/products/land-based-station/cooperative-observer-network)
- Operators are recruited and equipped by their local NWS Weather Forecast Office (WFO). Submission is daily; records flow either by paper form mailed monthly, by IV-ROCS (telephone), or — in the modern era — through **WxCoder**, a web-based entry system (see §2). — [NWS Become An Observer](https://www.weather.gov/coop/BecomeAnObserver), [NWS COOP Forms](https://www.weather.gov/coop/Forms)
- COOP is a **station-of-record** program. Once a COOP site is established (via WS Form B-43, "Request for Establishment or Change in status of Cooperative Station"), the data is treated as part of the official NCEI archive. — [COOP Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment)

### 1.2 Citizen Weather Observer Program (CWOP)

- **CWOP** is a separate program that ingests data from privately-owned automated weather stations. It is **not** part of COOP — different governance, different data path, different downstream consumers. Operationally CWOP feeds into NOAA's **MADIS** (Meteorological Assimilation Data Ingest System) as one of many ingest sources. — [MADIS CWOP page](https://madis.ncep.noaa.gov/madis_cwop.shtml), [Wikipedia: CWOP](https://en.wikipedia.org/wiki/Citizen_Weather_Observer_Program)
- CWOP originated among amateur-radio APRS operators and is operationally tied to APRS-IS. The findU server (run historically by Steve Dimse, K4HG) acts as the relay between APRS-IS and MADIS, FTPing batches to MADIS at regular intervals. — [Wikipedia: CWOP](https://en.wikipedia.org/wiki/Citizen_Weather_Observer_Program), [wxqa.com main site](http://wxqa.com/), [CWOP Guide PDF (Gladstonefamily)](https://weather.gladstonefamily.net/CWOP_Guide.pdf)
- Stated CWOP mission includes giving feedback to contributors via QC reports so they can improve data quality — i.e. it's not strictly one-way. CWOP/MADIS publishes per-station QC pages (e.g. on wxqa.com and gladstonefamily.net) where operators can see how their station compares to neighbors. — [MADIS CWOP page](https://madis.ncep.noaa.gov/madis_cwop.shtml), [CWOP Data Quality Results](http://wxqa.com/aprswxnetqc.html)
- CWOP data are quality-controlled inside MADIS (temporal/spatial consistency checks, QC flags) and then made available to NWS forecast offices, NCEI, NOHRSC, universities, and private redistributors. — [MADIS CWOP page](https://madis.ncep.noaa.gov/madis_cwop.shtml)

### 1.3 Are COOP and CWOP related?

Conceptually they're both "NOAA-adjacent volunteer observation programs" — but **the label "COOP/CWOP" is not technically meaningful**:

| | COOP | CWOP |
|---|---|---|
| Run by | NWS / WFO field offices | Volunteer-run, ingested by MADIS (NCEP) |
| Station class | Station of record (fixed siting standards) | Personal weather station, no official siting requirement |
| Submission cadence | Daily (fixed observation time) | Every 5–15 min (automated) |
| Submission path | Paper B-91 → WFO; or WxCoder; or IV-ROCS | APRS-IS → findU → MADIS |
| Goes into climate record? | Yes, NCEI of-record | Not in the of-record climate archive (used in models, MesoNet, public web tools) |
| Sources | [weather.gov/coop](https://www.weather.gov/coop/overview), [NCEI COOP](https://www.ncei.noaa.gov/products/land-based-station/cooperative-observer-network) | [MADIS CWOP](https://madis.ncep.noaa.gov/madis_cwop.shtml), [wxqa.com](http://wxqa.com/) |

A weewx user can be a CWOP participant without ever touching COOP, and vice-versa. The user in question (callsign GW2292) is a CWOP participant — that means MADIS-bound APRS packet flow, **not** B-91 monthly forms.

### 1.4 Other relevant programs

- **CoCoRaHS — Community Collaborative Rain, Hail and Snow Network.** Volunteer precipitation network using a standard manual gauge. Daily precipitation report (rain/snow water equivalent, snowfall, snow depth) submitted via the CoCoRaHS website or mobile app. Also separate hail and "significant weather" reports. Independent nonprofit, NOAA-supported. — [cocorahs.org](https://www.cocorahs.org/), [NOAA Climate.gov CoCoRaHS](https://www.climate.gov/teaching/climate-youth-engagement/case-studies/cocorahs-%E2%80%94-community-collaborative-rain-hail-and)
- **GLOBE Program** — global student/educator observation network. Out of scope for a single-station PWS reporting question. — *unverified relevance*
- **MesoWest / Synoptic** — academic redistributor that consumes MADIS+CWOP data; relevant only for downstream awareness. — *not a separate submission program*
- **AWOS / ASOS** — *not* volunteer programs; these are FAA/NWS automated stations and are the source of NCEI's LCD products (see §5). Cooperative observers do **not** submit to LCD.

---

## 2. The forms — what each contains and current status

This is the messy area where a lot of training-data confusion lives. The authoritative current list is at [NWS COOP Forms](https://www.weather.gov/coop/Forms) and [Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment).

| Form | Title | Who fills out | Status (2026) | Source |
|---|---|---|---|---|
| **WS Form B-91** | "Record of River and Climatological Observations" | COOP observer | **Active** — primary monthly submission. Records daily max/min temperature, precipitation, snowfall, snow depth, river stage where applicable. Available digitally via WxCoder. | [COOP Forms](https://www.weather.gov/coop/Forms), [COOP Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment) |
| **WS Form B-92** | "Record of Evaporation and Climatological Observations" | COOP observer (sites with evaporation pans) | **Active** | [COOP Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment) |
| **WS Form B-23** | "Cooperative Station Inspection" | NWS field staff (not the observer) | **Active** | [COOP Forms](https://www.weather.gov/coop/Forms) |
| **WS Form B-30** | "Cooperative Agreement with Observer" | Observer signs at enrollment | **Active** | [COOP Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment) |
| **WS Form B-43** | "Request for Establishment or Change in status of Cooperative Station" | NWS, with observer | **Active** | [COOP Forms](https://www.weather.gov/coop/Forms) |
| **WS Form A-1** | "Station Description and Instrument Siting" | NWS / observer | **Active** | [COOP Forms](https://www.weather.gov/coop/Forms) |
| **WS Form A-3** | "Product Description and Distribution" | NWS | **Active** | [COOP Forms](https://www.weather.gov/coop/Forms) |
| **WS Form 79-1D** | Fischer-Porter paper-tape decoding spreadsheet | COOP observer using FPR gauge | **Active** for sites with FPR equipment | [COOP Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment) |
| **NOAA Form 36-14** | "Contract for Observer Reports" | Paid observers | **Active** (administrative, not data) | [COOP Forms](https://www.weather.gov/coop/Forms) |
| **WS Form B-93** | — | — | **Unverified.** Not listed on the current NWS COOP forms index. Possibly never existed under that exact name, or obsolete. | not found at [COOP Forms](https://www.weather.gov/coop/Forms) |
| **NWS-1** | — | — | **Unverified.** Not present on current NWS COOP forms index. Likely obsolete or a misremembered name. | not found |
| **NOWS-1** | — | — | **Unverified.** Not present on current NWS forms index. | not found |
| **CD-3025** | — | — | **Unverified.** "CD-" prefix indicates a Department of Commerce form. Not currently visible on NWS COOP pages. Possibly a legacy paper form for surface observations; cannot confirm from authoritative 2026 sources. | not found |
| **WS Form F-6** (a.k.a. CF-6) | "Preliminary Local Climatological Data" | **NWS WFO**, not a cooperative observer — issued *by* the local Weather Forecast Office for the official ASOS station of record (e.g. an airport). It is a forecast-office product, not an observer submission. | **Active** — produced monthly by every WFO. | [NWS GRR F6 explanation](https://www.weather.gov/grr/climateF6explain), [NWS TAE CF-6 help](https://www.weather.gov/tae/cf6_help) |

**Key clarification on F-6:** F-6 is *not* a COOP observer form. It is the WFO's monthly preliminary climatological data report for the official station of record (the airport ASOS in most cities). The 18 columns are codified — see §5. The reason a lot of weewx-adjacent material conflates "NOAA report" with F-6 is that the F-6 layout (daily rows for a month, columns for max/min/avg/HDD/CDD/precip/snow/wind) is what **looks** most like what weewx generates, even though weewx's default template is loosely styled, not strictly F-6.

### 2.1 WxCoder — what it actually is

- **WxCoder** is the NWS web entry system that has effectively replaced paper B-91 submission for most COOP observers. The current production version is WxCoder 4 (with WxCoder 3 still referenced). Combined with IV-ROCS (telephone entry), it is how COOP observers send daily observations into NCEI's archive. — [WxCoder](https://wxcoder.org/), [NWS WxCoder page (TSA WFO)](https://www.weather.gov/tsa/wxcoder), [WxCoder 4 STAMS](https://stams.wxcoder.org/), [WxCoder3 User's Guide PDF](https://wxcoder.org/media/WxCoder3_Users_Guide.pdf)
- WxCoder produces the digital equivalent of the B-91 monthly form — it is an entry interface, not a separate form. Monthly forms in WxCoder auto-sum/average temperature, precipitation, snowfall. — [NWS TSA WxCoder](https://www.weather.gov/tsa/wxcoder)
- **Relevance for a CWOP participant:** none. WxCoder is for COOP observers. A CWOP-only operator does not interact with WxCoder.

---

## 3. CWOP technical data flow

Authoritative sources: [Gladstonefamily CWOP Guide PDF](https://weather.gladstonefamily.net/CWOP_Guide.pdf), [APRSWXNET info](https://weather.gladstonefamily.net/aprswxnet.html), [MADIS CWOP page](https://madis.ncep.noaa.gov/madis_cwop.shtml).

### 3.1 Submission format

CWOP data is APRS weather packets — there is no separate "CWOP form." Two principal packet types:

- **Position weather report** — APRS data-type indicator `@` or `!`. Carries timestamp, lat/lon, and weather fields.
- **Positionless weather report** — APRS data-type indicator `_`. Carries timestamp + weather fields; position is sent separately in a status packet.

Source: [Gladstonefamily CWOP Guide](https://weather.gladstonefamily.net/CWOP_Guide.pdf).

### 3.2 Fields in a CWOP weather packet

In packet order, per the APRS spec and CWOP Guide:

| Marker | Field | Units / format |
|---|---|---|
| `ddd/` | Wind direction | degrees, 3 digits |
| `sss` | Wind speed (sustained, 1-min or 2-min depending on station) | mph, 3 digits |
| `gNNN` | Wind gust (5-min peak typical) | mph |
| `tNNN` | Temperature | °F (signed), 3 digits |
| `rNNN` | Rainfall last hour (rate proxy) | hundredths of inch |
| `pNNN` | Rainfall last 24 hours | hundredths of inch |
| `PNNN` | Rainfall since local midnight | hundredths of inch |
| `hNN` | Relative humidity | percent (`h00` = 100%) |
| `bNNNNN` | Barometric pressure | tenths of millibar (i.e. value/10 = mbar) |
| `LNNN` / `lNNN` | Solar radiation | W/m² (capital ≤999, lowercase ≥1000) |
| `s` / `S` etc. | Snow (24h) / various | inches; not all stations send |

The first four fields (wind dir, wind speed, gust, temperature) are required; missing values send `...`. Pressure, humidity, rainfall, solar, snow are optional. — [Gladstonefamily CWOP Guide](https://weather.gladstonefamily.net/CWOP_Guide.pdf), [w4ehw CWOP-Main](https://w4ehw.fiu.edu/CWOP-Main.html)

Note: MADIS only ingests two of the three rain fields (`r` rate-equivalent and `p` 24-hour). — confirmed in [Gladstonefamily CWOP Guide](https://weather.gladstonefamily.net/CWOP_Guide.pdf) per search-result quote.

### 3.3 Ingest path

`PWS (e.g. weewx with cwop StdRESTful service)` → `APRS-IS Tier 2 server (cwop.aprs2.net)` → `findU server (run historically by Steve Dimse K4HG)` → FTP every 5 min → `MADIS at NCEP/NOAA` → QC checks → distributed to NWS WFOs, NCEI, NOHRSC, universities, redistributors.

Sources: [MADIS CWOP page](https://madis.ncep.noaa.gov/madis_cwop.shtml), [Wikipedia: CWOP](https://en.wikipedia.org/wiki/Citizen_Weather_Observer_Program).

### 3.4 Reports back to the operator

CWOP/MADIS does provide QC feedback, but **not** as a daily/monthly station summary report. Feedback is in the form of:

- Per-station QC pages on wxqa.com and gladstonefamily.net showing how each station's readings deviate from interpolated neighbors.
- MADIS internal QC flags accessible via MADIS Distribution Services.

There is **no NOAA-issued monthly climatological summary back to a CWOP participant**. If the operator wants such a summary, they must produce it themselves locally — which is exactly what weewx's NOAA template is for. — [MADIS CWOP page](https://madis.ncep.noaa.gov/madis_cwop.shtml), [CWOP Data Quality Results](http://wxqa.com/aprswxnetqc.html)

### 3.5 Relationship between APRS packets and the WS B-91/F-6 forms

**None.** CWOP packets carry near-real-time data from automated stations into MADIS for forecast/model use. WS B-91 captures fixed-time daily observations from a COOP observer's site of record into the NCEI climate archive. F-6 is a WFO-issued summary of the airport ASOS. These are three different document classes from three different data flows. The "NOAA report" naming weewx uses is colloquial — it is not aligned to any of these specific forms.

---

## 4. weewx default NOAA template — exact content

### 4.1 Location in source

In **weewx 5.x** the template files live at:

- `src/weewx_data/skins/Standard/NOAA/NOAA-%Y-%m.txt.tmpl` (monthly)
- `src/weewx_data/skins/Standard/NOAA/NOAA-%Y.txt.tmpl` (yearly)

Verified by direct fetch of the master branch of [github.com/weewx/weewx](https://github.com/weewx/weewx/tree/master/src/weewx_data/skins/Standard/NOAA). The percent-Y / percent-m in the filename is intentional — weewx 5 renamed the files to use strftime codes so that any time format can be substituted (see [issue #415](https://github.com/weewx/weewx/issues/415)).

The Belchertown skin in this repository ships the same templates **byte-identical** to weewx Standard:

- Local: `c:\CODE\weather-belchertown\skins\Belchertown\NOAA\NOAA-YYYY-MM.txt.tmpl`
- Local: `c:\CODE\weather-belchertown\skins\Belchertown\NOAA\NOAA-YYYY.txt.tmpl`

(Belchertown uses `YYYY-MM` filenames rather than weewx 5's `%Y-%m`, but the template body is the same.) The standard template content was confirmed against the upstream weewx master via raw curl fetch.

### 4.2 Monthly template — exact column list

Header row (verbatim from `NOAA-YYYY-MM.txt.tmpl`):

```
                                         HEAT   COOL         AVG
      MEAN                               DEG    DEG          WIND                   DOM
DAY   TEMP   HIGH   TIME    LOW   TIME   DAYS   DAYS   RAIN  SPEED   HIGH   TIME    DIR
```

Per-day columns (13 total):

1. **DAY** — day of month
2. **MEAN TEMP** — daily average outdoor temperature
3. **HIGH** — daily max temperature
4. **TIME** — time of high
5. **LOW** — daily min temperature
6. **TIME** — time of low
7. **HEAT DEG DAYS** — heating degree-days, sum
8. **COOL DEG DAYS** — cooling degree-days, sum
9. **RAIN** — daily total precipitation
10. **AVG WIND SPEED**
11. **HIGH** (wind) — daily peak wind speed
12. **TIME** — time of peak wind
13. **DOM DIR** — vector-mean wind direction for the day

Below the daily table, a single monthly summary row is emitted with the same columns aggregated over the month.

Things conspicuously **absent** from this default template:

- No barometric pressure (no min/max/avg pressure column).
- No humidity (no avg/min/max RH column).
- No dew point.
- No solar radiation, UV.
- No rainfall rate / max-rainfall-rate.
- No snowfall or snow depth.
- No "departure from normal" (because weewx doesn't store climate normals).
- No sunshine, sky cover, ceiling, visibility, weather-type codes (F-6 columns 13–16).
- No peak gust separate from sustained "high" wind.
- No record-tracker (record high/low for date).
- Plain ASCII fixed-width — no HTML, no machine-readable form.

### 4.3 Yearly template — exact column structure

The yearly template `NOAA-YYYY.txt.tmpl` produces three sub-tables.

**Table 1 — Temperature (per month rows):**

```
 YR  MO   MAX    MIN    MEAN  HDD    CDD    HI  DAY    LOW  DAY  >=Hot  <=Cold(max) <=Cold(min) <=VeryCold
```

i.e. monthly mean-of-daily-max, monthly mean-of-daily-min, monthly mean, monthly HDD sum, monthly CDD sum, monthly extreme high (with day), monthly extreme low (with day), and four day-counts: days with max ≥ Hot threshold, days with max ≤ Cold threshold, days with min ≤ Cold threshold, days with min ≤ VeryCold threshold. Thresholds default to (90/32/0 °F) or (30/0/-20 °C).

**Table 2 — Precipitation:**

```
 YR  MO  TOTAL    MAX OBS DAY   DATE   #days >= Trace    #days >= SomeRain    #days >= Soak
```

(Trace = 0.01 in / 0.3 mm; SomeRain = 0.1 in / 3 mm; Soak = 1.0 in / 30 mm.)

**Table 3 — Wind:**

```
 YR  MO    AVG     HI   DATE    DOM DIR
```

Same gaps as the monthly: no pressure, no humidity, no dew point, no snow, no solar, no gust separate from "high," no records, no normals, no F-6 columns.

### 4.4 What is the lineage / "NOAA-style" claim?

The weewx Customization Guide ([Cheetah generator](https://weewx.com/docs/5.2/custom/cheetah-generator/)) describes these as "examples using iteration and explicit formatting." The weewx documentation does **not** claim the template is F-6, B-91, or any specific NWS form. The folder is simply named `NOAA` and the template top-line says `MONTHLY CLIMATOLOGICAL SUMMARY` — generic phrasing. The format closely resembles output from late-1990s/early-2000s shareware weather software (e.g. Weather Display, VWS) and is best described as "tradition," not "standard."

This is worth surfacing for the audit: weewx's "NOAA report" is **not** a real NOAA form. It is a fixed-width ASCII climatological summary in a vintage style. Calling it "NOAA" is a folder-name choice that predates current NWS digital products.

### 4.5 Community alternatives

- **NeoWX-Material** ([github.com/neoground/neowx-material](https://github.com/neoground/neowx-material)) — its own NOAA reports are based on the Standard weewx skin (i.e. same column layout as above).
- **weewx-wdc (Weather Data Center)** ([github.com/Daveiano/weewx-wdc](https://github.com/Daveiano/weewx-wdc)) — likewise inherits NOAA report concepts from Standard/Seasons.
- **Saratoga / Weather34** — use their own report formats but rely on Saratoga template-set data, not on weewx's NOAA folder. — [Saratoga setup](https://saratoga-weather.org/wxtemplates/setup-WeeWX.php)
- **Belchertown** — ships the unmodified Standard NOAA templates (verified against this repo).

I did not find a widely-adopted community NOAA template that adds pressure/humidity/dew point/snow/solar to the daily monthly table. Most operators either accept the default or hand-roll their own. **Unverified** as "comprehensively searched"; this finding is from the github+weewx-user search above, not exhaustive code search.

---

## 5. NCEI / NWS published station-summary products today

### 5.1 F-6 (Preliminary Local Climatological Data) — 18 columns

Issued monthly by NWS WFOs for the airport ASOS station of record. Columns (per [NWS GRR](https://www.weather.gov/grr/climateF6explain) and [NWS TAE](https://www.weather.gov/tae/cf6_help)):

1. **Day** — day of month
2. **Max** — highest temperature
3. **Min** — lowest temperature
4. **Avg** — (Max+Min)/2
5. **Dep.** — departure from 30-year normal for the date
6a. **HDD** — heating degree-days (base 65 °F)
6b. **CDD** — cooling degree-days (base 65 °F)
7. **Water** — total liquid precipitation (in to hundredths)
8. **Snow** — daily snowfall (in to tenths)
9. **Depth** — snow depth at 6/7 AM local
10. **Avg.** — average wind speed (mph)
11. **Speed** — peak 2-minute sustained wind (mph)
12. **Dir** — direction of column-11 wind (compass deg / 10)
13. **Mins.** — minutes of sunshine
14. **%PSBL** — percent of possible sunshine
15. **SR-SS** — average sky cover sunrise–sunset (tenths)
16. **Weather** — coded weather types (1=fog, 2=fog with vis≤¼ mi, 3=thunder, etc.)
17. **Speed** — peak gust (mph)
18. **Dir** — direction of peak gust

Plus a footer with monthly extremes, totals, departures, and a synoptic narrative.

### 5.2 LCD (Local Climatological Data) — NCEI's published product

LCD (now LCDv2) is the **archived, formal** version of climate-summary publications. Coverage:

- Source stations are ASOS / AWOS, plus a small number of international air-base sites. — [NCEI LCD product page](https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data)
- Three sections: Daily Summaries, Hourly Observations, Hourly Precipitation. — [LCD product page](https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data)
- Daily Summary columns include date, max/min/avg temperature, departure from normal, dew point, avg station pressure, avg sea-level pressure, avg wind speed, peak wind speed (2-min sustained), peak gust, sky cover, weather type, wet-bulb, RH, HDD, CDD, precipitation, snowfall, snow depth, sunshine. — [LCD documentation PDF](https://www.ncei.noaa.gov/pub/data/cdo/documentation/LCD_documentation.pdf), [LCDv2 documentation](https://www.ncei.noaa.gov/oa/local-climatological-data/v2/doc/lcdv2_DOCUMENTATION.pdf)
- Monthly summaries: max/min/avg temperature, temperature departure from normal, dew point, avg station pressure, ceiling, visibility, weather type, wet bulb, RH, HDD/CDD, precipitation, avg wind speed, fastest wind speed/direction, sky cover, sunshine, snowfall, snow depth.
- **Important: COOP volunteer stations are NOT LCD stations. CWOP stations are NOT LCD stations.** A PWS operator cannot get an LCD-format publication for their site from NCEI. They can only produce something that *looks like* LCD locally.

### 5.3 Digital interfaces in use in 2026

- **WxCoder 4** at [stams.wxcoder.org](https://stams.wxcoder.org/) — current production. WxCoder 3 ([wxcoder.org](https://wxcoder.org/)) still referenced. — [NWS TSA WxCoder reference](https://www.weather.gov/tsa/wxcoder)
- **IV-ROCS** — telephone fallback for COOP. — [NWS TSA WxCoder reference](https://www.weather.gov/tsa/wxcoder)
- **MADIS Distribution Services** — for CWOP/PWS data consumers. — [MADIS CWOP](https://madis.ncep.noaa.gov/madis_cwop.shtml)
- **WFO daily/monthly CF6 product** — viewable at e.g. [forecast.weather.gov product viewer](https://forecast.weather.gov/product.php?site=NWS&product=CF6&issuedby=NYC).

### 5.4 Free / open formats a PWS operator can locally produce

There is no NOAA-blessed "you can make your own LCD" format. The closest aligned thing is:

- A **F-6-style** monthly grid (18 columns) — possible from a complete weewx archive *if* the station has barometer, RH, dew-point, sunshine sensor, and pyranometer. Without normals, the "Dep." column has no source.
- A **LCDv2-style** daily summary — same constraints; needs sea-level + station pressure, ceiling/vis (impossible for a PWS without an aviation-grade ceilometer), wet-bulb (computable), RH, weather-type codes (impossible for a PWS without a present-weather sensor).

So a PWS-realistic enhanced report can mimic *parts* of F-6 / LCD: the temperature, precipitation, wind, pressure, humidity, dew-point, HDD/CDD, snow if measured, solar if measured. It cannot honestly produce the sunshine/sky-cover/ceiling/visibility/weather-type columns or the departure-from-normal column.

---

## 6. Synthesis — gaps and recommendation for Clear Skies

### 6.1 What's the "right" report for a CWOP participant?

The CWOP participant has **no NOAA-issued report** coming back. The on-station-generated weewx NOAA report is *the* report this operator gets. So the question reduces to: what makes a useful self-generated monthly/yearly summary for someone running a personal weather station?

Anchoring to F-6 (the NWS standard for the airport-class stations) and LCDv2 (the NCEI-archived form) — both of which are the most authoritative templates — the columns most weewx users have data for are:

**Daily monthly grid (PWS-realistic columns):**

- Day
- Temp Max, Min, Avg, Departure (only if the operator stores normals — usually skip)
- HDD, CDD
- Precip total, max rate, hours-of-rain (if available)
- Snowfall, snow depth (if measured)
- Avg wind speed, peak sustained, peak gust, peak gust direction
- Avg / Min / Max barometric pressure (sea-level adjusted)
- Avg / Min / Max RH
- Avg / Min / Max dew point
- Avg solar radiation, peak solar (if pyranometer installed)
- UV index peak (if sensor installed)
- (Optionally) Records broken: high, low, rainfall, gust, etc.

**Monthly yearly grid:** same columns rolled up + yearly extremes + count of "hot/cold/wet/windy" days.

### 6.2 Gaps in the weewx default NOAA template vs. PWS-useful

The default weewx template covers **temperature, HDD/CDD, rain total, wind speed/direction only**. Compared to what a CWOP participant's station already collects:

| Available on most PWS / sent in CWOP packet | In weewx default NOAA report |
|---|---|
| Temperature (max/min/avg) | Yes |
| Humidity | **No** |
| Dew point | **No** |
| Barometric pressure | **No** |
| Rain total | Yes |
| Rain rate | **No** |
| Wind speed avg | Yes |
| Wind gust separate from sustained | **No** (only one "high" column) |
| Wind direction (vector) | Yes |
| Solar radiation | **No** |
| UV | **No** |
| Records broken | **No** |

So roughly half the data the operator already submits to MADIS doesn't appear in their own monthly summary. This is the genuine UX gap.

### 6.3 Should Clear Skies ship its own enhanced template?

**Recommendation: yes, but carefully — and surface the audit.**

**Arguments for shipping a Clear Skies template:**

1. Default weewx NOAA template wastes most of the station's data (see table above). A modernized template is a low-risk, high-value addition.
2. The template is pure Cheetah, no Python — maintenance burden is small.
3. Belchertown today already ships the unchanged Standard templates; replacing them is a strict superset of features.
4. The template is opt-in by file path — operators who want the classic look can drop in the original.

**Arguments against / risks (the audit):**

1. **Naming risk.** Calling it "NOAA report" perpetuates the misnomer. Weewx's NOAA folder isn't actually a NOAA standard. A Clear Skies template that adds pressure/humidity/dew point should probably be honest about this — call it "Climatological Summary" or "Station Summary," not "NOAA Report." This avoids implying NOAA endorsement and avoids implying conformance to F-6 (which would require columns the PWS can't produce).
2. **Departure-from-normal trap.** Don't add a "Dep." column unless Clear Skies also ships a way to set per-day climate normals. Empty/zero "departure" columns are worse than no column.
3. **Format choice.** ASCII fixed-width is fine for legacy/archive but a 2026 dashboard should *also* offer HTML/CSV. Recommend shipping three artifacts per period: `summary-YYYY-MM.txt` (fixed-width, classic), `summary-YYYY-MM.html` (web-viewable), `summary-YYYY-MM.csv` (machine-readable). The Cheetah generator already supports multiple template files per period.
4. **Customizability.** Operators have wildly different sensor sets (no snow, no solar, etc.). The template must gracefully omit missing columns based on `unit.unit_type_dict` / sensor presence — otherwise it'll fill the report with N/A clutter. This is the load-bearing implementation detail.
5. **Drift from upstream.** Once Clear Skies forks the NOAA template, future weewx changes (filename code support, new tag syntax, new aggregation methods) need to be tracked. This is a maintenance tax.
6. **Scope creep.** "Enhanced NOAA template" is the kind of feature that grows: records tracking, plot embedding, PDF export. Pin scope explicitly in the contract — pressure/humidity/dew point/gust/solar-if-present, plus HTML+CSV outputs, **and stop**.
7. **The user is a CWOP participant, not a COOP observer.** Don't ship anything that suggests this report has any role in CWOP submission. CWOP submission is the StdRESTful CWOP service in weewx.conf, completely separate.

**Mitigations:**

- Name it `ClimatologicalSummary` (folder + file name), not `NOAA`. Document the historical misnomer in the skin docs.
- Drop "Dep." until/unless normals support exists.
- Ship three formats (txt fixed-width / html / csv), all driven from a shared partial/macro for column logic.
- Auto-omit pressure/humidity/dew-point/solar/uv/snow columns when the corresponding aggregate is null over the period.
- Explicitly annotate the report header: "Generated locally; not an official NOAA, NWS, or NCEI product."
- Keep the Cheetah template under 200 lines; if it grows, refactor logic into a small Python helper rather than into Cheetah.

### 6.4 Concrete column proposal (for an ADR)

**Daily rows, monthly summary file:**

- Day
- Temp Avg, High, High Time, Low, Low Time
- HDD, CDD
- Mean Dew Point
- Mean RH
- Min Pressure, Max Pressure, Mean Pressure (sea-level)
- Rain Total, Max Rain Rate
- Snow (if column non-empty for any day in period)
- Avg Wind, Peak Sustained, Peak Sustained Time, Peak Gust, Peak Gust Time, Vector Direction
- Solar Radiation Mean, Peak (if non-null)
- UV Peak (if non-null)

**Monthly summary footer:** all of the above aggregated; plus counts of (days with rain, days max ≥ 90 °F, days max ≤ 32 °F, days min ≤ 32 °F, days min ≤ 0 °F, days with measurable snow, days with peak gust ≥ 30 mph).

**Yearly file:** same columns but rows are months instead of days; footer is annual.

This gives a CWOP-participating PWS operator a self-generated summary that uses ~95% of the data their station already records, while staying within the bounds of what the PWS can honestly produce (no ceiling/vis/sunshine/weather-type, no normals).

---

## 7. Things that could not be verified from current authoritative sources

- **WS Form B-93** — not present on [NWS COOP Forms](https://www.weather.gov/coop/Forms) or [Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment) as of 2026-05-02. Status: unverified / likely not in current use under that exact identifier.
- **NWS-1 / NOWS-1** — not present on current NWS COOP forms index. Status: unverified. Possibly historical / superseded.
- **CD-3025** — Department of Commerce form prefix; not on current NWS COOP forms index. Status: unverified.
- **Whether weewx 5 docs explicitly call out which NWS form the NOAA template is modeled on** — searched; no such statement found. The templates are described generically as "examples." Lineage is therefore *not* an NWS-form-derived spec; it is a fixed-width climatological-summary tradition predating the current LCDv2 era.
- **Comprehensive enumeration of community weewx NOAA-template forks** — only sampled (NeoWX-Material, weewx-wdc, Saratoga, Weather34, Belchertown). Not exhaustive.

---

## 8. Source list (deduplicated)

- [NWS COOP overview](https://www.weather.gov/coop/overview)
- [NWS COOP Forms](https://www.weather.gov/coop/Forms)
- [NWS COOP Forms-Manuals-Equipment](https://www.weather.gov/coop/Forms-Manuals-Equipment)
- [NWS Become An Observer](https://www.weather.gov/coop/BecomeAnObserver)
- [NCEI COOP product page](https://www.ncei.noaa.gov/products/land-based-station/cooperative-observer-network)
- [WxCoder](https://wxcoder.org/)
- [WxCoder 4 STAMS](https://stams.wxcoder.org/)
- [NWS TSA WxCoder page](https://www.weather.gov/tsa/wxcoder)
- [WxCoder3 User's Guide PDF](https://wxcoder.org/media/WxCoder3_Users_Guide.pdf)
- [NWS GRR F-6 explanation](https://www.weather.gov/grr/climateF6explain)
- [NWS TAE CF-6 help](https://www.weather.gov/tae/cf6_help)
- [Forecast.weather.gov CF6 product viewer](https://forecast.weather.gov/product.php?site=NWS&product=CF6&issuedby=NYC)
- [NCEI LCD product page](https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data)
- [NCEI LCD documentation PDF](https://www.ncei.noaa.gov/pub/data/cdo/documentation/LCD_documentation.pdf)
- [NCEI LCDv2 documentation PDF](https://www.ncei.noaa.gov/oa/local-climatological-data/v2/doc/lcdv2_DOCUMENTATION.pdf)
- [MADIS CWOP page](https://madis.ncep.noaa.gov/madis_cwop.shtml)
- [Wikipedia: Citizen Weather Observer Program](https://en.wikipedia.org/wiki/Citizen_Weather_Observer_Program)
- [wxqa.com main site](http://wxqa.com/)
- [wxqa.com CWOP info](http://www.wxqa.com/cwop_info.htm)
- [wxqa.com FAQ](http://wxqa.com/faq.html)
- [wxqa.com QC results](http://wxqa.com/aprswxnetqc.html)
- [w4ehw.fiu.edu CWOP-Main](https://w4ehw.fiu.edu/CWOP-Main.html)
- [Gladstonefamily CWOP Guide PDF](https://weather.gladstonefamily.net/CWOP_Guide.pdf)
- [Gladstonefamily APRSWXNET info](https://weather.gladstonefamily.net/aprswxnet.html)
- [CoCoRaHS](https://www.cocorahs.org/)
- [NOAA Climate.gov CoCoRaHS case study](https://www.climate.gov/teaching/climate-youth-engagement/case-studies/cocorahs-%E2%80%94-community-collaborative-rain-hail-and)
- [weewx Customization Guide / Cheetah](https://weewx.com/docs/5.2/custom/cheetah-generator/)
- [weewx GitHub repo](https://github.com/weewx/weewx)
- [weewx issue #415 — filename code support](https://github.com/weewx/weewx/issues/415)
- [NeoWX-Material on GitHub](https://github.com/neoground/neowx-material)
- [weewx-wdc on GitHub](https://github.com/Daveiano/weewx-wdc)
- [Saratoga Weewx setup](https://saratoga-weather.org/wxtemplates/setup-WeeWX.php)
