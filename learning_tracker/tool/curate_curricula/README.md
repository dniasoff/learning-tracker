# tool/curate_curricula

Generates `assets/content/hierarchy/{curriculum}.json` files from
Sefaria-Project's library + your local Mongo dump (port 27019).

Output matches the existing flat-list-with-`level1..levelN` schema so
the runtime curriculum browser doesn't change.

## Setup (one-time)

```sh
cd ~/repos/Sefaria-Project
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Drop a `sefaria/local_settings.py` that points at the local Mongo:

```python
from sefaria.local_settings_example import *  # noqa
DEBUG = False
SECRET_KEY = 'extract-only-not-secret'
MONGO_HOST = '127.0.0.1'
MONGO_PORT = 27019
MONGO_REPLICASET_NAME = None
SEARCH_INDEX_ON_SAVE = False
```

## Run

```sh
cd ~/repos/Sefaria-Project
source .venv/bin/activate
DJANGO_SETTINGS_MODULE=sefaria.settings PYTHONPATH=. \
  python ~/repos/learning-tracker/learning_tracker/tool/curate_curricula/main.py \
    --curriculum bavli --diff
```

Flags:
- `--curriculum NAME` — which curriculum to generate (default: bavli)
- `--diff` — show diff vs the on-disk hierarchy (sanity check)
- `--write` — actually write the output to `assets/content/hierarchy/`

## Strategies

One per curriculum. Each returns `(items, level_labels, max_levels)`.

| Curriculum | Levels | Status |
|---|---|---|
| `bavli` | Seder / Masechta / Daf / Amud | ✅ |
| `yerushalmi` | Seder / Masechta / Halacha / … | ✅ |
| `mishnayos` | Seder / Masechta / Perek / Mishnah | ✅ |
| `chumash` | Sefer / Parsha / Aliyah / Pasuk | ✅ |
| `nach` | Sefer / Perek / Pasuk | ✅ |
| `mishna_berurah` | Volume / Siman / Seif | ✅ |
| `mussar` | Book / Section | ✅ |
| `mishneh_torah` | Sefer / Hilchot / Perek / Halacha | ✅ |
| `shulchan_arukh` | Volume / Siman / Seif | ✅ |
| `arukh_hashulchan` | Volume / Siman / Seif | ✅ |
| `kitzur_shulchan_aruch` | Siman / Seif | ✅ |
| `chofetz_chaim` | Part / Klal / Seif | ✅ |
| `sefer_hamitzvot` | Section / Mitzvah | ✅ |
| `shemirat_halashon` | Book / Sefer / Chapter / Verse | ✅ |
| `pirkei_avot` | Perek / Mishnah | ✅ |

Every row above has a working strategy function in `main.py`'s `STRATEGIES`
dict and a generated `assets/content/hierarchy/{curriculum}.json`. "✅"
means implemented and generated, not "reviewed" — per [Validation](#validation),
only `bavli` has had its `--diff` output checked leaf-by-leaf so far; the
rest should still get a `--diff` pass and a taxonomy spot-check before being
treated as fully vetted.

Each strategy walks Sefaria's `Index.nodes` schema (lengths, sectionNames,
addressTypes) to enumerate atomic refs. Talmud is special-cased for
`a/b` amud labels; other depth-2 books use plain integer indexing; codes
are depth-3 (siman:seif:sub-seif).

## Validation

`--diff` reports `only in existing` and `only in generated`. For new
curricula there's no existing — sanity check by leaf count and spot-check
sample refs against `Ref(...)` resolution.

For the bavli strategy currently:
- existing 5349 leaves, generated 5488
- 0 missing in generated, 139 extra (real Sefaria refs past last-daf in
  certain tractates — empty content, harmless but should be filtered)

A future enhancement: filter generated leaves to those with non-empty
text in Mongo. Adds ~1 query per leaf but only at curation time.
