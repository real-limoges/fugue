#!/usr/bin/env python3
"""Rebuild priv/static/menagerie/melbourne_weather.csv from NCEI daily summaries
(ASN00086282 Melbourne Airport: temps + precip) merged with Open-Meteo ERA5
reanalysis wind speed at the same coordinates. 5yr trailing window."""

import csv
import json
import sys
import urllib.request
from datetime import date
from pathlib import Path

OUT = Path("priv/static/menagerie/melbourne_weather.csv")
STATION = "ASN00086282"
LAT = -37.6655
LON = 144.8321
MIN_ROWS = 1500
FIELDS = ["STATION", "DATE", "PRCP", "TAVG", "TMAX", "TMIN", "WSPD_MAX", "WSPD_MEAN"]


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read()


def main() -> int:
    end = date.today()
    start = end.replace(year=end.year - 5)

    ncei_url = (
        "https://www.ncei.noaa.gov/access/services/data/v1"
        f"?dataset=daily-summaries&stations={STATION}"
        f"&startDate={start}&endDate={end}"
        "&dataTypes=TMAX,TMIN,TAVG,PRCP&format=csv&units=metric"
    )
    ncei_rows = list(csv.DictReader(fetch(ncei_url).decode().splitlines()))
    if len(ncei_rows) < MIN_ROWS:
        print(f"NCEI returned {len(ncei_rows)} rows (< {MIN_ROWS}); aborting", file=sys.stderr)
        return 1

    first, last = ncei_rows[0]["DATE"], ncei_rows[-1]["DATE"]
    om_url = (
        "https://archive-api.open-meteo.com/v1/archive"
        f"?latitude={LAT}&longitude={LON}"
        f"&start_date={first}&end_date={last}"
        "&daily=windspeed_10m_max,windspeed_10m_mean"
        "&timezone=Australia%2FMelbourne"
    )
    om = json.loads(fetch(om_url))
    wind = {
        d: (wmax, wmean)
        for d, wmax, wmean in zip(
            om["daily"]["time"],
            om["daily"]["windspeed_10m_max"],
            om["daily"]["windspeed_10m_mean"],
        )
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, quoting=csv.QUOTE_ALL)
        w.writeheader()
        for row in ncei_rows:
            wmax, wmean = wind.get(row["DATE"], (None, None))
            row["WSPD_MAX"] = "" if wmax is None else f"{wmax}"
            row["WSPD_MEAN"] = "" if wmean is None else f"{wmean}"
            w.writerow({k: row.get(k, "") for k in FIELDS})

    matched = sum(1 for r in ncei_rows if r["DATE"] in wind)
    print(f"Wrote {len(ncei_rows)} rows; wind matched on {matched}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())