# tool/data

Source data + build artifacts used by the seed-DB build (`tool/seed_content_db.dart`).

## Calendar caches

`sefaria_calendar_cache.json` — date → program → ref map for the 4 calendar
programs whose authoritative schedules ship as CSVs in
[Sefaria-Data/sources/calendars](https://github.com/Sefaria/Sefaria-Data/tree/master/sources/calendars):

| Program key             | Source CSV                                                   |
| ----------------------- | ------------------------------------------------------------ |
| `halakhah_yomit`        | `Halakhah_Yomit_2020-2038.csv`                               |
| `arukh_hashulchan_yomi` | `AhS_Yomi_Calendar_-_Sefaria - AhS_Yomi_Calendar_-_Sefaria.csv` |
| `tanakh_yomi`           | `Tanach_Yomi_Sedarim_Calendar_-_updated.csv`                 |
| `yerushalmi_yomi`       | `Yerushalmi_Yomi_Cal_-_Sheet1.csv`                           |

Built by `tool/build_sefaria_calendar_cache.dart`. The committed JSON covers
the seed-build range (2024-01-01 to 2032-12-31). Validated against the live
Sefaria `/api/calendars` API (see `tool/verify_seed_calendar.dart`).

## Daily Rambam (1 + 3 chapters)

Not in this cache. The Rambam cycle skips Yom Tov, so a single-cycle CSV
can't be repeated linearly. Run `tool/fetch_rambam_calendar.dart` to populate
`tool/data/sefaria_rambam_cache.json` from the live API. That fetcher is
slow on purpose — Sefaria rate-limits aggressively. Once the file is fully
populated and committed, `is_active` can flip back to `true` for both Rambam
program seeds.

## City data

`cities15000.txt` (gitignored) — GeoNames cities15000 dataset used by
`tool/build_cities_db.dart` to produce `assets/data/cities.sqlite` (the
Sacred Time city picker). Re-download from
<https://download.geonames.org/export/dump/cities15000.zip> if you need to
rebuild.
