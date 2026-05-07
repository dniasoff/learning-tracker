# tool/text_extract

Builds `tool/data/daily_content_cache.json` — a pre-resolved bilingual
text map for every calendar entry hebcal + Sefaria emit. The seed builder
(`tool/seed_content_db.dart` Phase 4b) consumes this and populates the
`daily_content` table; the runtime falls back to that table when
`text_cache` doesn't have the calendar's display ref.

Output is gitignored (~770MB raw JSON; the resulting SQLite is ~88MB
compressed). Regenerate when:
- New calendar programs are added
- The hebcal cache or sefaria_calendar cache changes
- Sefaria's text changes for any cached ref

## Setup

Same Sefaria-Project venv as `tool/curate_curricula/` (see its README).
Local Mongo dump on port 27019. No API calls are made.

## Run

```sh
cd ~/repos/Sefaria-Project
source .venv/bin/activate
DJANGO_SETTINGS_MODULE=sefaria.settings PYTHONPATH=. \
  python ~/repos/learning-tracker/learning_tracker/tool/text_extract/main.py [--resume] [--limit N]
```

Takes ~3-5 minutes for the full 2024-2032 range (~55K calendar entries).
`--resume` skips entries already in the output file.

## Failure modes

The current run produces ~93% coverage. Known gaps:
- `sefer_hamitzvot` (3288 entries): hebcal supplies chabad.org URLs not
  Sefaria refs. The day-numbered display string ("Day 254: P194") is
  also non-canonical. Either skip the program or hand-translate
  P/N numbers to "Sefer HaMitzvot, Positive/Negative Commandment N".
- `rambam_3_chapters` cross-book ranges (~500 entries): refs like
  "Forbidden Intercourse 21-22, Forbidden Foods 1" span two Mishneh
  Torah books. Sefaria's `Ref()` doesn't parse them as a single ref;
  needs a small split-and-resolve loop.

Extend `_resolve()` in main.py to handle these as needed.
