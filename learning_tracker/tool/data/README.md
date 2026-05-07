# tool/data

Source data + build artifacts used by the seed-DB build (`tool/seed_content_db.dart`).

## Calendar cache

`sefaria_calendar_cache.json` — date → program → `{en, he}` ref map for every
calendar program our app surfaces. Populated by `tool/sefaria_fetch/` (Go)
from Sefaria's `/api/calendars`. The committed JSON covers 2024-01-01 →
2032-12-31 (3288 days × 9 programs, all with both English ref and Hebrew
`displayValue.he`). Validated against the live API by
`tool/verify_seed_calendar.dart`.

To rebuild or extend the cache:

```sh
cd tool/sefaria_fetch && go build -o ../bin/sefaria_fetch . && cd ../..
tool/bin/sefaria_fetch                       # resume — fills missing days only
tool/bin/sefaria_fetch --refresh             # refetch everything
tool/bin/sefaria_fetch --start=2028-02-09    # narrow range
tool/bin/sefaria_fetch --test=2026-05-07     # one day, print, no write
```

The fetcher writes atomically (tmp + rename), classifies errors
(rate-limit / transient / permanent), and uses circuit breakers so a silent
API contract change exits non-zero rather than producing empty data.

## City data

`cities15000.txt` (gitignored) — GeoNames cities15000 dataset used by
`tool/build_cities_db.dart` to produce `assets/data/cities.sqlite` (the
Sacred Time city picker). Re-download from
<https://download.geonames.org/export/dump/cities15000.zip> if you need to
rebuild.
