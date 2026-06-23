"""Compare weewx Ryan-Stolzenbach maxSolarRad vs pvlib Ineichen clear-sky GHI."""

import csv
import pandas as pd
from pvlib.location import Location

# Station coordinates from api.conf
lat = 33.65683
lon = -117.98267
alt = 12.192  # meters

site = Location(lat, lon, 'America/Los_Angeles', alt)

# Read our existing CSV
rows = []
with open('c:/tmp/kcs-analysis-2026-06-22.csv') as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

print('{:<10s} {:>8s} {:>10s} {:>10s} {:>10s} {:>10s} {:>10s}'.format(
    'Local', 'rad', 'weewx_msr', 'pvlib_ghi', 'Kcs_weewx', 'Kcs_pvlib', 'pvlib/weewx'))
print('=' * 75)

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

    cs = site.get_clearsky(times, model='ineichen')
    pvlib_ghi = float(cs['ghi'].iloc[0])

    kcs_weewx = rad / weewx_msr if weewx_msr > 0 else None
    kcs_pvlib = rad / pvlib_ghi if pvlib_ghi > 0 else None
    ratio = pvlib_ghi / weewx_msr if weewx_msr > 0.01 else None

    # Sample key times
    parts = local_time.replace(':', ' ').split()
    hour = int(parts[0])
    minute = int(parts[1]) if len(parts) > 1 else 0

    show = (minute % 5 == 0) or (hour <= 7) or (hour >= 19)
    if show:
        kw = '{:.2f}'.format(kcs_weewx) if kcs_weewx and kcs_weewx < 100 else 'INF'
        kp = '{:.4f}'.format(kcs_pvlib) if kcs_pvlib else 'n/a'
        rt = '{:.1f}x'.format(ratio) if ratio else 'n/a'
        print('{:<10s} {:>8.1f} {:>10.1f} {:>10.1f} {:>10s} {:>10s} {:>10s}'.format(
            local_time, rad, weewx_msr, pvlib_ghi, kw, kp, rt))

    out_rows.append({
        'timestamp_utc': ts_str,
        'local_time': local_time,
        'radiation_wm2': rad,
        'weewx_maxSolarRad': weewx_msr,
        'pvlib_ghi': round(pvlib_ghi, 2),
        'kcs_weewx': round(kcs_weewx, 4) if kcs_weewx else '',
        'kcs_pvlib': round(kcs_pvlib, 4) if kcs_pvlib else '',
    })

with open('c:/tmp/kcs-pvlib-comparison-2026-06-22.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=out_rows[0].keys())
    w.writeheader()
    w.writerows(out_rows)

print()
print('Written to c:/tmp/kcs-pvlib-comparison-2026-06-22.csv')
