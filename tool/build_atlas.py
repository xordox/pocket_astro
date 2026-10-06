#!/usr/bin/env python3
"""Builds the bundled offline atlas from GeoNames.

Gap G-40. The app shipped with 25 hardcoded cities and an opt-in online
lookup, which meant a chart could only be cast offline for somewhere the
author had thought of. This turns the GeoNames cities15000 dump — every
populated place above 15,000 people — into one compact asset the app can
search without a network.

Source: https://download.geonames.org/export/dump/  (CC BY 4.0)

Output format, one record per line, tab separated:

    name <TAB> region <TAB> lat <TAB> lon <TAB> timezone <TAB> popRank

Coordinates are stored to four decimals — about eleven metres, which is
three orders of magnitude finer than a birth chart can use and keeps the
file a third smaller than full precision. Records are sorted by population
descending so a prefix search can stop early and still return the place
the reader almost certainly meant.

Timezone ids are written as indices into a table at the head of the file,
because the same few hundred ids repeat across 34,000 rows.

Run:  python3 tool/build_atlas.py /tmp/cities15000.txt /tmp/admin1.txt \
          /tmp/countryInfo.txt assets/atlas/cities.txt
"""

import sys
from pathlib import Path


def main(cities_path, admin1_path, country_path, out_path):
    # Country code -> readable name.
    countries = {}
    for line in Path(country_path).read_text(encoding='utf-8').splitlines():
        if line.startswith('#') or not line.strip():
            continue
        parts = line.split('\t')
        if len(parts) > 4:
            countries[parts[0]] = parts[4]

    # "US.CA" -> "California".
    admin1 = {}
    for line in Path(admin1_path).read_text(encoding='utf-8').splitlines():
        parts = line.split('\t')
        if len(parts) >= 2:
            admin1[parts[0]] = parts[1]

    rows = []
    timezones = {}

    for line in Path(cities_path).read_text(encoding='utf-8').splitlines():
        f = line.split('\t')
        if len(f) < 18:
            continue
        name = f[1].strip()
        lat, lon = f[4], f[5]
        country_code = f[8]
        admin_code = f[10]
        population = int(f[14] or 0)
        tz = f[17].strip()
        if not name or not tz:
            continue

        country = countries.get(country_code, country_code)
        state = admin1.get(f'{country_code}.{admin_code}', '')
        # "Pune, Maharashtra, India" reads better than "Pune, 16, IN", but a
        # state that merely repeats the country name is noise.
        if state and state != country:
            region = f'{state}, {country}'
        else:
            region = country

        tz_index = timezones.setdefault(tz, len(timezones))
        rows.append((population, name, region, float(lat), float(lon), tz_index))

    rows.sort(key=lambda r: -r[0])

    out = []
    out.append('\t'.join(sorted(timezones, key=timezones.get)))
    for population, name, region, lat, lon, tz_index in rows:
        out.append(
            f'{name}\t{region}\t{lat:.4f}\t{lon:.4f}\t{tz_index}\t{population}')

    Path(out_path).write_text('\n'.join(out) + '\n', encoding='utf-8')
    print(f'{len(rows)} places, {len(timezones)} timezones, '
          f'{Path(out_path).stat().st_size / 1_000_000:.2f} MB')


if __name__ == '__main__':
    main(*sys.argv[1:5])
