"""Compare weewx RS vs pvlib Ineichen vs pvlib Simplified Solis at various AOD/PW settings."""

import csv
import pandas as pd
from pvlib.location import Location
from pvlib.clearsky import simplified_solis
from pvlib.solarposition import get_solarposition

# Station coordinates from api.conf
lat = 33.65683
lon = -117.98267
alt = 12.192  # meters
tz = 'America/Los_Angeles'

site = Location(lat, lon, tz, alt)

# Read our existing CSV
rows = []
with open('c:/tmp/kcs-analysis-2026-06-22.csv') as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

# Atmosphere scenarios for Simplified Solis:
# aod700 = aerosol optical depth at 700nm (higher = more haze/pollution)
# precipitable_water = cm of water vapor in column (higher = more humid)
#
# Defaults: aod700=0.1, precipitable_water=1.0
# LA Basin near ocean in summer: higher AOD (smog/marine aerosol), higher PW (humidity)
scenarios = {
    'solis_default':    {'aod700': 0.1,  'precipitable_water': 1.0},
    'solis_la_summer':  {'aod700': 0.15, 'precipitable_water': 3.0},
    'solis_la_hazy':    {'aod700': 0.25, 'precipitable_water': 4.0},
    'solis_la_murky':   {'aod700': 0.35, 'precipitable_water': 5.0},
}

# Header
hdr = '{:<7s} {:>6s} {:>7s} {:>7s}'.format('Local', 'rad', 'weewx', 'inchen')
for name in scenarios:
    short = name.replace('solis_', '')
    hdr += ' {:>8s}'.format(short)
hdr += '  {:>7s} {:>7s}'.format('Kcs_wwx', 'Kcs_ine')
for name in scenarios:
    short = name.replace('solis_', '')
    hdr += ' {:>8s}'.format('K_' + short[:5])
print(hdr)
print('=' * len(hdr))

out_rows = []
for r in rows:
    ts_str = r['timestamp_utc']
    rad = float(r['radiation_wm2'])
    weewx_msr = float(r['maxSolarRad_wm2'])
    local_time = r['local_time_pdt']

    if rad <= 0:
        continue

    dt = pd.Timestamp(ts_str)
    times = pd.DatetimeIndex([dt])

    # Solar position
    solpos = site.get_solarposition(times)
    apparent_elev = float(solpos['apparent_elevation'].iloc[0])

    # Ineichen
    cs_ine = site.get_clearsky(times, model='ineichen')
    ine_ghi = float(cs_ine['ghi'].iloc[0])

    # Simplified Solis with different atmosphere settings
    solis_ghis = {}
    for name, params in scenarios.items():
        cs_sol = site.get_clearsky(times, model='simplified_solis',
                                   solar_position=solpos,
                                   **params)
        solis_ghis[name] = float(cs_sol['ghi'].iloc[0])

    # Kcs values
    kcs_weewx = rad / weewx_msr if weewx_msr > 0 else None
    kcs_ine = rad / ine_ghi if ine_ghi > 0 else None
    kcs_solis = {}
    for name, ghi in solis_ghis.items():
        kcs_solis[name] = rad / ghi if ghi > 0 else None

    # Sample key times
    parts = local_time.replace(':', ' ').split()
    hour = int(parts[0])
    minute = int(parts[1]) if len(parts) > 1 else 0
    show = (minute % 5 == 0) or (hour <= 7 and minute % 2 == 0) or (hour >= 19 and minute % 2 == 0)

    if show:
        def fmt_kcs(k):
            if k is None: return 'n/a'
            if k > 99: return 'INF'
            if k > 2: return '{:.1f}'.format(k)
            return '{:.4f}'.format(k)

        line = '{:<7s} {:>6.1f} {:>7.1f} {:>7.1f}'.format(local_time, rad, weewx_msr, ine_ghi)
        for name in scenarios:
            line += ' {:>8.1f}'.format(solis_ghis[name])
        line += '  {:>7s} {:>7s}'.format(fmt_kcs(kcs_weewx), fmt_kcs(kcs_ine))
        for name in scenarios:
            line += ' {:>8s}'.format(fmt_kcs(kcs_solis[name]))
        print(line)

    out_row = {
        'timestamp_utc': ts_str,
        'local_time': local_time,
        'solar_elevation': round(apparent_elev, 2),
        'radiation_wm2': rad,
        'weewx_maxSolarRad': weewx_msr,
        'pvlib_ineichen_ghi': round(ine_ghi, 2),
    }
    for name, ghi in solis_ghis.items():
        out_row[name + '_ghi'] = round(ghi, 2)
    out_row['kcs_weewx'] = round(kcs_weewx, 4) if kcs_weewx else ''
    out_row['kcs_ineichen'] = round(kcs_ine, 4) if kcs_ine else ''
    for name, k in kcs_solis.items():
        out_row['kcs_' + name] = round(k, 4) if k else ''
    out_rows.append(out_row)

with open('c:/tmp/kcs-solis-comparison-2026-06-22.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=out_rows[0].keys())
    w.writeheader()
    w.writerows(out_rows)

print()
print('Written to c:/tmp/kcs-solis-comparison-2026-06-22.csv')
