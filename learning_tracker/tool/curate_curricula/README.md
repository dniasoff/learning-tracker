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
| `yerushalmi` | Seder / Masechta / Halacha / … | TODO |
| `mishnayos` | Seder / Masechta / Perek / Mishnah | TODO |
| `chumash` | Sefer / Parsha / Aliyah / Pasuk | TODO |
| `nach` | Sefer / Perek / Pasuk | TODO |
| `mishna_berurah` | Volume / Siman / Seif | TODO |
| `mussar` | Book / Section | TODO |
| **`mishneh_torah`** | Sefer / Hilchot / Perek / Halacha | NEW — TODO |
| **`shulchan_arukh`** | Volume / Siman / Seif | NEW — TODO |
| **`arukh_hashulchan`** | Volume / Siman / Seif | NEW — TODO |
| **`kitzur_shulchan_aruch`** | Siman / Seif | NEW — TODO |
| **`chofetz_chaim`** | Part / Klal / Seif | NEW — TODO |
| **`sefer_hamitzvot`** | Section / Mitzvah | NEW — TODO |
| **`pirkei_avot`** | Perek / Mishnah | NEW — TODO |

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
